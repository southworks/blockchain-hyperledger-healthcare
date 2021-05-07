PORT=7050
ORDERER_PORT=7050
CA_PORT=6050
ORDERER_CA_PORT=6050
COUCH_DB_DEFAULT_PORT=5984
COUCH_DB_PORT=5984
NETWORK_NAME=${NETWORK_NAME:="skadar"}
IMAGE_TAG=${IMAGE_TAG:="latest"}
COMPOSE_PROJECT_NAME=docker

function create_net_yaml() {
  ORGANIZATION=${ORGANIZATION}

  echo "
version:  '2'

volumes:
  orderer:" >>docker/docker-compose-net.yaml

  echo "  peer0.${ORGANIZATION}:" >>docker/docker-compose-net.yaml

  echo "
networks:
  $NETWORK_NAME:

services:
  orderer:
    container_name: orderer
    image: hyperledger/fabric-orderer:$IMAGE_TAG
    environment:
      - FABRIC_LOGGING_SPEC=INFO
      - ORDERER_GENERAL_LISTENADDRESS=0.0.0.0
      - ORDERER_GENERAL_LISTENPORT=$PORT
      - ORDERER_GENERAL_GENESISMETHOD=file
      - ORDERER_GENERAL_GENESISFILE=/var/hyperledger/orderer/orderer.genesis.block
      - ORDERER_GENERAL_LOCALMSPID=OrdererMSP
      - ORDERER_GENERAL_LOCALMSPDIR=/var/hyperledger/orderer/msp
      # enabled TLS
      - ORDERER_GENERAL_TLS_ENABLED=true
      - ORDERER_GENERAL_TLS_PRIVATEKEY=/var/hyperledger/orderer/tls/server.key
      - ORDERER_GENERAL_TLS_CERTIFICATE=/var/hyperledger/orderer/tls/server.crt
      - ORDERER_GENERAL_TLS_ROOTCAS=[/var/hyperledger/orderer/tls/ca.crt]
      - ORDERER_KAFKA_TOPIC_REPLICATIONFACTOR=1
      - ORDERER_KAFKA_VERBOSE=true
      - ORDERER_GENERAL_CLUSTER_CLIENTCERTIFICATE=/var/hyperledger/orderer/tls/server.crt
      - ORDERER_GENERAL_CLUSTER_CLIENTPRIVATEKEY=/var/hyperledger/orderer/tls/server.key
      - ORDERER_GENERAL_CLUSTER_ROOTCAS=[/var/hyperledger/orderer/tls/ca.crt]
    working_dir: /opt/gopath/src/github.com/hyperledger/fabric
    command: orderer
    volumes:
        - ../system-genesis-block/genesis.block:/var/hyperledger/orderer/orderer.genesis.block
        - ../organizations/ordererOrganizations/orderers/orderer/msp:/var/hyperledger/orderer/msp
        - ../organizations/ordererOrganizations/orderers/orderer/tls/:/var/hyperledger/orderer/tls
        - orderer:/var/hyperledger/production/orderer
    ports:
      - $PORT:$PORT
    networks:
      - $NETWORK_NAME
" >>docker/docker-compose-net.yaml
  PORT=$((PORT + 10))
  PORT2=$((PORT + 1))
  ORGS=${ORGANIZATION}
  PORTS=${PORT}

  # Store port for peer 0 to use in setPeerGlobals
  echo "${ORGANIZATION}_peer_PORTS=(${PORT})" >>utils/port-env.sh
  echo "${ORGANIZATION}_peers=1" >>utils/port-env.sh

  echo "${ORGANIZATION}_PORT=$PORT" >>utils/port-env.sh
  echo "  peer0.${ORGANIZATION}:
    container_name: peer0.${ORGANIZATION}
    image: hyperledger/fabric-peer:$IMAGE_TAG
    environment:
      #Generic peer variables
      - CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
      # the following setting starts chaincode containers on the same
      # bridge network as the peers
      # https://docs.docker.com/compose/networking/
      - CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=${COMPOSE_PROJECT_NAME}_$NETWORK_NAME
      - FABRIC_LOGGING_SPEC=INFO
      #- FABRIC_LOGGING_SPEC=DEBUG
      - CORE_PEER_TLS_ENABLED=true
      - CORE_PEER_PROFILE_ENABLED=true
      - CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/fabric/tls/server.crt
      - CORE_PEER_TLS_KEY_FILE=/etc/hyperledger/fabric/tls/server.key
      - CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/fabric/tls/ca.crt
      # Peer specific variabes
      - CORE_PEER_ID=peer0.${ORGANIZATION}
      - CORE_PEER_ADDRESS=peer0.${ORGANIZATION}:$PORT
      - CORE_PEER_LISTENADDRESS=0.0.0.0:$PORT
      - CORE_PEER_CHAINCODEADDRESS=peer0.${ORGANIZATION}:$PORT2
      - CORE_PEER_CHAINCODELISTENADDRESS=0.0.0.0:$PORT2
      - CORE_PEER_GOSSIP_BOOTSTRAP=peer0.${ORGANIZATION}:$PORT
      - CORE_PEER_GOSSIP_EXTERNALENDPOINT=peer0.${ORGANIZATION}:$PORT
      - CORE_PEER_LOCALMSPID=${ORGANIZATION}
    volumes:
        - /var/run/docker.sock:/host/var/run/docker.sock
        - ../organizations/peerOrganizations/${ORGANIZATION}/peers/peer0.${ORGANIZATION}/msp:/etc/hyperledger/fabric/msp
        - ../organizations/peerOrganizations/${ORGANIZATION}/peers/peer0.${ORGANIZATION}/tls:/etc/hyperledger/fabric/tls
        - peer0.${ORGANIZATION}:/var/hyperledger/production
    working_dir: /opt/gopath/src/github.com/hyperledger/fabric/peer
    command: peer node start
    ports:
      - $PORT:$PORT
    networks:
      - $NETWORK_NAME
    " >>docker/docker-compose-net.yaml
  echo "ORGS=(${ORGS[*]})" >>utils/port-env.sh
  echo "PORTS=(${ORDERER_PORT} ${PORTS[*]})" >>utils/port-env.sh
  echo "  cli:
    container_name: cli
    image: hyperledger/fabric-tools:${IMAGE_TAG}
    tty: true
    stdin_open: true
    environment:
      - GOPATH=/opt/gopath
      - CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
      - FABRIC_LOGGING_SPEC=INFO
      #- FABRIC_LOGGING_SPEC=DEBUG
    working_dir: /opt/gopath/src/github.com/hyperledger/fabric/peer
    command: /bin/bash
    volumes:
        - /var/run/:/host/var/run/
        - ../organizations:/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations
        - ../scripts:/opt/gopath/src/github.com/hyperledger/fabric/peer/scripts/
        - ../utils:/opt/gopath/src/github.com/hyperledger/fabric/peer/utils/
    depends_on: 
      - peer0.${ORGANIZATION}
    networks:
        - $NETWORK_NAME
    " >>docker/docker-compose-net.yaml
}

