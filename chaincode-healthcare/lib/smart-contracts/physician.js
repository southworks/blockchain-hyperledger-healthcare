'use strict';

const { Contract } = require('fabric-contract-api');
const utils = require('../common/utils');
const { ACTIONS } = require('../security-middleware/permissions');
const canPerformAction = require('../security-middleware/role-permission-validation');

class Physician extends Contract {

  // add a new Notes to an existing emr from a specific patient
  async AddEmrNote(ctx, noteProps) {
    await canPerformAction(ctx, ACTIONS.addEmrNote);

    const notePropsJson = JSON.parse(noteProps);
    if (!this.areValidNoteProps(notePropsJson)) {
      throw new Error('Bad request');
    }

    const emrString = await this.GetEmrByPatientId(ctx, notePropsJson.patientId);

    const note = this.buildNote(ctx, notePropsJson);

    let emr = JSON.parse(emrString);
    emr.notes.push(note);

    const clientOrg = ctx.clientIdentity.getMSPID();
    const emrKey = utils.buildKey(clientOrg, utils.DOCTYPES.emr, emr.id);
    await ctx.stub.putState(emrKey, Buffer.from(JSON.stringify(emr)));

    return emr;
  }

  // reads EMR belonging to specified patient from the world state.
  async ReadEmr(ctx, id) {
    await canPerformAction(ctx, ACTIONS.readEmr);

    const clientOrg = ctx.clientIdentity.getMSPID();
    const emrKey = utils.buildKey(clientOrg, utils.DOCTYPES.emr, id);
    const emrJSON = await ctx.stub.getState(emrKey);
    if (!emrJSON || emrJSON.length === 0) {
      throw new Error(`The EMR ${id} does not exist`);
    }

    return emrJSON.toString();
  }

  async GetEmrByPatientId(ctx, patientId) {
    await canPerformAction(ctx, ACTIONS.getEmrByPatientId);

    let results = await utils.getEMRs(ctx, patientId);

    if (results.length === 0) {
      throw new Error(`There is not an EMR created for the patient ${patientId}`);
    }

    return JSON.stringify(results[0].Record);
  }

  async GetSharedEmr(ctx, sharerOrgId, patientId) {
    await canPerformAction(ctx, ACTIONS.getSharedEmr);

    const emrPermissionList = await utils.getPermissionList(ctx);
    const clientOrg = ctx.clientIdentity.getMSPID();

    const permission = utils.getPermission(
      emrPermissionList, sharerOrgId, clientOrg, patientId
    );

    if (!permission || !permission.ownerOrgApproval || !permission.patientApproval) {
      throw Error('You do not have permission to read this EMR');
    }

    const emrHistoryIterator = await utils.getEmrHistory(
      ctx, sharerOrgId, permission.emrId
    );
    const emrHistory = await utils.getAllResults(emrHistoryIterator, true);

    if (!emrHistory || emrHistory.length === 0) {
      throw Error('The EMR does not exist');
    }

    const emrVersion = emrHistory.find(emr => emr.TxId === permission.txId);
    if (!emrVersion) {
      throw Error('This EMR version does not exist');
    }

    return emrVersion.Value;
  }

  buildNote(ctx, notePropsJson) {
    const userNameAttrName = 'hf.EnrollmentID';
    const transactionMilliseconds = utils.txTimestampToMilliseconds(
      ctx.stub.getTxTimestamp()
    );

    const note = {
      id: parseInt(transactionMilliseconds).toString(),
      date: new Date(transactionMilliseconds).toISOString(),
      issueDoctor: ctx.clientIdentity.getAttributeValue(userNameAttrName),
      area: notePropsJson.area,
      progress: (notePropsJson.progress || '-'),
      vitalSigns: (notePropsJson.vitalSigns || '-'),
      diagnosis: (notePropsJson.diagnosis || '-'),
      medication: (notePropsJson.medication || '-'),
      testResult: (notePropsJson.testResult || '-'),
    };
    return note;
  }

  areValidNoteProps (noteProps)  {
    return (noteProps && noteProps.patientId && noteProps.area);
  }

}

module.exports = Physician;
