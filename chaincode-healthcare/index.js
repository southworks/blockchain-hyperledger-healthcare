'use strict';

const InitState = require('./lib/smart-contracts/init-state');
const HealthCenter = require('./lib/smart-contracts/health-center');
const Physician = require('./lib/smart-contracts/physician');
const Patient = require('./lib/smart-contracts/patient');

module.exports.InitState = InitState;
module.exports.HealthCenter = HealthCenter;
module.exports.Physician = Physician;
module.exports.Patient = Patient;

module.exports.contracts = [InitState, HealthCenter, Physician, Patient];
