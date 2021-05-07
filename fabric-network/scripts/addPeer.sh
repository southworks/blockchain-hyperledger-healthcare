#!/bin/bash
. ../utils/env.sh
. ../utils/cli-utils.sh
. ../utils/create-peer-yaml.sh
. ../utils/port-env.sh

export PATH=${PWD}/bin:$PATH

function printHelp() {
  println "Usage: "
  println "  peer [mode: create/join]"
  println "    peer create - Create a peer"
  println "      peer create [--org <organization name>] [--admin-user <admin username>] [--admin-pwd <admin user password>]"
  println "      peer create --help (print this message)"
  println "        --org <organization name> - Name of the organization where the peer will be added"
  println "        --admin-user <admin username> - Name of the organization's Admin user"
  println "        --admin-pwd <admin userpassword> - Password of the organization's Admin user"
  println "        Example:"
  println "          peer create --org org1 --admin-user user01 --admin-pwd pass01"
  println "    peer join - Join a peer to a channel"
  println "      peer join [--channel-name <channel name>] [--org <organization name>] [--peer <peer ID>]"
  println "      peer join --help (print this message)"
  println "        --channel-name <channel name> - Name of the new channel"
  println "        --org <organization name> - Name of the organization the peer belongs to"
  println "        --peer <peer ID> - Peer ID"
  println "        Example:"
  println "          peer join --channel-name channel01 --org org1 --peer 1"
}

