#!/bin/bash
cd scripts

. ../utils/cli-utils.sh

function printHelp() {
  println "  ./bc-network.sh [COMMANDS: help/install/network/channel/user/peer/chaincode]"
  println "Usage: "
  println "      help (print this message)"
  println "      install [MODES: prereqs/bootstrap]"
  println "      network [MODES: create/add-org/delete]"
  println "      channel [MODES: create/join]"
  println "      user [MODES: create/list]"
  println "      peer [MODES: create/join]"
  println "      chaincode [MODES: deploy-org/deploy-peer]"
  exit
}

command=$1
mode=$2

shift 2

if [ "$command" = "network" ]; then
  if [ "$mode" = "create" ]; then
    infoln "CREATE NETWORK"
    ./createNetwork.sh "$@"
    exit
  elif [ "$mode" = "add-org" ]; then
    infoln "ADD ORGANIZATION"
    ./addOrganization.sh "$@"
    exit
  elif [ "$mode" = "delete" ]; then
    infoln "DELETE NETWORK"
    ./createNetwork.sh --delete
    exit
  else
  infoln "Unknown '$mode' mode."
  printHelp
  fi
elif [ "$command" = "channel" ]; then
  if [ "$mode" = "create" ]; then
    infoln "CREATE CHANNEL"
    ./createChannel.sh "$@"
    exit
  elif [ "$mode" = "join" ]; then
    infoln "JOIN ORGANIZATION"
    ./joinOrganizations.sh "$@"
    exit
  else
  infoln "Unknown '$mode' mode."
  printHelp
  fi
elif [ "$command" = "user" ]; then
  if [ "$mode" = "create" ]; then
    infoln "CREATE USER"
    ./createUser.sh "$@"
    exit
  elif [ "$mode" = "list" ]; then
    infoln "LIST ORGANIZATION'S USERS"
    ./createUser.sh --list "$@"
    exit
  else
  infoln "Unknown '$mode' mode."
  printHelp
  fi
elif [ "$command" = "peer" ]; then
  if [ "$mode" = "create" ]; then
    infoln "CREATE NEW PEER"
    ./addPeer.sh "$@"
    exit
  fi
  if [ "$mode" = "join" ]; then
    infoln "JOIN NEW PEER"
    ./joinPeerToChannel.sh "$@"
    exit
  else
  infoln "Unknown '$mode' mode."
  printHelp
  fi
elif [ "$command" = "chaincode" ]; then
  if [ "$mode" = "deploy-org" ]; then
    infoln "DEPLOY CHAINCODE ON ORGANIZATION"
    ./deploycc.sh "$@"
    exit
  elif [ "$mode" = "deploy-peer" ]; then
    infoln "DEPLOY CHAINCODE ON NEW PEER"
    ./deploycc.sh --install-peer "$@"
    exit
  elif [ "$mode" = "invoke" ]; then
    infoln "INVOKE CHAINCODE METHOD"
    ./deploycc.sh --invoke "$@"
    exit
  else
  infoln "Unknown '$mode' mode."
  printHelp
  fi
elif [ "$command" = "install" ]; then
  if [ "$mode" = "prereqs" ]; then
    infoln "INSTALL PREREQUESITES"
    ./install.sh --prereqs
    exit
  fi
  if [ "$mode" = "bootstrap" ]; then
    infoln "INSTALL BOOTSTRAP"
    ./install.sh --bootstrap
    exit
  else
  infoln "Unknown '$mode' mode."
  printHelp
  fi
elif [ "$command" = "help" ]; then
  infoln "HELP" 
  printHelp
else
  infoln "Unknow '$command' command."
  printHelp
fi