function create_couch_yaml() {
  ORGANIZATION=$1
  ADMIN_USER=$2
  ADMIN_PWD=$3
  echo "version:  '2'

networks:
  $NETWORK_NAME:

services:" >docker/docker-compose-couchdb.yaml

  echo "  couchdb${ORGANIZATION}peer0:
    container_name: couchdb${ORGANIZATION}peer0
    image: couchdb:3.1.1
    # Populate the COUCHDB_USER and COUCHDB_PASSWORD to set an admin user and password
    # for CouchDB.  This will prevent CouchDB from operating in an "Admin Party" mode.
    environment:
      - COUCHDB_USER=${ADMIN_USER}
      - COUCHDB_PASSWORD=${ADMIN_PWD}
    # Comment/Uncomment the port mapping if you want to hide/expose the CouchDB service,
    # for example map it to utilize Fauxton User Interface in dev environments.
    ports:
      - "$COUCH_DB_PORT:$COUCH_DB_DEFAULT_PORT"
    networks:
      - $NETWORK_NAME

  peer0.${ORGANIZATION}:
    environment:
      - CORE_LEDGER_STATE_STATEDATABASE=CouchDB
      - CORE_LEDGER_STATE_COUCHDBCONFIG_COUCHDBADDRESS=couchdb${ORGANIZATION}peer0:$COUCH_DB_DEFAULT_PORT
      # The CORE_LEDGER_STATE_COUCHDBCONFIG_USERNAME and CORE_LEDGER_STATE_COUCHDBCONFIG_PASSWORD
      # provide the credentials for ledger to connect to CouchDB.  The username and password must
      # match the username and password set for the associated CouchDB.
      - CORE_LEDGER_STATE_COUCHDBCONFIG_USERNAME=${ADMIN_USER}
      - CORE_LEDGER_STATE_COUCHDBCONFIG_PASSWORD=${ADMIN_PWD}
    depends_on:
      - couchdb${ORGANIZATION}peer0
    " >>docker/docker-compose-couchdb.yaml
  echo "COUCH_DB_PORTS=(${COUCH_DB_PORT})" >>utils/port-env.sh
}