function initPeer() {
  local ORGANIZATION=$1
  local PEER_ID=$2
  local ORG_CA_PORT=$((CA_${ORGANIZATION}_PORT))

  export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/peerOrganizations/${ORGANIZATION}/

  infoln "Registering new peer"
  set -x
  fabric-ca-client register --caname ca-${ORGANIZATION} --id.name peer${PEER_ID} --id.secret peer${PEER_ID}pw --id.type peer --tls.certfiles ${PWD}/organizations/fabric-ca/${ORGANIZATION}/tls-cert.pem &>>log.txt
  { set +x; } 2>/dev/null

  infoln "Generating the peer msp"
  set -x
  fabric-ca-client enroll -u https://peer${PEER_ID}:peer${PEER_ID}pw@localhost:${ORG_CA_PORT} --caname ca-${ORGANIZATION} -M ${PWD}/organizations/peerOrganizations/${ORGANIZATION}/peers/peer${PEER_ID}.${ORGANIZATION}/msp --csr.hosts peer${PEER_ID}.${ORGANIZATION} --tls.certfiles ${PWD}/organizations/fabric-ca/${ORGANIZATION}/tls-cert.pem &>>log.txt
  { set +x; } 2>/dev/null

  cp ${PWD}/organizations/peerOrganizations/${ORGANIZATION}/msp/config.yaml ${PWD}/organizations/peerOrganizations/${ORGANIZATION}/peers/peer${PEER_ID}.${ORGANIZATION}/msp/config.yaml

  infoln "Generating the peer tls certificates"
  set -x
  fabric-ca-client enroll -u https://peer${PEER_ID}:peer${PEER_ID}pw@localhost:${ORG_CA_PORT} --caname ca-${ORGANIZATION} -M ${PWD}/organizations/peerOrganizations/${ORGANIZATION}/peers/peer${PEER_ID}.${ORGANIZATION}/tls --enrollment.profile tls --csr.hosts peer${PEER_ID}.${ORGANIZATION} --csr.hosts localhost --tls.certfiles ${PWD}/organizations/fabric-ca/${ORGANIZATION}/tls-cert.pem &>>log.txt
  { set +x; } 2>/dev/null

  cp ${PWD}/organizations/peerOrganizations/${ORGANIZATION}/peers/peer${PEER_ID}.${ORGANIZATION}/tls/tlscacerts/* ${PWD}/organizations/peerOrganizations/${ORGANIZATION}/peers/peer${PEER_ID}.${ORGANIZATION}/tls/ca.crt
  cp ${PWD}/organizations/peerOrganizations/${ORGANIZATION}/peers/peer${PEER_ID}.${ORGANIZATION}/tls/signcerts/* ${PWD}/organizations/peerOrganizations/${ORGANIZATION}/peers/peer${PEER_ID}.${ORGANIZATION}/tls/server.crt
  cp ${PWD}/organizations/peerOrganizations/${ORGANIZATION}/peers/peer${PEER_ID}.${ORGANIZATION}/tls/keystore/* ${PWD}/organizations/peerOrganizations/${ORGANIZATION}/peers/peer${PEER_ID}.${ORGANIZATION}/tls/server.key
}

function createPeer() {
  local ORGANIZATION=$1
  local ADMIN_USER=$2
  local ADMIN_PWD=$3

  if [ ! -d "organizations/peerOrganizations/${ORGANIZATION}/" ]; then
    fatalln "The organization does not exist"
  fi

  PEER_ID=$(ls ${PWD}/organizations/peerOrganizations/${ORGANIZATION}/peers/ | wc -l)

  # Create crypto material using cryptogen
  if [ "$CRYPTO" == "cryptogen" ]; then
    which cryptogen
    if [ "$?" -ne 0 ]; then
      fatalln "cryptogen tool not found. exiting"
    fi
    infoln "Generating certificates using cryptogen tool"

    infoln "Creating ${1} new peer"

    set -x
    cryptogen generate --config=./organizations/cryptogen/crypto-config-${1}.yaml --output="organizations"
    res=$?
    { set +x; } 2>/dev/null
    if [ $res -ne 0 ]; then
      fatalln "Failed to generate certificates..."
    fi
  fi
  # Create crypto material using Fabric CA
  if [ "$CRYPTO" == "Certificate Authorities" ]; then
    infoln "Creating peer Identities"
    initPeer $ORGANIZATION $PEER_ID
  fi

  create_peer_yaml $ORGANIZATION $PEER_ID
  create_peer_couch_yaml $ORGANIZATION $ADMIN_USER $ADMIN_PWD $PEER_ID

  COMPOSE_FILES="-f docker/docker-compose-${ORGANIZATION}-peer${PEER_ID}.yaml"
  COMPOSE_FILE_COUCH="docker/docker-compose-couchdb-${ORGANIZATION}-peer${PEER_ID}.yaml"
  if [ "${DATABASE}" == "couchdb" ]; then
    COMPOSE_FILES="${COMPOSE_FILES} -f ${COMPOSE_FILE_COUCH}"
  fi

  infoln "Starting Docker containers"

  IMAGE_TAG=$IMAGETAG docker-compose ${COMPOSE_FILES} up -d 2>&1

  # Store amount of peers created in the organization to use in chaincode installation
  ORG_PEERS=$((${ORGANIZATION}_peers))
  echo "${ORGANIZATION}_peers=$((${ORGANIZATION}_peers + 1))" >>utils/port-env.sh

  setPortEnv

  docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

  if [ $? -ne 0 ]; then
    fatalln "Unable to start network"
  fi

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
  --org)
    ORGANIZATION="$2"
    shift
    ;;
  --admin-user)
    ADMIN_USER="$2"
    shift
    ;;
  --admin-pwd)
    ADMIN_PWD="$2"
    shift
    ;;
  *)
    fatalln "Unknown flag: $key"
    ;;
  esac
  shift
done

if [ -z "$ORGANIZATION" ]; then
  fatalln "--org flag not entered"
fi

if [ -z "$ADMIN_USER" ]; then
  fatalln "--admin-user flag not entered"
fi

if [ -z "$ADMIN_PWD" ]; then
  fatalln "--admin-pwd flag not entered"
fi

echo
println "Executing with the following"
println "- ORGANIZATION NAME: ${C_GREEN}${ORGANIZATION}${C_RESET}"
println "- ADMIN NAME: ${C_GREEN}${ADMIN_USER}${C_RESET}"
println "- ADMIN PASSWORD: ${C_GREEN}${ADMIN_PWD}${C_RESET}"

createPeer $ORGANIZATION $ADMIN_USER $ADMIN_PWD
