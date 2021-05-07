#!/bin/bash
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

# This script is designed to be run in the cli container as the
# first step of the EYFN tutorial.  It creates and submits a
# configuration transaction to add Org to the test network
#

# imports
. ./utils/cli-utils.sh

ORG="$1"
CHANNEL="$2"
HOST_ORG="$3"
DELAY="3"
TIMEOUT="10"
VERBOSE="false"
COUNTER=1
MAX_RETRY=5

infoln "Creating config transaction to add Org to network"

# Fetch the config for the channel, writing it to config.json
fetchChannelConfig ${HOST_ORG} ${CHANNEL} config.json

# Modify the configuration to append the new org
set -x
jq -s ".[0] * {\"channel_group\":{\"groups\":{\"Application\":{\"groups\": {\"${ORG}\":.[1]}}}}}" config.json ./organizations/peerOrganizations/${ORG}/${ORG}.json >modified_config.json
{ set +x; } 2>/dev/null

# Compute a config update, based on the differences between config.json and modified_config.json, write it as a transaction to org3_update_in_envelope.pb
createConfigUpdate ${CHANNEL} config.json modified_config.json ${ORG}_update_in_envelope.pb

infoln "Signing config transaction"
signConfigtxAsPeerOrg ${HOST_ORG} ${ORG}_update_in_envelope.pb

infoln "Submitting transaction from a different peer which also signs it"
setGlobals ${HOST_ORG}

set -x
peer channel update -f ${ORG}_update_in_envelope.pb -c ${CHANNEL} -o orderer:7050 --ordererTLSHostnameOverride orderer --tls --cafile "$ORDERER_CA"
{ set +x; } 2>/dev/null

successln "Config transaction to add Org to network submitted"
