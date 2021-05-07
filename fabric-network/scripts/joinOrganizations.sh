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
  println "          channel create  --channel-name channel01 --org-creator org1"
  println "    channel join - Join a organization to a channel"
  println "      channel join [--channel-name <channel name>] [--org <organization name>]"
  println "      channel join --help (print this message)"
  println "        --channel-name <channel name> - Name of the new channel"
  println "        --org <organization name> - Name of the organization to join (could be more than one)"
  println "        Example:"
  println "          channel join --channel-name channel01 --org org1 --org org2"
}

joinChannel() {
  ORG=$1
  setGlobals $ORG
  local rc=1
  local COUNTER=1
  ## Sometimes Join takes time, hence retry
  while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ]; do
    sleep $DELAY
    set -x
    peer channel join -b $BLOCKFILE >&log.txt
    res=$?
    { set +x; } 2>/dev/null
    let rc=$res
    COUNTER=$(expr $COUNTER + 1)
  done
  cat log.txt
  verifyResult $res "After $MAX_RETRY attempts, peer0.${ORG} has failed to join channel '$CHANNEL_NAME' "
}

setAnchorPeer() {
  ORG=$1
  docker exec cli sed -i 's/\r//' ./utils/setAnchorPeer.sh
  docker exec cli ./utils/setAnchorPeer.sh $ORG $CHANNEL_NAME
}

function joinOrganization() {
  cd ..
  DELAY="$CLI_DELAY"
  MAX_RETRY="$MAX_RETRY"
  VERBOSE="$VERBOSE"
  : ${DELAY:="3"}
  : ${MAX_RETRY:="5"}
  : ${VERBOSE:="false"}

  #Join all the peers to the channel
  for ORGANIZATION in ${ORGANIZATIONS[*]}; do
    BLOCKFILE="./channel-artifacts/${CHANNEL_NAME}.block"
    infoln "Joining ${ORGANIZATION} peer to the ${CHANNEL_NAME} ..."
    joinChannel ${ORGANIZATION}
    infoln "Setting anchor peer for ${ORGANIZATION}..."
    setAnchorPeer ${ORGANIZATION} $CHANNEL_NAME
  done
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
  --org)
    if [ "${ORGANIZATIONS}" = "" ]; then
      ORGANIZATIONS=($2)
    else
      ORGANIZATIONS=(${ORGANIZATIONS[*]} $2)
    fi
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

if [ -z "$ORGANIZATIONS" ]; then
  fatalln "--org flag not entered"
fi

echo
println "Executing with the following"
println "- CHANNEL NAME: ${C_GREEN}${CHANNEL_NAME}${C_RESET}"
println "- ORGANIZATION/S NAME/S: ${C_GREEN}${ORGANIZATIONS[*]}${C_RESET}"

joinOrganization
