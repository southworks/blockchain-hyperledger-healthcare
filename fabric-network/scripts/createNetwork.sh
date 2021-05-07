#!/bin/bash
. ../utils/cli-utils.sh
. ../utils/env.sh
export PATH=${PWD}/bin:$PATH
export VERBOSE=false
. ../utils/create-yaml.sh

# Print the usage message
function printHelp() {
  println "Usage: "
  println "  network [mode: delete/create/add-org]"
  println "    network delete - Delete network and its directories"
  println "    network create - Create network"
  println "      network create [--org <organization name>] [--admin-user <admin username>] [--admin-pwd <admin user password>] [--cc-install-policy <cc install policy>]"
  println "      network create --help (print this message)"
  println "        --org <organization name> - Name of the organization to be added"
  println "        --admin-user <admin username> - Name of the organization's Admin user"
  println "        --admin-pwd <admin user password> - Password of the organization's Admin user"
  println "        --cc-install-policy <cc install policy> - Lifecycle and Endorsment chaincode policies"
  println "          ANY: At least one organization has to approve the chaincode install operation"
  println "          MAJORITY (default option): The majority of the organizations have to approve the chaincode install operation"
  println "          ALL: All the organizations have to approve the chaincode install operation"
  println "        Example:"
  println "          network create --org org1 --admin-user user01 --admin-pwd pass01 --cc-install-policy all"
  println "    network add-org - Add a new organization to the network"
  println "      network add-org [--org <organization name>] [--admin-user <admin username>] [--admin-pwd <admin user password>] [--channel-name <channel name>]"
  println "      network add-org -h|--help (print this message)"
  println "        --org <organization name> - Name of the organization to be added"
  println "        --admin-user <admin username> - Name of the organization's Admin user"
  println "        --admin-pwd <admin user password> - Password of the organization's Admin user"
  println "        Example:"
  println "          network add-org --org org1 --admin-user user01 --admin-pwd pass01 --channel-name channel01"
}

function networkDown() {
  cd ..
  docker-compose -f $COMPOSE_FILE_BASE -f $COMPOSE_FILE_COUCH -f $COMPOSE_FILE_CA down --volumes --remove-orphans
  printf "${C_GREEN}Containers deleted.${C_RESET}"
  echo
  if [ -d "docker" ]; then
    rm -R docker
    echo docker directory deleted
  fi
  if [ -d "config" ]; then
    rm -R config
    echo config directory deleted
  fi
  if [ -d "channel-artifacts" ]; then
    rm -R channel-artifacts
    echo channel-artifact directory deleted
  fi
  if [ -d "organizations/fabric-ca" ]; then
    rm -R organizations/fabric-ca
    echo fabric-ca directory deleted
  fi
  if [ -d "organizations/ordererOrganizations" ]; then
    rm -R organizations/ordererOrganizations
    echo organizations/ordererOrganizations directory deleted
  fi
  if [ -d "organizations/peerOrganizations" ]; then
    rm -R organizations/peerOrganizations
    echo organizations/peerOrganizations directory deleted
  fi
  if [ -d "system-genesis-block" ]; then
    rm -R system-genesis-block
    echo system-genesis-block directory deleted
  fi
  if [ -d "package" ]; then
    rm -R package
    echo package directory deleted
  fi
  if [ -f "utils/port-env.sh" ]; then
    rm utils/port-env.sh
    echo utils/port-env.sh file deleted
  fi
  if [ -f "log.txt" ]; then
    rm log.txt
    echo log.txt file deleted
  fi
  if [ -f "deploy-log.txt" ]; then
    rm deploy-log.txt
    echo deploy-log.txt file deleted
  fi
  printf "${C_GREEN}Networks folders deleted.${C_RESET}"
  echo
  printf "${C_RED}Delete ${NETWORK_NAME} volumes ${C_RESET}"
  echo
  docker system prune --volumes
}

