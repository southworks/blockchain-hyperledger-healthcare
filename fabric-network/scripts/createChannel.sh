#!/bin/bash
. ../utils/cli-utils.sh
. ../utils/env.sh
export PATH=${PWD}/bin:$PATH

# Print the usage message
function printHelp() {
  println "Usage: "
  println "  channel [mode: create/join]"
  println "    channel create - Create a channel"
  println "      channel create [--channel-name <channel name>] [--org-creator < creator organization name>]"
  println "      channel create --help (print this message)"
  println "        --channel-name <channel name> - Name of the new channel"
  println "        --org-creator <creator organization name> - Name of the creator organization"
  println "        Example:"
  println "          channel create --channel-name channel01 --org-creator org1"
  println "    channel join - Join an organization to a channel"
  println "      channel join [--channel-name <channel name>] [--org <organization name>]"
  println "      channel join --help (print this message)"
  println "        --channel-name <channel name> - Name of the new channel"
  println "        --org <organization name> - Name of the organization to join (could be more than one)"
  println "        Example:"
  println "          channel join --channel-name channel01 --org org1 --org org2"
}

function initChannel() {
  setGlobals $2
  # Poll in case the raft leader is not set yet
  local rc=1
  local COUNTER=1
  while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ]; do
    sleep $DELAY
    set -x
    peer channel create -o localhost:$ORDERER_PORT -c $CHANNEL_NAME --ordererTLSHostnameOverride orderer -f ./channel-artifacts/${CHANNEL_NAME}.tx --outputBlock $BLOCKFILE --tls --cafile $ORDERER_CA &>>log.txt
    res=$?
    { set +x; } 2>/dev/null
    let rc=$res
    COUNTER=$(expr $COUNTER + 1)
  done
  verifyResult $res "Channel creation failed"
}

function createChannelTx() {
  set -x
  configtxgen -profile OrgsChannel -outputCreateChannelTx ./channel-artifacts/${CHANNEL_NAME}.tx -channelID $CHANNEL_NAME --configPath ${PWD}/config &>>log.txt
  res=$?
  { set +x; } 2>/dev/null
  verifyResult $res "Failed to generate channel configuration transaction..."
}

function createChannel() {
  cd ..
  CHANNEL_NAME="$1"
  ORG="$2"
  DELAY="$CLI_DELAY"
  MAX_RETRY="$MAX_RETRY"
  VERBOSE="$VERBOSE"
  : ${CHANNEL_NAME:="testChannel"}
  : ${DELAY:="3"}
  : ${MAX_RETRY:="5"}
  : ${VERBOSE:="false"}

  if [ ! -d "channel-artifacts" ]; then
    mkdir channel-artifacts
  fi

  ORDERER_CA=${PWD}/organizations/ordererOrganizations/orderers/orderer/msp/tlscacerts/tlsca-cert.pem

  ## Create channeltx
  infoln "Generating channel create transaction '${CHANNEL_NAME}.tx'"
  createChannelTx

  BLOCKFILE="./channel-artifacts/${CHANNEL_NAME}.block"

  ## Create channel
  infoln "Creating channel ${CHANNEL_NAME}"
  initChannel $CHANNEL_NAME $ORG
  successln "Channel '$CHANNEL_NAME' created"
  cd scripts
}

if [ -z "$1" ]; then
  fatalln "No flags entered. Use --help for more information"
fi

while [[ $# -ge 1 ]]; do
  key="$1"
  case $key in
  --help)
    printHelp
    exit 0
    ;;
  --org-creator)
    ORGANIZATION="$2"
    shift
    ;;
  --channel-name)
    CHANNEL_NAME="$2"
    shift
    ;;
  *)
    fatalln "Unknown flag: $key. Use --help for more information"
    ;;
  esac
  shift
done

if [ -z "$CHANNEL_NAME" ]; then
  fatalln "--channel-name flag not entered"
fi

if [ -z "$ORGANIZATION" ]; then
  fatalln "--org flag not entered"
fi

echo
println "Executing with the following"
println "- CHANNEL NAME: ${C_GREEN}${CHANNEL_NAME}${C_RESET}"
println "- ORGANIZATION NAME: ${C_GREEN}${ORGANIZATION}${C_RESET}"

createChannel $CHANNEL_NAME $ORGANIZATION
