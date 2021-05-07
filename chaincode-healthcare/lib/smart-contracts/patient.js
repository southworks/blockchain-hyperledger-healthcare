'use strict';

const { Contract } = require('fabric-contract-api');
const utils = require('../common/utils');
const { ACTIONS } = require('../security-middleware/permissions');
const canPerformAction = require('../security-middleware/role-permission-validation');

class Patient extends Contract {

  async GetOwnEmr(ctx) {
    const patientId = await canPerformAction(ctx, ACTIONS.getOwnEmr);

    return await this.GetEmrByPatientId(ctx, patientId);
  }

  async GetEmrByPatientId(ctx, patientId) {
    await canPerformAction(ctx, ACTIONS.getEmrByPatientId);

    let results = await utils.getEMRs(ctx, patientId);

    if (results.length === 0) {
      throw new Error(`There is not an EMR created for the patient ${patientId}`);
    }

    return JSON.stringify(results[0].Record);
  }

  async GetMedicalVisitsCount(ctx) {
    const patientId = await canPerformAction(ctx, ACTIONS.getMedicalVisitsCount);

    const EMR = await this.GetEmrByPatientId(ctx, patientId);

    return `Patient visited this place ${JSON.parse(EMR).notes.length} times`;
  }

  async ApproveEmrSharing(ctx, receiverOrgId) {
    const patientId = await canPerformAction(ctx, ACTIONS.approveEmrSharing);

    const clientOrg = ctx.clientIdentity.getMSPID();
    const emrPermissionList = await utils.getPermissionList(ctx);

    const permission = utils.getPermission(
      emrPermissionList, clientOrg, receiverOrgId, patientId
    );

    if (!permission) {
      throw Error('The health center didn\'t authorize this permission');
    }
    permission.patientApproval = true;

    await ctx.stub.putState(
      utils.DOCTYPES.emrPermissionList,
      Buffer.from(JSON.stringify(emrPermissionList))
    );

    return permission;
  }

  async RemoveEmrSharing(ctx, receiverOrgId) {
    const patientId = await canPerformAction(ctx, ACTIONS.approveEmrSharing);

    const clientOrg = ctx.clientIdentity.getMSPID();

    const emrPermissionList = await utils.getPermissionList(ctx);
    const permission = utils.getPermission(
      emrPermissionList, clientOrg, receiverOrgId, patientId
    );
    const response = `The medical provider ${receiverOrgId} doesn't have permission to access your EMR`;

    if (!permission) {
      return response;
    }
    permission.patientApproval = false;

    await ctx.stub.putState(
      utils.DOCTYPES.emrPermissionList,
      Buffer.from(JSON.stringify(emrPermissionList))
    );

    return response;
  }

}

module.exports = Patient;
