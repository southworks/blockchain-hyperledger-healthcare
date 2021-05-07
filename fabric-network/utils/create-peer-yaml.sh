PORT=7050
COUCH_DB_DEFAULT_PORT=5984
COUCH_DB_PORT=5984
NETWORK_NAME=${NETWORK_NAME:="skadar"}
IMAGE_TAG=${IMAGE_TAG:="latest"}
COMPOSE_PROJECT_NAME=docker

function create_peer_yaml() {
  local ORGANIZATION=$1
  local PEER_ID=$2
  local PEER_PORT=$((${PORTS[-1]} + 10))
  local PEER_PORT2=$(($PEER_PORT + 1))

  echo "
version: '2'

volumes:
  peer${PEER_ID}.${ORGANIZATION}:

networks:
  ${NETWORK_NAME}:

services:
  peer${PEER_ID}.${ORGANIZATION}:
    container_name: peer${PEER_ID}.${ORGANIZATION}
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
      - CORE_PEER_ID=peer${PEER_ID}.${ORGANIZATION}
      - CORE_PEER_ADDRESS=peer${PEER_ID}.${ORGANIZATION}:$PEER_PORT
      - CORE_PEER_LISTENADDRESS=0.0.0.0:$PEER_PORT
      - CORE_PEER_CHAINCODEADDRESS=peer${PEER_ID}.${ORGANIZATION}:$PEER_PORT2
      - CORE_PEER_CHAINCODELISTENADDRESS=0.0.0.0:$PEER_PORT2
      - CORE_PEER_GOSSIP_BOOTSTRAP=peer${PEER_ID}.${ORGANIZATION}:$PEER_PORT
      - CORE_PEER_GOSSIP_EXTERNALENDPOINT=peer${PEER_ID}.${ORGANIZATION}:$PEER_PORT
      - CORE_PEER_LOCALMSPID=${ORGANIZATION}
    volumes:
        - /var/run/docker.sock:/host/var/run/docker.sock
        - ../organizations/peerOrganizations/${ORGANIZATION}/peers/peer${PEER_ID}.${ORGANIZATION}/msp:/etc/hyperledger/fabric/msp
        - ../organizations/peerOrganizations/${ORGANIZATION}/peers/peer${PEER_ID}.${ORGANIZATION}/tls:/etc/hyperledger/fabric/tls
        - peer${PEER_ID}.${ORGANIZATION}:/var/hyperledger/production
    working_dir: /opt/gopath/src/github.com/hyperledger/fabric/peer
    command: peer node start
    ports:
      - $PEER_PORT:$PEER_PORT
    networks:
      - $NETWORK_NAME
    " >>docker/docker-compose-${ORGANIZATION}-peer${PEER_ID}.yaml

  # Store port for peer 0 to use in setPeerGlobals
  local ORG_PEER_PORTS=${ORGANIZATION}_peer_PORTS[@]
  echo "${ORGANIZATION}_peer_PORTS=(${!ORG_PEER_PORTS} ${PEER_PORT})" >>utils/port-env.sh

  echo "PORTS=(${PORTS[*]} ${PEER_PORT})" >>utils/port-env.sh
  echo "PORTS=(${PORTS[*]} ${PEER_PORT})" >>utils/port-env.sh

}

function create_peer_couch_yaml() {
  local ORGANIZATION=$1
  local ADMIN_USER=$2
  local ADMIN_PWD=$3
  local PEER_ID=$4
  local COUCH_DB_PORT=$((${COUCH_DB_PORTS[-1]} + 1))
  echo "COUCH_DB_PORTS=(${COUCH_DB_PORTS[*]} ${COUCH_DB_PORT})" >>utils/port-env.sh

  echo "version:  '2'

networks:
  $NETWORK_NAME:

services:
  couchdb${ORGANIZATION}peer${PEER_ID}:
    container_name: couchdb${ORGANIZATION}peer${PEER_ID}
    image: couchdb:3.1.1
    # Populate the COUCHDB_USER and COUCHDB_PASSWORD to set an admin user and password
    # for CouchDB.  This will prevent CouchDB from operating in an "Admin Party" mode.
    environment:
      - COUCHDB_USER=${ADMIN_USER}
      - COUCHDB_PASSWORD=${ADMIN_PWD}
    # Comment/Uncomment the port mapping if you want to hide/expose the CouchDB service,
    # for example map it to utilize Fauxton User Interface in dev environments.
    ports:
      - "$COUCH_DB_PORT:$COUCH_DB_PORT"
    networks:
      - $NETWORK_NAME

  peer${PEER_ID}.${ORGANIZATION}:
    environment:
      - CORE_LEDGER_STATE_STATEDATABASE=CouchDB
      - CORE_LEDGER_STATE_COUCHDBCONFIG_COUCHDBADDRESS=couchdb${ORGANIZATION}peer${PEER_ID}:$COUCH_DB_DEFAULT_PORT
      # The CORE_LEDGER_STATE_COUCHDBCONFIG_USERNAME and CORE_LEDGER_STATE_COUCHDBCONFIG_PASSWORD
      # provide the credentials for ledger to connect to CouchDB.  The username and password must
      # match the username and password set for the associated CouchDB.
      - CORE_LEDGER_STATE_COUCHDBCONFIG_USERNAME=${ADMIN_USER}
      - CORE_LEDGER_STATE_COUCHDBCONFIG_PASSWORD=${ADMIN_PWD}
    depends_on:
      - couchdb${ORGANIZATION}peer${PEER_ID}
    " >>docker/docker-compose-couchdb-${ORGANIZATION}-peer${PEER_ID}.yaml
}
