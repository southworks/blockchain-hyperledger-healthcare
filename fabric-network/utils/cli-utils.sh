#!/bin/bash
C_RESET='\033[0m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_BLUE='\033[0;34m'
C_YELLOW='\033[1;33m'
# println echos string
function println() {
  echo -e "${1}"
}
# errorln echos i red color
function errorln() {
  println "${C_RED}${1}${C_RESET}"
}
# successln echos in green color
function successln() {
  println "${C_GREEN}${1}${C_RESET}"
}

# infoln echos in blue color
function infoln() {
  echo
  println "${C_BLUE}${1}${C_RESET}"
}

# warnln echos in yellow color
function warnln() {
  println "${C_YELLOW}${1}${C_RESET}"
}

# fatalln echos in red color and exits with fail status
function fatalln() {
  errorln "$1"
  exit 1
}

#set port-env values
function setPortEnv() {
  . ./utils/port-env.sh
  echo "ORGS=(${ORGS[*]})
PORTS=(${PORTS[*]})
COUCH_DB_PORTS=(${COUCH_DB_PORTS[*]})
CA_PORTS=(${CA_PORTS[*]})" >utils/port-env.sh
  p=1
  for ORG in ${ORGS[*]}; do
    local ORG_PEER_PORTS=${ORG}_peer_PORTS[@]
    echo "${ORG}_PORT=$((PORTS[${p}]))
CA_${ORG}_PORT=$((CA_PORTS[${p}]))
${ORG}_peer_PORTS=(${!ORG_PEER_PORTS})
${ORG}_peers=$((${ORG}_peers))" >>utils/port-env.sh
    p=$((p + 1))
  done
}
function setGlobals() {
  . ./utils/port-env.sh
  local org=$1
  local port=$((${org}_PORT))
  infoln "Using organization ${org}"
  export CORE_PEER_LOCALMSPID="${org}"
  export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/${org}/peers/peer0.${org}/tls/ca.crt
  export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/${org}/users/Admin@${org}/msp
  export CORE_PEER_ADDRESS=localhost:${port}
  export FABRIC_CFG_PATH=${PWD}/scripts/config
  export CORE_PEER_TLS_ENABLED=true
  export PEER0_${org}_CA=${PWD}/organizations/peerOrganizations/${org}/peers/peer0.${org}/tls/ca.crt
  if [ "$VERBOSE" == "true" ]; then
    env | grep CORE
  fi
}

function setGlobalsCLI() {
  . ./utils/port-env.sh

  setGlobals $1
  local port=$((${1}_PORT))
  export CORE_PEER_ADDRESS=peer0.${1}:${port}
}

function verifyResult() {
  if [ $1 -ne 0 ]; then
    fatalln "$2"
  fi
}

function fetchChannelConfig() {
  local ORG=$1
  local CHANNEL=$2
  OUTPUT=$3
  ORDERER_CA=${PWD}/organizations/ordererOrganizations/orderers/orderer/msp/tlscacerts/tlsca-cert.pem
  setGlobals $ORG

  infoln "Fetching the most recent configuration block for the channel"
  set -x
  peer channel fetch config config_block.pb -o orderer:7050 --ordererTLSHostnameOverride orderer -c $CHANNEL --tls --cafile $ORDERER_CA
  { set +x; } 2>/dev/null

  infoln "Decoding config block to JSON and isolating config to ${OUTPUT}"
  set -x
  configtxlator proto_decode --input config_block.pb --type common.Block | jq .data.data[0].payload.data.config >"${OUTPUT}"
  { set +x; } 2>/dev/null
}

function createConfigUpdate() {
  local CHANNEL=$1
  local ORIGINAL=$2
  local MODIFIED=$3
  local OUTPUT=$4

  set -x
  configtxlator proto_encode --input "${ORIGINAL}" --type common.Config >original_config.pb
  configtxlator proto_encode --input "${MODIFIED}" --type common.Config >modified_config.pb
  configtxlator compute_update --channel_id "${CHANNEL}" --original original_config.pb --updated modified_config.pb >config_update.pb
  configtxlator proto_decode --input config_update.pb --type common.ConfigUpdate >config_update.json
  echo '{"payload":{"header":{"channel_header":{"channel_id":"'$CHANNEL'", "type":2}},"data":{"config_update":'$(cat config_update.json)'}}}' | jq . >config_update_in_envelope.json
  configtxlator proto_encode --input config_update_in_envelope.json --type common.Envelope >"${OUTPUT}"
  { set +x; } 2>/dev/null
}

function signConfigtxAsPeerOrg() {
  local ORG=$1
  local CONFIGTXFILE=$2
  setGlobals $ORG
  set -x
  peer channel signconfigtx -f "${CONFIGTXFILE}"
  { set +x; } 2>/dev/null
}

function parsePeerConnectionParameters() {
  PEER_CONN_PARMS=""
  PEERS=""
  while [ "$#" -gt 0 ]; do
    setGlobals $1
    PEER="peer0.$1"
    ## Set peer addresses
    PEERS="$PEERS $PEER"
    PEER_CONN_PARMS="$PEER_CONN_PARMS --peerAddresses $CORE_PEER_ADDRESS"
    ## Set path to TLS certificate
    TLSINFO=$(eval echo "--tlsRootCertFiles \$PEER0_${1}_CA")
    PEER_CONN_PARMS="$PEER_CONN_PARMS $TLSINFO"
    # shift by one to get to the next organization
    shift
  done
  # remove leading space for output
  PEERS="$(echo -e "$PEERS" | sed -e 's/^[[:space:]]*//')"
}

function parseOrganizationPeerConnectionParameters() {
  local OWNER_ORG=$1
  local PEER_ID=$2
  PEER_CONN_PARMS=""
  PEERS=""

  for ORG in ${ORGS[@]}; do
    if [ "$ORG" == "$OWNER_ORG" ] ; then
      setPeerGlobals ${OWNER_ORG} ${PEER_ID}
      PEER="peer${PEER_ID}.${ORG}"
      TLSINFO=$(eval echo "--tlsRootCertFiles \$PEER${PEER_ID}_${ORG}_CA")
    else
      setGlobals ${ORG}
      PEER="peer0.${ORG}"
      ## Set path to TLS certificate
      TLSINFO=$(eval echo "--tlsRootCertFiles \$PEER0_${ORG}_CA")
    fi
    ## Set peer addresses
    PEERS="$PEERS $PEER"
    PEER_CONN_PARMS="$PEER_CONN_PARMS --peerAddresses $CORE_PEER_ADDRESS"
    PEER_CONN_PARMS="$PEER_CONN_PARMS $TLSINFO"
    # shift by one to get to the next organization
    shift
  done
  # remove leading space for output
  PEERS="$(echo -e "$PEERS" | sed -e 's/^[[:space:]]*//')"
}

function setPeerGlobals() {
  . ./utils/port-env.sh

  local org=$1
  local peer=$2
  local port=$((${org}_peer_PORTS[${peer}]))
  infoln "Using organization ${org}"
  infoln "Using peer ${peer}"
  export CORE_PEER_LOCALMSPID="${org}"
  export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/${org}/peers/peer${peer}.${org}/tls/ca.crt
  export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/${org}/users/Admin@${org}/msp
  export CORE_PEER_ADDRESS=localhost:${port}
  export FABRIC_CFG_PATH=${PWD}/scripts/config
  export CORE_PEER_TLS_ENABLED=true
  export PEER${peer}_${org}_CA=${PWD}/organizations/peerOrganizations/${org}/peers/peer${peer}.${org}/tls/ca.crt
  if [ "$VERBOSE" == "true" ]; then
    env | grep CORE
  fi
}

export -f errorln
export -f successln
export -f infoln
export -f warnln
export -f setGlobals
export -f setGlobalsCLI
export -f verifyResult
export -f fetchChannelConfig
export -f createConfigUpdate
export -f signConfigtxAsPeerOrg
export -f parsePeerConnectionParameters
export -f setPortEnv
export -f setPeerGlobals
