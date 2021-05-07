#!/bin/bash
. ../utils/cli-utils.sh
. ../utils/env.sh
. ../utils/port-env.sh
export PATH=${PWD}/bin:$PATH
export VERBOSE=false
. ../utils/create-yaml.sh

# Print the usage message
function printHelp() {
  println "Usage: "
  println "  network [mode: delete/create/add-org]"
  println "    network delete - Delete network and its directories"
  println "    network create - Create network"
  println "      network create [--org <organization name>] [--admin-user <admin username>] [--admin-pwd <admin userpassword>] [--cc-install-policy <cc install policy>]"
  println "      network create --help (print this message)"
  println "        --org <organization name> - Name of the organization to be added"
  println "        --admin-user <admin username> - Name of the organization's Admin user"
  println "        --admin-pwd <admin user password> - Password of the organization's Admin user"
  println "        --cc-install-policy <cc install policy> - Lifecycle and Endorsment chaincode policies"
  println "          ANY: At least one organization has to approve the chaincode install operation"
  println "          MAJORITY (default option): The majority of the existing organizations have to approve the chaincode install operation"
  println "          ALL: All organizations have to approve the chaincode install operation"
  println "        Example:"
  println "          network create --org org1 --admin-user user01 --admin-pwd pass01 --cc-install-policy all"
  println "    network add-org - Add a new organization to the network"
  println "      network add-org [--org <organization name>] [--admin-user <admin username>] [--admin-pwd <admin userpassword>]"
  println "      network add-org -h|--help (print this message)"
  println "        --org <organization name> - Name of the organization to be added"
  println "        --admin-user <admin username> - Name of the organization's Admin user"
  println "        --admin-pwd <admin user password> - Password of the organization's Admin user"
  println "        Example:"
  println "          network add-org --org org1 --admin-user user01 --admin-pwd pass01"
}

