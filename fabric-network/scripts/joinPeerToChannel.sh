#!/bin/bash
. ../utils/cli-utils.sh
. ../utils/env.sh
export PATH=${PWD}/bin:$PATH

function printHelp() {
  println "Usage: "
  println "  peer [mode: create/join]"
  println "    peer create - Create a peer"
  println "      peer create [--org <organization name>] [--admin-user <admin username>] [--admin-pwd <admin userpassword>]"
  println "      peer create --help (print this message)"
  println "        --org <organization name> - Name of the organization where the peer will be added"
  println "        --admin-user <admin username> - Name of the organization's Admin user"
  println "        --admin-pwd <admin userpassword> - Password of the organization's Admin user"
  println "        Example:"
  println "          peer create --org org1 --admin-user user01 --admin-pwd pass01"
  println "    peer join - Join a peer to a channel"
  println "      peer join [--channel-name <channel name>] [--org <organization name>] [--peer <peer ID>]"
  println "      peer join --help (print this message)"
  println "        --channel-name <channel name> - Name of the channel"
  println "        --org <organization name> - Name of the organization to join (could be more than one)"
  println "        --peer <peer ID> - Peer ID"
  println "        Example:"
  println "          peer join --channel-name channel01 --org org1 --peer 1"
}

function joinChannel() {
  ORG=$1
  PEER_ID=$2

  if [ ! -z $2 ]; then
    setPeerGlobals $ORG $PEER_ID
  else
    setGlobals $ORG
  fi

  if [ -z $BLOCKFILE ] && [ ! -z $3 ]; then
    BLOCKFILE="./channel-artifacts/$3.block"
  fi

  local rc=1
  local COUNTER=1
  # Sometimes Join takes time, hence retry
  while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ]; do
    sleep 1
    set -x
    peer channel join -b $BLOCKFILE >&log.txt
    res=$?
    { set +x; } 2>/dev/null
    let rc=$res
    COUNTER=$(expr $COUNTER + 1)
  done
  verifyResult $res "After $MAX_RETRY attempts, peer0.${ORG} has failed to join channel '$CHANNEL' "
  successln "peer$PEER_ID joined to $CHANNEL"
}

cd ..

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
  --channel-name)
    CHANNEL="$2"
    shift
    ;;
  --org)
    ORGANIZATION="$2"
    shift
    ;;
  --peer)
    PEER_ID="$2"
    shift
    ;;
  *)
    fatalln "Unknown flag: $key"
    ;;
  esac
  shift
done

if [ -z "$CHANNEL" ]; then
  fatalln "--channel-name flag not entered"
fi

if [ -z "$ORGANIZATION" ]; then
  fatalln "--org flag not entered"
fi

if [ -z "$PEER_ID" ]; then
  fatalln "--peer flag not entered"
fi

echo
println "Executing with the following"
println "- ORGANIZATION NAME: ${C_GREEN}${ORGANIZATION}${C_RESET}"
println "- CHANNEL: ${C_GREEN}${CHANNEL}${C_RESET}"
println "- PEER ID: ${C_GREEN}${PEER_ID}${C_RESET}"

joinChannel $ORGANIZATION $PEER_ID $CHANNEL