function create_ca_yaml() {
  ORGANIZATION=$1
  ADMIN_USER=$2
  ADMIN_PWD=$3

  echo "version: '2'
networks:
  $NETWORK_NAME:
services:
  ca_orderer:
    image: hyperledger/fabric-ca:$IMAGE_TAG
    environment:
      - FABRIC_CA_HOME=/etc/hyperledger/fabric-ca-server
      - FABRIC_CA_SERVER_CA_NAME=ca-orderer
      - FABRIC_CA_SERVER_TLS_ENABLED=true
      - FABRIC_CA_SERVER_PORT=$CA_PORT
    ports:
      - "$CA_PORT:$CA_PORT"
    command: sh -c 'fabric-ca-server start -b ${ADMIN_USER}:${ADMIN_PWD} -d'
    volumes:
      - ../organizations/fabric-ca/ordererOrg:/etc/hyperledger/fabric-ca-server
    container_name: ca_orderer
    networks:
      - $NETWORK_NAME" >>docker/docker-compose-ca.yaml
  CA_PORT=$((CA_PORT + 1))
  echo "CA_${ORGANIZATION}_PORT=$CA_PORT" >>utils/port-env.sh
  echo "  ca_${ORGANIZATION}:
    image: hyperledger/fabric-ca:$IMAGE_TAG
    environment:
      - FABRIC_CA_HOME=/etc/hyperledger/fabric-ca-server
      - FABRIC_CA_SERVER_CA_NAME=ca-${ORGANIZATION}
      - FABRIC_CA_SERVER_TLS_ENABLED=true
      - FABRIC_CA_SERVER_PORT=$CA_PORT
    ports:
      - "$CA_PORT:$CA_PORT"
    command: sh -c 'fabric-ca-server start -b ${ADMIN_USER}:${ADMIN_PWD} -d'
    volumes:
      - ../organizations/fabric-ca/${ORGANIZATION}:/etc/hyperledger/fabric-ca-server
    container_name: ca_${ORGANIZATION}
    networks:
      - $NETWORK_NAME" >>docker/docker-compose-ca.yaml
  echo "CA_PORTS=(${ORDERER_CA_PORT} ${CA_PORT})" >>utils/port-env.sh
}

