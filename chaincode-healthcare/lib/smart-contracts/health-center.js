'use strict';

const { Contract } = require('fabric-contract-api');
const utils = require('../common/utils');
const { ACTIONS } = require('../security-middleware/permissions');
const canPerformAction = require('../security-middleware/role-permission-validation');

class HealthCenter extends Contract {

  // issues a new EMR to the world state with given details. ORG1MSPEMR{emrId}
  async CreateEmr(ctx, emrPropsJson) {
    await canPerformAction(ctx, ACTIONS.createEmr);

    const emrProps = JSON.parse(emrPropsJson);
    if (!this.areValidEmrProps(emrProps)) {
      throw new Error('Bad request');
    }

    await this.CheckIsPatientRegistered(ctx, emrProps.patientId);

    const docType = utils.DOCTYPES.emr;
    const clientOrg = ctx.clientIdentity.getMSPID();
    const emr = this.buildEmr(ctx, clientOrg, docType, emrProps);
    const emrKey = utils.buildKey(clientOrg, docType, emr.id);

    await ctx.stub.putState(emrKey, Buffer.from(JSON.stringify(emr)));

    return emr;
  }

  async CheckIsPatientRegistered(ctx, patientId) {
    await canPerformAction(ctx, ACTIONS.checkIsPatientRegistered);

    let results = await utils.getEMRs(ctx, patientId);

    if (results.length !== 0) {
      throw new Error(`The EMR for the patient ${patientId} already exist`);
    }
  }

  async GetRolePermissionsHistory(ctx) {
    await canPerformAction(ctx, ACTIONS.getRolePermissionsHistory);

    const permissionsIterator = await ctx.stub.getHistoryForKey(utils.DOCTYPES.rolePermissions);
    const permissions = await utils.getAllResults(permissionsIterator, true);

    return JSON.stringify(permissions);
  }

  async AuthorizeEmrReading(ctx, receiverOrgId, emrId) {
    await canPerformAction(ctx, ACTIONS.getRolePermissionsHistory);

    const clientOrg = ctx.clientIdentity.getMSPID();
    const emrHistoryIterator = await utils.getEmrHistory(ctx, clientOrg, emrId);
    const emrHistory = await utils.getAllResults(emrHistoryIterator, true);

    if (!emrHistory || emrHistory.length === 0) {
      throw Error(`The EMR ${emrId} does not exist`);
    }

    const emrPermissionList = await utils.getPermissionList(ctx);

    const emrVersion = emrHistory[0];
    const txId = emrVersion.TxId;
    const patientId = emrVersion.Value.patient.id;

    let permissionListEntry = utils.findPermission(
      emrPermissionList, receiverOrgId, emrId
    );

    if (permissionListEntry) {
      if (permissionListEntry.txId === txId) {
        return permissionListEntry;
      }
      permissionListEntry.txId = txId;
    } else {
      permissionListEntry = this.buildPermissionListEntry(
        clientOrg, receiverOrgId, patientId, emrId, txId
      );
      emrPermissionList.push(permissionListEntry);
    }

    await ctx.stub.putState(
      utils.DOCTYPES.emrPermissionList,
      Buffer.from(JSON.stringify(emrPermissionList))
    );

    return permissionListEntry;
  }

  buildEmr (ctx, ownerOrg, docType, emrProps) {
    const transactionMilliseconds = utils.txTimestampToMilliseconds(
      ctx.stub.getTxTimestamp()
    );
    const emr = {
      id: parseInt(transactionMilliseconds).toString(),
      docType,
      ownerOrg,
      creationDate: new Date(transactionMilliseconds).toISOString(),
      patient: {
        id: emrProps.patientId,
        name: emrProps.patientName,
        birthDate: emrProps.patientBirthdate,
      },
      notes: [],
    };

    return emr;
  }

  buildPermissionListEntry(clientOrg, receiverOrgId, patientId, emrId, txId) {
    return {
      ownerOrgId: clientOrg,
      receiverOrgId,
      patientId,
      emrId,
      txId,
      ownerOrgApproval: true,
    };
  }

  areValidEmrProps (emrProps)  {
    return (emrProps && emrProps.patientId && emrProps.patientName && emrProps.patientBirthdate);
  }

}

module.exports = HealthCenter;
