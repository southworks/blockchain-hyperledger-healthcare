'use strict';

const DOCTYPES = {
  emr: 'EMR',
  rolePermissions: 'rolePermissions',
  emrPermissionList: 'emrPermissionList',
};

const buildKey = (orgId, docType, id) => {
  return orgId + docType + id;
};

const txTimestampToMilliseconds = (timestamp) => {
  const milliseconds =
    (timestamp.seconds.low + timestamp.nanos / 1000000 / 1000) * 1000;

  return milliseconds;
};

const getEmrHistory = async (ctx, clientOrg, emrId) => {
  const emrKey = buildKey(clientOrg, DOCTYPES.emr, emrId);

  return await ctx.stub.getHistoryForKey(emrKey);
};

const getPermissionList = async (ctx) => {
  let emrPermissionList = [];
  const emrPermissionListAsBuffer = await ctx.stub.getState(DOCTYPES.emrPermissionList);

  if (emrPermissionListAsBuffer && emrPermissionListAsBuffer.length !== 0) {
    emrPermissionList = JSON.parse(emrPermissionListAsBuffer.toString());
  }

  return emrPermissionList;
};

const findPermission = (emrPermissionList, receivingOrgId, emrId) => {
  return emrPermissionList.find(p => {
    return p.emrId === emrId && p.receiverOrgId === receivingOrgId;
  });
};

const getPermission = (emrPermissionList, sharerOrgId, receiverOrgId, patientId) => {
  console.log('PARAMS: ', sharerOrgId, receiverOrgId, patientId);
  return emrPermissionList.find(p => {
    return (
      p.ownerOrgId === sharerOrgId &&
            p.receiverOrgId === receiverOrgId &&
            p.patientId === patientId
    );
  });
};

const getAllResults = async (iterator, isHistory) => {
  let allResults = [];
  let res = await iterator.next();
  while (!res.done) {
    if (res.value && res.value.value.toString()) {
      let jsonRes = {};
      console.log(res.value.value.toString('utf8'));
      if (isHistory && isHistory === true) {
        jsonRes.TxId = res.value.txId;
        jsonRes.Timestamp = res.value.timestamp;
        try {
          jsonRes.Value = JSON.parse(res.value.value.toString('utf8'));
        } catch (err) {
          console.log(err);
          jsonRes.Value = res.value.value.toString('utf8');
        }
      } else {
        jsonRes.Key = res.value.key;
        try {
          jsonRes.Record = JSON.parse(res.value.value.toString('utf8'));
        } catch (err) {
          console.log(err);
          jsonRes.Record = res.value.value.toString('utf8');
        }
      }
      allResults.push(jsonRes);
    }
    res = await iterator.next();
  }
  iterator.close();
  return allResults;
};

const getEMRs = async (ctx, patientId) => {
  let queryString = {};
  queryString.selector = {};
  queryString.selector.docType = DOCTYPES.emr;
  queryString.selector.patient = {};
  queryString.selector.patient.id = patientId;
  queryString.selector.ownerOrg = ctx.clientIdentity.getMSPID();

  let resultsIterator = await ctx.stub.getQueryResult(JSON.stringify(queryString));
  let results = await getAllResults(resultsIterator, false);
  return results;
};

module.exports = {
  DOCTYPES,
  buildKey,
  txTimestampToMilliseconds,
  getEmrHistory,
  getPermissionList,
  findPermission,
  getPermission,
  getAllResults,
  getEMRs,
};
