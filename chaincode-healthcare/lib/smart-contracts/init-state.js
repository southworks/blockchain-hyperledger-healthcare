'use strict';

const { Contract } = require('fabric-contract-api');
const utils = require('../common/utils');
const { permissions } = require('../security-middleware/permissions');

class InitState extends Contract {

  async InitLedger(ctx) {
    await ctx.stub.putState(
      utils.DOCTYPES.rolePermissions,
      Buffer.from(JSON.stringify(permissions))
    );
  }
}

module.exports = InitState;
