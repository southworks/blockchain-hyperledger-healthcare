'use strict';

const ACTIONS = {
  createEmr: 'CreateEmr',
  readEmr: 'ReadEmr',
  getEmrByPatientId: 'GetEmrByPatientId',
  addEmrNote: 'AddEmrNote',
  approveEmrSharing: 'ApproveEmrSharing',
  getRolePermissionsHistory: 'GetRolePermissionsHistory',
  getOwnEmr: 'GetOwnEmr',
  checkIsPatientRegistered: 'CheckIsPatientRegistered',
  getMedicalVisitsCount: 'GetMedicalVisitsCount',
  authorizeEmrReading: 'AuthorizeEmrReading',
  getSharedEmr: 'GetSharedEmr',
  removeEmrSharing: 'RemoveEmrSharing',
};


const permissions = [
  {
    role: 'healthcenter',
    actions: [
      ACTIONS.createEmr,
      ACTIONS.getRolePermissionsHistory,
      ACTIONS.checkIsPatientRegistered,
      ACTIONS.authorizeEmrReading,
    ],
  },
  {
    role: 'physician',
    actions: [
      ACTIONS.readEmr,
      ACTIONS.getEmrByPatientId,
      ACTIONS.addEmrNote,
      ACTIONS.getSharedEmr,
    ],
  },
  {
    role: 'patient',
    actions: [
      ACTIONS.getEmrByPatientId,
      ACTIONS.approveEmrSharing,
      ACTIONS.getOwnEmr,
      ACTIONS.getMedicalVisitsCount,
      ACTIONS.removeEmrSharing,
    ],
  },
];

module.exports = {
  permissions,
  ACTIONS,
};