function initOrg {

  infoln "Enrolling the CA admin"
  mkdir -p organizations/peerOrganizations/${ORGANIZATION}/

  export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/peerOrganizations/${ORGANIZATION}/

  set -x
  fabric-ca-client enroll -u https://${ADMIN_USER}:${ADMIN_PWD}@localhost:${PEER_CA_PORT} --caname ca-${ORGANIZATION} --tls.certfiles ${PWD}/organizations/fabric-ca/${ORGANIZATION}/tls-cert.pem &>>log.txt
  { set +x; } 2>/dev/null

  echo "NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/localhost-${PEER_CA_PORT}-ca-${ORGANIZATION}.pem
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/localhost-${PEER_CA_PORT}-ca-${ORGANIZATION}.pem
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/localhost-${PEER_CA_PORT}-ca-${ORGANIZATION}.pem
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/localhost-${PEER_CA_PORT}-ca-${ORGANIZATION}.pem
    OrganizationalUnitIdentifier: orderer" >${PWD}/organizations/peerOrganizations/${ORGANIZATION}/msp/config.yaml

  infoln "Registering peer0"
  set -x
  fabric-ca-client register --caname ca-${ORGANIZATION} --id.name peer0 --id.secret peer0pw --id.type peer --tls.certfiles ${PWD}/organizations/fabric-ca/${ORGANIZATION}/tls-cert.pem &>>log.txt
  { set +x; } 2>/dev/null

  infoln "Registering the org admin"
  set -x
  fabric-ca-client register --caname ca-${ORGANIZATION} --id.name ${ORGANIZATION}-${ADMIN_USER} --id.secret ${ADMIN_PWD} --id.type admin --tls.certfiles ${PWD}/organizations/fabric-ca/${ORGANIZATION}/tls-cert.pem &>>log.txt
  { set +x; } 2>/dev/null

  infoln "Generating the peer0 msp"
  set -x
  fabric-ca-client enroll -u https://peer0:peer0pw@localhost:${PEER_CA_PORT} --caname ca-${ORGANIZATION} -M ${PWD}/organizations/peerOrganizations/${ORGANIZATION}/peers/peer0.${ORGANIZATION}/msp --csr.hosts peer0.${ORGANIZATION} --tls.certfiles ${PWD}/organizations/fabric-ca/${ORGANIZATION}/tls-cert.pem &>>log.txt
  { set +x; } 2>/dev/null

  cp ${PWD}/organizations/peerOrganizations/${ORGANIZATION}/msp/config.yaml ${PWD}/organizations/peerOrganizations/${ORGANIZATION}/peers/peer0.${ORGANIZATION}/msp/config.yaml

  infoln "Generating the peer0-tls certificates"
  set -x
  fabric-ca-client enroll -u https://peer0:peer0pw@localhost:${PEER_CA_PORT} --caname ca-${ORGANIZATION} -M ${PWD}/organizations/peerOrganizations/${ORGANIZATION}/peers/peer0.${ORGANIZATION}/tls --enrollment.profile tls --csr.hosts peer0.${ORGANIZATION} --csr.hosts localhost --tls.certfiles ${PWD}/organizations/fabric-ca/${ORGANIZATION}/tls-cert.pem &>>log.txt
  { set +x; } 2>/dev/null

  cp ${PWD}/organizations/peerOrganizations/${ORGANIZATION}/peers/peer0.${ORGANIZATION}/tls/tlscacerts/* ${PWD}/organizations/peerOrganizations/${ORGANIZATION}/peers/peer0.${ORGANIZATION}/tls/ca.crt
  cp ${PWD}/organizations/peerOrganizations/${ORGANIZATION}/peers/peer0.${ORGANIZATION}/tls/signcerts/* ${PWD}/organizations/peerOrganizations/${ORGANIZATION}/peers/peer0.${ORGANIZATION}/tls/server.crt
  cp ${PWD}/organizations/peerOrganizations/${ORGANIZATION}/peers/peer0.${ORGANIZATION}/tls/keystore/* ${PWD}/organizations/peerOrganizations/${ORGANIZATION}/peers/peer0.${ORGANIZATION}/tls/server.key

  mkdir -p ${PWD}/organizations/peerOrganizations/${ORGANIZATION}/msp/tlscacerts
  cp ${PWD}/organizations/peerOrganizations/${ORGANIZATION}/peers/peer0.${ORGANIZATION}/tls/tlscacerts/* ${PWD}/organizations/peerOrganizations/${ORGANIZATION}/msp/tlscacerts/ca.crt

  mkdir -p ${PWD}/organizations/peerOrganizations/${ORGANIZATION}/tlsca
  cp ${PWD}/organizations/peerOrganizations/${ORGANIZATION}/peers/peer0.${ORGANIZATION}/tls/tlscacerts/* ${PWD}/organizations/peerOrganizations/${ORGANIZATION}/tlsca/tlsca.${ORGANIZATION}-cert.pem

  mkdir -p ${PWD}/organizations/peerOrganizations/${ORGANIZATION}/ca
  cp ${PWD}/organizations/peerOrganizations/${ORGANIZATION}/peers/peer0.${ORGANIZATION}/msp/cacerts/* ${PWD}/organizations/peerOrganizations/${ORGANIZATION}/ca/ca.${ORGANIZATION}-cert.pem

  infoln "Generating the org admin msp"
  set -x
  fabric-ca-client enroll -u https://${ORGANIZATION}-${ADMIN_USER}:${ADMIN_PWD}@localhost:${PEER_CA_PORT} --caname ca-${ORGANIZATION} -M ${PWD}/organizations/peerOrganizations/${ORGANIZATION}/users/Admin@${ORGANIZATION}/msp --tls.certfiles ${PWD}/organizations/fabric-ca/${ORGANIZATION}/tls-cert.pem &>>log.txt
  { set +x; } 2>/dev/null

  cp ${PWD}/organizations/peerOrganizations/${ORGANIZATION}/msp/config.yaml ${PWD}/organizations/peerOrganizations/${ORGANIZATION}/users/Admin@${ORGANIZATION}/msp/config.yaml
}

# Create Organziation crypto material using cryptogen or CAs
function generateOrg() {

  # Create crypto material using Fabric CA
  if [ "$CRYPTO" == "Certificate Authorities" ]; then
    fabric-ca-client version >/dev/null 2>&1
    if [[ $? -ne 0 ]]; then
      echo "ERROR! fabric-ca-client binary not found.."
      echo
      echo "Follow the instructions in the Fabric docs to install the Fabric Binaries:"
      echo "https://hyperledger-fabric.readthedocs.io/en/latest/install.html"
      exit 1
    fi

    infoln "Generating certificates using Fabric CA"
    docker-compose -f ${COMPOSE_FILE_CA_ORG} up -d 2>&1

    sleep 10

    infoln "Creating ${ORGANIZATION} Identities"
    initOrg ${ORGANIZATION} ${ADMIN_USER} ${ADMIN_PWD} ${PEER_CA_PORT}

  fi

  infoln "Generating CCP files for ${ORGANIZATION}"
  . ./utils/ccp-generate.sh ${ORGANIZATION} ${PEER_CA_PORT} ${PEER_PORT} ${NETWORK_NAME}
}

# Generate channel configuration transaction
function generateOrgDefinition() {
  which configtxgen
  if [ "$?" -ne 0 ]; then
    fatalln "configtxgen tool not found. exiting"
  fi
  infoln "Generating Org organization definition"
  export FABRIC_CFG_PATH=$PWD/scripts/config
  set -x
  configtxgen -printOrg ${ORGANIZATION} --configPath ${PWD}/config/${ORGANIZATION} >organizations/peerOrganizations/${ORGANIZATION}/${ORGANIZATION}.json
  res=$?
  { set +x; } 2>/dev/null
  if [ $res -ne 0 ]; then
    fatalln "Failed to generate ${ORGANIZATION} organization definition..."
  fi
}

function OrgUp() {
  # start org3 nodes
  if [ "${DATABASE}" == "couchdb" ]; then
    docker-compose -f $COMPOSE_FILE_ORG -f $COMPOSE_FILE_COUCH up -d 2>&1
  else
    docker-compose -f $COMPOSE_FILE_ORG up -d 2>&1
  fi
  if [ $? -ne 0 ]; then
    fatalln "ERROR !!!! Unable to start ${ORGANIZATION} network"
  fi
}

# Generate the needed certificates, the genesis block and start the network.
function addOrg() {
  # If the network is not up, abort
  if [ ! -d organizations/ordererOrganizations ]; then
    fatalln "ERROR: Please, run ./network.sh up createChannel first."
  fi

  # generate artifacts if they don't exist
  if [ ! -d "organizations/peerOrganizations/${ORGANIZATION}" ]; then
    generateOrg
    generateOrgDefinition
  fi

  infoln "Bringing up ${ORGANIZATION} peer"
  OrgUp

  # Use the CLI container to create the configuration transaction needed to add
  # Org to the network
  infoln "Generating and submitting config tx to add ${ORGANIZATION}"
  docker exec cli sed -i 's/\r//' ./utils/env.sh
  docker exec cli sed -i 's/\r//' ./utils/cli-utils.sh
  docker exec cli sed -i 's/\r//' ./scripts/add-org/updateChannelConfig.sh
  docker exec cli ./scripts/add-org/updateChannelConfig.sh ${ORGANIZATION} ${CHANNEL_NAME} ${HOST_ORG}
  if [ $? -ne 0 ]; then
    fatalln "ERROR !!!! Unable to create config tx"
  fi
  successln "${ORG} peer successfully added to network, join it to ${CHANNEL_NAME} channel"
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
  --channel-name)
    CHANNEL="$2"
    shift
    ;;
  *)
    fatalln "Unknown flag: $key. Use --help for more information"
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

if [ -z "$CHANNEL" ]; then
  fatalln "--channel-name flag not entered"
fi

COMPOSE_FILE_ORG=docker/docker-compose-${ORGANIZATION}.yaml
COMPOSE_FILE_COUCH=docker/docker-compose-couchdb-${ORGANIZATION}.yaml
COMPOSE_FILE_CA_ORG=docker/docker-compose-ca-${ORGANIZATION}.yaml
CHANNEL_NAME=${CHANNEL}
PEER_PORT=$((ORDERER_PORT + ${#ORGS[@]} + 1))
PEER_CA_PORT=$((CA_ORDERER_PORT + ${#ORGS[@]} + 1))
cd ..

if [ ! -d "organizations/peerOrganizations/${ORGANIZATION}" ]; then
  create_net_org_yaml
  create_couch_org_yaml
  create_ca_org_yaml
  setPortEnv
  create_configtx_org_yaml
fi

HOST_ORG=${ORGS[0]}
echo
println "Executing with the following"
println "- ORGANIZATION NAME: ${C_GREEN}${ORGANIZATION}${C_RESET}"
println "- HOST ORGANIZATION: ${C_GREEN}${HOST_ORG}${C_RESET}"
println "- CHANNEL_NAME: ${C_GREEN}${CHANNEL_NAME}${C_RESET}"
println "- ADMIN USER: ${C_GREEN}${ADMIN_USER}${C_RESET}"
println "- ADMIN PWD: ${C_GREEN}${ADMIN_PWD}${C_RESET}"
println "- CA_ORDERER_PEER_PORT: ${C_GREEN}${PEER_CA_PORT}${C_RESET}"
println "- ORDERER_PEER_PORT: ${C_GREEN}${PEER_PORT}${C_RESET}"

addOrg
