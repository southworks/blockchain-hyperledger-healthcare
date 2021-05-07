'use strict';

const utils = require('../common/utils');

const roleAttrName = 'userRole';
const userNameAttrName = 'hf.EnrollmentID';

function verifyAccessPermissions(permissions, roleName, fcnName) {
  let permissionActionsByRole = permissions.filter(p => p.role === roleName)[0];
  if (permissionActionsByRole) {
    let operation = permissionActionsByRole.actions.filter(act => act === fcnName)[0];
    if (operation) {
      return true;
    }
  }

  return false;
}

async function canPerformAction(ctx, fcnName) {
  let role = ctx.clientIdentity.getAttributeValue(roleAttrName);
  let username = ctx.clientIdentity.getAttributeValue(userNameAttrName);

  // Check if user has a role value
  if (!role) {
    throw new Error('User does not have a role.');
  }

  // If user is an admin return the username
  if (role === 'admin') {
    return username;
  }

  const permissionsJSON = await ctx.stub.getState(utils.DOCTYPES.rolePermissions);
  const permissions = JSON.parse(permissionsJSON.toString());

  // Validate user has permission to invoke the required operation
  if (!verifyAccessPermissions(permissions, role, fcnName)) {
    throw new Error('User is not allowed to perform the required operation');
  }

  return username;
}

module.exports = canPerformAction;