function create_configtx_yaml() {
  local ORGANIZATION=${ORGANIZATION}
  local ADMIN_USER=${ADMIN_USER}
  local ADMIN_PWD=${ADMIN_PWD}
  local CC_INSTALL_POLICY=${CC_INSTALL_POLICY}
  if [ ! -d "config" ]; then
    mkdir config
  fi
  echo "
Organizations:
    - &OrdererOrg
        Name: OrdererOrg
        ID: OrdererMSP
        MSPDir: ../organizations/ordererOrganizations/msp
        Policies:
            Readers:
                Type: Signature
                Rule: \"""OR('OrdererMSP.member')"\""
            Writers:
                Type: Signature
                Rule: \"""OR('OrdererMSP.member')"\""
            Admins:
                Type: Signature
                Rule: \"""OR('OrdererMSP.admin')"\""

        OrdererEndpoints:
            - orderer:$ORDERER_PORT
  " >config/configtx.yaml
  for org in ${ORGS[*]}; do
    echo " 
    - &${org}
        Name: ${org}
        ID: ${org}
        MSPDir: ../organizations/peerOrganizations/${org}/msp
        Policies:
            Readers:
                Type: Signature
                Rule: \"""OR('${org}.admin', '${org}.peer', '${org}.client')""\"
            Writers:
                Type: Signature
                Rule: \"""OR('${org}.admin', '${org}.client')""\"
            Admins:
                Type: Signature
                Rule: \"""OR('${org}.admin')""\"
            Endorsement:
                Type: Signature
                Rule: \"""OR('${org}.peer')""\"
    " >>config/configtx.yaml
  done
  echo "
Capabilities:
    Channel: &ChannelCapabilities
        V2_0: true
    Orderer: &OrdererCapabilities
        V2_0: true
    Application: &ApplicationCapabilities
        V2_0: true

Application: &ApplicationDefaults
    ACLs: &ACLsDefault
        # ACL policy for _lifecycle's \"CheckCommitReadiness\" function
        _lifecycle/CheckCommitReadiness: /Channel/Application/Writers

        # ACL policy for _lifecycle's \"CommitChaincodeDefinition\" function
        _lifecycle/CommitChaincodeDefinition: /Channel/Application/Writers

        # ACL policy for _lifecycle's \"QueryChaincodeDefinition\" function
        _lifecycle/QueryChaincodeDefinition: /Channel/Application/Readers

        # ACL policy for _lifecycle's \"QueryChaincodeDefinitions\" function
        _lifecycle/QueryChaincodeDefinitions: /Channel/Application/Readers

        #---Lifecycle System Chaincode (lscc) function to policy mapping for access control---#

        # ACL policy for lscc's \"getid\" function
        lscc/ChaincodeExists: /Channel/Application/Readers

        # ACL policy for lscc's \"getdepspec\" function
        lscc/GetDeploymentSpec: /Channel/Application/Readers

        # ACL policy for lscc's \"getccdata\" function
        lscc/GetChaincodeData: /Channel/Application/Readers

        # ACL Policy for lscc's \"getchaincodes\" function
        lscc/GetInstantiatedChaincodes: /Channel/Application/Readers

        #---Query System Chaincode (qscc) function to policy mapping for access control---#

        # ACL policy for qscc's \"GetChainInfo\" function
        qscc/GetChainInfo: /Channel/Application/Readers

        # ACL policy for qscc's \"GetBlockByNumber\" function
        qscc/GetBlockByNumber: /Channel/Application/Readers

        # ACL policy for qscc's  \"GetBlockByHash\" function
        qscc/GetBlockByHash: /Channel/Application/Readers

        # ACL policy for qscc's \"GetTransactionByID\" function
        qscc/GetTransactionByID: /Channel/Application/Readers

        # ACL policy for qscc's \"GetBlockByTxID\" function
        qscc/GetBlockByTxID: /Channel/Application/Readers

        #---Configuration System Chaincode (cscc) function to policy mapping for access control---#

        # ACL policy for cscc's \"GetConfigBlock\" function
        cscc/GetConfigBlock: /Channel/Application/Readers

        # ACL policy for cscc's \"GetConfigTree\" function
        cscc/GetConfigTree: /Channel/Application/Readers

        # ACL policy for cscc's \"SimulateConfigTreeUpdate\" function
        cscc/SimulateConfigTreeUpdate: /Channel/Application/Readers

        #---Miscellaneous peer function to policy mapping for access control---#

        # ACL policy for invoking chaincodes on peer
        peer/Propose: /Channel/Application/Writers

        # ACL policy for chaincode to chaincode invocation
        peer/ChaincodeToChaincode: /Channel/Application/Readers

        #---Events resource to policy mapping for access control###---#

        # ACL policy for sending block events
        event/Block: /Channel/Application/Readers

        # ACL policy for sending filtered block events
        event/FilteredBlock: /Channel/Application/Readers

    Organizations:
    Policies:
        Readers:
            Type: ImplicitMeta
            Rule: \"""ANY Readers""\"
        Writers:
            Type: ImplicitMeta
            Rule: \"""ANY Writers""\"
        Admins:
            Type: ImplicitMeta
            Rule: \"""MAJORITY Admins""\"
        LifecycleEndorsement:
            Type: ImplicitMeta
            Rule: \"""${CC_INSTALL_POLICY} Endorsement""\"
        Endorsement:
            Type: ImplicitMeta
            Rule: \"""${CC_INSTALL_POLICY} Endorsement""\"

    Capabilities:
        <<: *ApplicationCapabilities

Orderer: &OrdererDefaults
    OrdererType: etcdraft
    Addresses:
        - orderer:${ORDERER_PORT}
    EtcdRaft:
        Consenters:
        - Host: orderer
          Port: ${ORDERER_PORT}
          ClientTLSCert: ../organizations/ordererOrganizations/orderers/orderer/tls/server.crt
          ServerTLSCert: ../organizations/ordererOrganizations/orderers/orderer/tls/server.crt
    BatchTimeout: 2s
    BatchSize:
        MaxMessageCount: 10
        AbsoluteMaxBytes: 99 MB
        PreferredMaxBytes: 512 KB
    Organizations:
    Policies:
        Readers:
            Type: ImplicitMeta
            Rule: \"""ANY Readers""\"
        Writers:
            Type: ImplicitMeta
            Rule: \"""ANY Writers""\"
        Admins:
            Type: ImplicitMeta
            Rule: \"""MAJORITY Admins""\"
        BlockValidation:
            Type: ImplicitMeta
            Rule: \"""ANY Writers""\"

Channel: &ChannelDefaults
    Policies:
        Readers:
            Type: ImplicitMeta
            Rule: \"""ANY Readers""\"
        Writers:
            Type: ImplicitMeta
            Rule: \"""ANY Writers""\"
        Admins:
            Type: ImplicitMeta
            Rule: \"""MAJORITY Admins""\"

    Capabilities:
        <<: *ChannelCapabilities

Profiles:
    OrgsOrdererGenesis:
        <<: *ChannelDefaults
        Orderer:
            <<: *OrdererDefaults
            Organizations:
                - *OrdererOrg
            Capabilities:
                <<: *OrdererCapabilities
        Consortiums:
            SampleConsortium:
                Organizations:" >>config/configtx.yaml
  for org in ${ORGS[*]}; do
    echo "                    - *${org}" >>config/configtx.yaml
  done
  echo "
    OrgsChannel:
        Consortium: SampleConsortium
        <<: *ChannelDefaults
        Application:
            <<: *ApplicationDefaults
            Organizations:" >>config/configtx.yaml
  for org in ${ORGS[*]}; do
    echo "                - *${org}" >>config/configtx.yaml
  done
  echo "        Capabilities:
            <<: *ApplicationCapabilities" >>config/configtx.yaml
}

## -------------------------------------- YAML files to create a new organization -------------------------------------- ##

function create_net_org_yaml() {
  echo "
version:  '2'

volumes:" >>docker/docker-compose-${ORGANIZATION}.yaml

  echo "  peer0.${ORGANIZATION}:" >>docker/docker-compose-${ORGANIZATION}.yaml

  echo "
networks:
  $NETWORK_NAME:

services:
" >>docker/docker-compose-${ORGANIZATION}.yaml
  local PORT=$((${PORTS[-1]} + 10))
  local PORT2=$((PORT + 1))
  echo "${ORGANIZATION}_PORT=$PORT" >>utils/port-env.sh
  echo "  peer0.${ORGANIZATION}:
    container_name: peer0.${ORGANIZATION}
    image: hyperledger/fabric-peer:$IMAGE_TAG
    environment:
      #Generic peer variables
      - CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
      # the following setting starts chaincode containers on the same
      # bridge network as the peers
      # https://docs.docker.com/compose/networking/
      - CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=${COMPOSE_PROJECT_NAME}_$NETWORK_NAME
      - FABRIC_LOGGING_SPEC=INFO
      #- FABRIC_LOGGING_SPEC=DEBUG
      - CORE_PEER_TLS_ENABLED=true
      - CORE_PEER_PROFILE_ENABLED=true
      - CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/fabric/tls/server.crt
      - CORE_PEER_TLS_KEY_FILE=/etc/hyperledger/fabric/tls/server.key
      - CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/fabric/tls/ca.crt
      # Peer specific variabes
      - CORE_PEER_ID=peer0.${ORGANIZATION}
      - CORE_PEER_ADDRESS=peer0.${ORGANIZATION}:$PORT
      - CORE_PEER_LISTENADDRESS=0.0.0.0:$PORT
      - CORE_PEER_CHAINCODEADDRESS=peer0.${ORGANIZATION}:$PORT2
      - CORE_PEER_CHAINCODELISTENADDRESS=0.0.0.0:$PORT2
      - CORE_PEER_GOSSIP_BOOTSTRAP=peer0.${ORGANIZATION}:$PORT
      - CORE_PEER_GOSSIP_EXTERNALENDPOINT=peer0.${ORGANIZATION}:$PORT
      - CORE_PEER_LOCALMSPID=${ORGANIZATION}
    volumes:
        - /var/run/docker.sock:/host/var/run/docker.sock
        - ../organizations/peerOrganizations/${ORGANIZATION}/peers/peer0.${ORGANIZATION}/msp:/etc/hyperledger/fabric/msp
        - ../organizations/peerOrganizations/${ORGANIZATION}/peers/peer0.${ORGANIZATION}/tls:/etc/hyperledger/fabric/tls
        - peer0.${ORGANIZATION}:/var/hyperledger/production
    working_dir: /opt/gopath/src/github.com/hyperledger/fabric/peer
    command: peer node start
    ports:
      - $PORT:$PORT
    networks:
      - $NETWORK_NAME
    " >>docker/docker-compose-${ORGANIZATION}.yaml
  echo "ORGS=(${ORGS[*]} ${ORGANIZATION})" >>utils/port-env.sh
  echo "PORTS=(${PORTS[*]} ${PORT})" >>utils/port-env.sh

  # Store port for peer 0 to use in setPeerGlobals
  echo "${ORGANIZATION}_peer_PORTS=(${PORT})" >>utils/port-env.sh
  echo "${ORGANIZATION}_peers=1" >>utils/port-env.sh
}

function create_couch_org_yaml() {
  local COUCH_DB_PORT=$((${COUCH_DB_PORTS[-1]} + 1))
  echo "version:  '2'

networks:
  $NETWORK_NAME:

services:" >docker/docker-compose-couchdb-${ORGANIZATION}.yaml

  echo "  couchdb${ORGANIZATION}peer0:
    container_name: couchdb${ORGANIZATION}peer0
    image: couchdb:3.1.1
    # Populate the COUCHDB_USER and COUCHDB_PASSWORD to set an admin user and password
    # for CouchDB.  This will prevent CouchDB from operating in an "Admin Party" mode.
    environment:
      - COUCHDB_USER=${ADMIN_USER}
      - COUCHDB_PASSWORD=${ADMIN_PWD}
    # Comment/Uncomment the port mapping if you want to hide/expose the CouchDB service,
    # for example map it to utilize Fauxton User Interface in dev environments.
    ports:
      - "$COUCH_DB_PORT:$COUCH_DB_DEFAULT_PORT"
    networks:
      - $NETWORK_NAME

  peer0.${ORGANIZATION}:
    environment:
      - CORE_LEDGER_STATE_STATEDATABASE=CouchDB
      - CORE_LEDGER_STATE_COUCHDBCONFIG_COUCHDBADDRESS=couchdb${ORGANIZATION}peer0:$COUCH_DB_DEFAULT_PORT
      # The CORE_LEDGER_STATE_COUCHDBCONFIG_USERNAME and CORE_LEDGER_STATE_COUCHDBCONFIG_PASSWORD
      # provide the credentials for ledger to connect to CouchDB.  The username and password must
      # match the username and password set for the associated CouchDB.
      - CORE_LEDGER_STATE_COUCHDBCONFIG_USERNAME=${ADMIN_USER}
      - CORE_LEDGER_STATE_COUCHDBCONFIG_PASSWORD=${ADMIN_PWD}
    depends_on:
      - couchdb${ORGANIZATION}peer0
    " >>docker/docker-compose-couchdb-${ORGANIZATION}.yaml
  echo "COUCH_DB_PORTS=(${COUCH_DB_PORTS[*]} ${COUCH_DB_PORT})" >>utils/port-env.sh
}

function create_ca_org_yaml() {
  local CA_PORT=$((${CA_PORTS[-1]} + 1))
  echo "version: '2'
networks:
  $NETWORK_NAME:
services:" >>docker/docker-compose-ca-${ORGANIZATION}.yaml
  echo "CA_${ORGANIZATION}_PORT=$CA_PORT" >>utils/port-env.sh
  echo "  ca_${ORGANIZATION}:
    image: hyperledger/fabric-ca:$IMAGE_TAG
    environment:
      - FABRIC_CA_HOME=/etc/hyperledger/fabric-ca-server
      - FABRIC_CA_SERVER_CA_NAME=ca-${ORGANIZATION}
      - FABRIC_CA_SERVER_TLS_ENABLED=true
      - FABRIC_CA_SERVER_PORT=$CA_PORT
    ports:
      - "$CA_PORT:$CA_PORT"
    command: sh -c 'fabric-ca-server start -b ${ADMIN_USER}:${ADMIN_PWD} -d'
    volumes:
      - ../organizations/fabric-ca/${ORGANIZATION}:/etc/hyperledger/fabric-ca-server
    container_name: ca_${ORGANIZATION}
    networks:
      - $NETWORK_NAME" >>docker/docker-compose-ca-${ORGANIZATION}.yaml
  echo "CA_PORTS=(${CA_PORTS[*]} ${CA_PORT})" >>utils/port-env.sh
}

function create_configtx_org_yaml() {
  mkdir config/${ORGANIZATION}
  echo "Organizations:
    - &${ORGANIZATION}
        Name: ${ORGANIZATION}
        ID: ${ORGANIZATION}
        MSPDir: ../../organizations/peerOrganizations/${ORGANIZATION}/msp
        Policies:
            Readers:
                Type: Signature
                Rule: \"""OR('${ORGANIZATION}.admin', '${ORGANIZATION}.peer', '${ORGANIZATION}.client')""\"
            Writers:
                Type: Signature
                Rule: \"""OR('${ORGANIZATION}.admin', '${ORGANIZATION}.client')""\"
            Admins:
                Type: Signature
                Rule: \"""OR('${ORGANIZATION}.admin')""\"
            Endorsement:
                Type: Signature
                Rule: \"""OR('${ORGANIZATION}.peer')""\"
    " >config/${ORGANIZATION}/configtx.yaml
}