function checkPrereqs() {
  ## Check if your have cloned the peer binaries and configuration files.
  peer version >/dev/null 2>&1

  if [[ $? -ne 0 || ! -d "scripts/config" ]]; then
    errorln "Peer binary and configuration files not found.."
    errorln
    errorln "Follow the instructions in the Fabric docs to install the Fabric Binaries:"
    errorln "https://hyperledger-fabric.readthedocs.io/en/latest/install.html"
    exit 1
  fi
  # use the fabric tools container to see if the samples and binaries match your
  # docker images
  LOCAL_VERSION=$(peer version | sed -ne 's/ Version: //p')
  DOCKER_IMAGE_VERSION=$(docker run --rm hyperledger/fabric-tools:$IMAGETAG peer version | sed -ne 's/ Version: //p' | head -1)

  infoln "LOCAL_VERSION=$LOCAL_VERSION"
  infoln "DOCKER_IMAGE_VERSION=$DOCKER_IMAGE_VERSION"

  if [ "$LOCAL_VERSION" != "$DOCKER_IMAGE_VERSION" ]; then
    warnln "Local fabric binaries and docker images are out of  sync. This may cause problems."
  fi

  for UNSUPPORTED_VERSION in $NONWORKING_VERSIONS; do
    infoln "$LOCAL_VERSION" | grep -q $UNSUPPORTED_VERSION
    if [ $? -eq 0 ]; then
      fatalln "Local Fabric binary version of $LOCAL_VERSION does not match the versions supported by the test network."
    fi

    infoln "$DOCKER_IMAGE_VERSION" | grep -q $UNSUPPORTED_VERSION
    if [ $? -eq 0 ]; then
      fatalln "Fabric Docker image version of $DOCKER_IMAGE_VERSION does not match the versions supported by the test network."
    fi
  done

  ## Check for fabric-ca
  if [ "$CRYPTO" == "Certificate Authorities" ]; then

    fabric-ca-client version >/dev/null 2>&1
    if [[ $? -ne 0 ]]; then
      errorln "fabric-ca-client binary not found.."
      errorln
      errorln "Follow the instructions in the Fabric docs to install the Fabric Binaries:"
      errorln "https://hyperledger-fabric.readthedocs.io/en/latest/install.html"
      exit 1
    fi
    CA_LOCAL_VERSION=$(fabric-ca-client version | sed -ne 's/ Version: //p')
    CA_DOCKER_IMAGE_VERSION=$(docker run --rm hyperledger/fabric-ca:$CA_IMAGETAG fabric-ca-client version | sed -ne 's/ Version: //p' | head -1)
    infoln "CA_LOCAL_VERSION=$CA_LOCAL_VERSION"
    infoln "CA_DOCKER_IMAGE_VERSION=$CA_DOCKER_IMAGE_VERSION"

    if [ "$CA_LOCAL_VERSION" != "$CA_DOCKER_IMAGE_VERSION" ]; then
      warnln "Local fabric-ca binaries and docker images are out of sync. This may cause problems."
    fi
  fi
}

function initOrderer() {
  ADMIN_USER=$1
  ADMIN_PWD=$2

  infoln "Enrolling the CA admin"
  mkdir -p organizations/ordererOrganizations

  export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/ordererOrganizations

  set -x
  fabric-ca-client enroll -u https://${ADMIN_USER}:${ADMIN_PWD}@localhost:$CA_ORDERER_PORT --caname ca-orderer --tls.certfiles ${PWD}/organizations/fabric-ca/ordererOrg/tls-cert.pem &>>log.txt
  { set +x; } 2>/dev/null

  echo "NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/localhost-$CA_ORDERER_PORT-ca-orderer.pem
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/localhost-$CA_ORDERER_PORT-ca-orderer.pem
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/localhost-$CA_ORDERER_PORT-ca-orderer.pem
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/localhost-$CA_ORDERER_PORT-ca-orderer.pem
    OrganizationalUnitIdentifier: orderer" >${PWD}/organizations/ordererOrganizations/msp/config.yaml

  infoln "Registering orderer"
  set -x
  fabric-ca-client register --caname ca-orderer --id.name orderer --id.secret ordererpw --id.type orderer --tls.certfiles ${PWD}/organizations/fabric-ca/ordererOrg/tls-cert.pem &>>log.txt
  { set +x; } 2>/dev/null

  infoln "Registering the orderer admin"
  set -x
  fabric-ca-client register --caname ca-orderer --id.name ordererAdmin --id.secret ordererAdminpw --id.type admin --tls.certfiles ${PWD}/organizations/fabric-ca/ordererOrg/tls-cert.pem &>>log.txt
  { set +x; } 2>/dev/null

  infoln "Generating the orderer msp"
  set -x
  fabric-ca-client enroll -u https://orderer:ordererpw@localhost:$CA_ORDERER_PORT --caname ca-orderer -M ${PWD}/organizations/ordererOrganizations/orderers/orderer/msp --csr.hosts orderer --csr.hosts localhost --tls.certfiles ${PWD}/organizations/fabric-ca/ordererOrg/tls-cert.pem &>>log.txt
  { set +x; } 2>/dev/null

  cp ${PWD}/organizations/ordererOrganizations/msp/config.yaml ${PWD}/organizations/ordererOrganizations/orderers/orderer/msp/config.yaml

  infoln "Generating the orderer-tls certificates"
  set -x
  fabric-ca-client enroll -u https://orderer:ordererpw@localhost:$CA_ORDERER_PORT --caname ca-orderer -M ${PWD}/organizations/ordererOrganizations/orderers/orderer/tls --enrollment.profile tls --csr.hosts orderer --csr.hosts localhost --tls.certfiles ${PWD}/organizations/fabric-ca/ordererOrg/tls-cert.pem &>>log.txt
  { set +x; } 2>/dev/null

  cp ${PWD}/organizations/ordererOrganizations/orderers/orderer/tls/tlscacerts/* ${PWD}/organizations/ordererOrganizations/orderers/orderer/tls/ca.crt
  cp ${PWD}/organizations/ordererOrganizations/orderers/orderer/tls/signcerts/* ${PWD}/organizations/ordererOrganizations/orderers/orderer/tls/server.crt
  cp ${PWD}/organizations/ordererOrganizations/orderers/orderer/tls/keystore/* ${PWD}/organizations/ordererOrganizations/orderers/orderer/tls/server.key

  mkdir -p ${PWD}/organizations/ordererOrganizations/orderers/orderer/msp/tlscacerts
  cp ${PWD}/organizations/ordererOrganizations/orderers/orderer/tls/tlscacerts/* ${PWD}/organizations/ordererOrganizations/orderers/orderer/msp/tlscacerts/tlsca-cert.pem

  mkdir -p ${PWD}/organizations/ordererOrganizations/msp/tlscacerts
  cp ${PWD}/organizations/ordererOrganizations/orderers/orderer/tls/tlscacerts/* ${PWD}/organizations/ordererOrganizations/msp/tlscacerts/tlsca-cert.pem

  infoln "Generating the admin msp"
  set -x
  fabric-ca-client enroll -u https://ordererAdmin:ordererAdminpw@localhost:$CA_ORDERER_PORT --caname ca-orderer -M ${PWD}/organizations/ordererOrganizations/users/Admin/msp --tls.certfiles ${PWD}/organizations/fabric-ca/ordererOrg/tls-cert.pem &>>log.txt
  { set +x; } 2>/dev/null

  cp ${PWD}/organizations/ordererOrganizations/msp/config.yaml ${PWD}/organizations/ordererOrganizations/users/Admin/msp/config.yaml
}

function createOrderer() {
  if [ -d "organizations/ordererOrganizations" ]; then
    rm -Rf organizations/ordererOrganizations
  fi
  # Create crypto material using cryptogen
  if [ "$CRYPTO" == "cryptogen" ]; then
    which cryptogen
    if [ "$?" -ne 0 ]; then
      fatalln "cryptogen tool not found. exiting"
    fi
    infoln "Generating certificates using cryptogen tool"

    infoln "Creating Orderer Org Identities"

    set -x
    cryptogen generate --config=./organizations/cryptogen/crypto-config-orderer.yaml --output="organizations"
    res=$?
    { set +x; } 2>/dev/null
    if [ $res -ne 0 ]; then
      fatalln "Failed to generate certificates..."
    fi
  fi
  # Create crypto material using Fabric CA
  if [ "$CRYPTO" == "Certificate Authorities" ]; then
    infoln "Generating certificates using Fabric CA"

    IMAGE_TAG=${CA_IMAGETAG} docker-compose -f $COMPOSE_FILE_CA up -d 2>&1
    infoln "Creating Orderer Org Identities"

    while :; do
      if [ ! -f "organizations/fabric-ca/ordererOrg/tls-cert.pem" ]; then
        sleep 1
      else
        break
      fi
    done
    initOrderer $1 $2
  fi
}

function initOrg() {
  ORGANIZATION=$1
  PEER_CA_PORT=$2
  ADMIN_USER=$3
  ADMIN_PWD=$4

  infoln "Enrolling the CA admin"
  mkdir -p organizations/peerOrganizations/${ORGANIZATION}/

  export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/peerOrganizations/${ORGANIZATION}/

  set -x
  fabric-ca-client enroll -u https://${ADMIN_USER}:${ADMIN_PWD}@localhost:$2 --caname ca-${ORGANIZATION} --tls.certfiles ${PWD}/organizations/fabric-ca/${ORGANIZATION}/tls-cert.pem &>>log.txt
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

function createOrg() {
  # Create crypto material using cryptogen
  if [ "$CRYPTO" == "cryptogen" ]; then
    which cryptogen
    if [ "$?" -ne 0 ]; then
      fatalln "cryptogen tool not found. exiting"
    fi
    infoln "Generating certificates using cryptogen tool"

    infoln "Creating ${1} Organization Identities"

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
    infoln "Generating certificates for $1 Organization using Fabric CA"
    while :; do
      if [ ! -f "organizations/fabric-ca/$1/tls-cert.pem" ]; then
        sleep 1
      else
        break
      fi
    done
    infoln "Creating $1 Identities"
    initOrg $1 $2 $4 $5
  fi

  infoln "Generating CCP files for $1 Organization"
  . ./utils/ccp-generate.sh $1 $2 $3 $NETWORK_NAME
}

function createConsortium() {
  which configtxgen
  if [ "$?" -ne 0 ]; then
    fatalln "configtxgen tool not found."
  fi

  infoln "Generating Orderer Genesis block"

  # Note: For some unknown reason (at least for now) the block file can't be
  # named orderer.genesis.block or the orderer will fail to launch!
  set -x
  configtxgen -profile OrgsOrdererGenesis -channelID system-channel -outputBlock ./system-genesis-block/genesis.block --configPath ${PWD}/config &>>log.txt
  res=$?
  { set +x; } 2>/dev/null
  if [ $res -ne 0 ]; then
    fatalln "Failed to generate orderer genesis block..."
  fi
}

function networkUp() {
  cd ..

  if [ ! -d "docker" ]; then
    mkdir docker
  fi

  cd utils
  sed -i 's/\r//' cli-utils.sh
  sed -i 's/\r//' env.sh
  cd ..

  create_net_yaml $1 $2 $3
  create_couch_yaml $1 $2 $3
  create_ca_yaml $1 $2 $3
  create_configtx_yaml $1 $2 $3 $4
  checkPrereqs

  createOrderer $2 $3

  if [ -d "organizations/peerOrganizations" ]; then
    rm -Rf organizations/peerOrganizations
  fi
  CA_PEER_PORT=$((CA_ORDERER_PORT + 1))
  PEER_PORT=$((ORDERER_PORT + 1))

  createOrg $1 $CA_PEER_PORT $PEER_PORT $2 $3
  CA_PEER_PORT=$((CA_PEER_PORT + 1))
  PEER_PORT=$((PEER_PORT + 1))

  createConsortium

  COMPOSE_FILES="-f ${COMPOSE_FILE_BASE}"

  if [ "${DATABASE}" == "couchdb" ]; then
    COMPOSE_FILES="${COMPOSE_FILES} -f ${COMPOSE_FILE_COUCH}"
  fi

  infoln "Starting Docker containers"

  IMAGE_TAG=$IMAGETAG docker-compose ${COMPOSE_FILES} up -d 2>&1

  docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

  if [ $? -ne 0 ]; then
    fatalln "Unable to start network"
  fi
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
  --delete)
    echo
    printf "${C_RED}Delete containers and ${NETWORK_NAME} network folders${C_RESET}"
    echo
    networkDown
    exit 0
    ;;
  --cc-install-policy)
    CC_INSTALL_POLICY="${2^^}"
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

if [ -z "$CC_INSTALL_POLICY" ]; then
  CC_INSTALL_POLICY="MAJORITY"
fi

if [ "$CC_INSTALL_POLICY" != "ANY" ] && [ "$CC_INSTALL_POLICY" != "MAJORITY" ] && [ $CC_INSTALL_POLICY != "ALL" ]; then
  fatalln "--cc-install-policy flag only supports the values 'ANY', 'MAJORITY' or 'ALL'"
fi

echo
println "Executing with the following"
println "- ORGANIZATION NAME: ${C_GREEN}${ORGANIZATION}${C_RESET}"
println "- ADMIN NAME: ${C_GREEN}${ADMIN_USER}${C_RESET}"
println "- ADMIN PASSWORD: ${C_GREEN}${ADMIN_PWD}${C_RESET}"
println "- CC INSTALL POLICY: ${C_GREEN}${CC_INSTALL_POLICY}${C_RESET}"

networkUp $ORGANIZATION $ADMIN_USER $ADMIN_PWD $CC_INSTALL_POLICY
