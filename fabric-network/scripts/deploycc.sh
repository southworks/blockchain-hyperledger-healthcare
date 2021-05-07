#!/bin/bash
. ../utils/cli-utils.sh
. ../utils/env.sh
export PATH=${PWD}/bin:$PATH

# Print the usage message
function printHelp() {
  println "Usage: "
  println "  chaincode [mode: deploy/invoke]"
  println "  chaincode deploy - Deploy a chaincode"
  println "  chaincode [deploy-org/deploy-peer]"
  println "    chaincode deploy-org - Deploy a chaincode on an organization"
  println "      chaincode deploy-org [--cc-name <cc name>] [--cc-path <cc path>] [--cc-version <cc version>]"
  println "                           [--cc-sequence <cc sequence>] [--org <organization name>] [--channel-name <channel name>]"
  println "        chaincode deploy-org --help (print this message)"
  println "          --cc-name <cc name> - Chaincode name"
  println "          --cc-path <cc path> - Chaincode path"
  println "          --cc-version <cc version> - Chaincode version"
  println "          --cc-sequence <cc sequence> - Chaincode sequence"
  println "          --org <organization name> - Name of the organization where the chaincode will be installed (could be more than one)"
  println "          --channel-name <channel name> - Name of the channel where the chaincode will be installed"
  println "          Examples:"
  println "            chaincode deploy-org --cc-name chaincode --cc-path ../chaincode/ --cc-version 1.1 --cc-sequence 1 --org org1 --channel-name channel01"
  println "    chaincode deploy-peer - Deploy a chaincode on a peer"
  println "      chaincode deploy-peer [--cc-name <cc name>] [--peer <peer ID>] [--org <organization name>] [--channel-name <channel name>]"
  println "        chaincode deploy-peer --help (print this message)"
  println "          --cc-name <cc name> - Chaincode name"
  println "          --peer <peer ID> - Peer ID"
  println "          --org <organization name> - Name of the organization where the chaincode will be installed (could be more than one)"
  println "          --channel-name <channel name> - Name of the channel where the chaincode will be installed"
  println "          Examples:"
  println "            chaincode deploy-peer --cc-name chaincode --peer 1 --org org1 --channel-name channel01"
  println "  chaincode invoke - Invoke a chaincode method"
  println "    chaincode invoke [--cc-name <cc name>] [--cc-args <cc arguments>] [--user-name <username>]"
  println "                     [--org <organization name>] [--channel-name <channel name>]"
  println "      chaincode invoke --help (print this message)"
  println "        --cc-name <cc name> - Chaincode name"
  println "        --cc-args <cc path> - Chaincode arguments with the method name that will be invoked"
  println "        --user-name <username> - User name of the invoker user"
  println "        --org <organization name> - Name of the organization where the chaincode is installed"
  println "        --channel-name <channel name> - Name of the channel where the chaincode is installed"
  println "        Examples:"
  println "          chaincode invoke --cc-name chaincode --cc-args '{\"Args\":[\"methodName\",\"arg1\"]}' --user-name user --org org1 --channel-name channel01"

}

function buildCC() {
  CC_SRC_LANGUAGE=${CC_SRC_LANGUAGE}
  CC_INIT_FCN=${CC_INIT_FCN:-"NA"}
  CC_END_POLICY=${SIGNATURE_POLICY:-"NA"}
  CC_COLL_CONFIG=${CC_COLL_CONFIG:-"NA"}
  DELAY=${DELAY:-"3"}
  MAX_RETRY=${MAX_RETRY:-"5"}
  VERBOSE=${VERBOSE:-"false"}

  println "executing with the following"
  println "- CC_NAME: ${C_GREEN}${CC_NAME}${C_RESET}"
  println "- CC_SRC_PATH: ${C_GREEN}${CC_SRC_PATH}${C_RESET}"
  println "- CC_SRC_LANGUAGE: ${C_GREEN}${CC_SRC_LANGUAGE}${C_RESET}"
  println "- CC_VERSION: ${C_GREEN}${CC_VERSION}${C_RESET}"
  println "- CHANNEL_NAME: ${C_GREEN}${CHANNEL_NAME}${C_RESET}"
  println "- CC_SEQUENCE: ${C_GREEN}${CC_SEQUENCE}${C_RESET}"
  println "- CC_END_POLICY: ${C_GREEN}${CC_END_POLICY}${C_RESET}"
  println "- CC_COLL_CONFIG: ${C_GREEN}${CC_COLL_CONFIG}${C_RESET}"
  println "- CC_INIT_FCN: ${C_GREEN}${CC_INIT_FCN}${C_RESET}"
  println "- DELAY: ${C_GREEN}${DELAY}${C_RESET}"
  println "- MAX_RETRY: ${C_GREEN}${MAX_RETRY}${C_RESET}"
  println "- VERBOSE: ${C_GREEN}${VERBOSE}${C_RESET}"

  CC_SRC_LANGUAGE=$(echo "$CC_SRC_LANGUAGE" | tr [:upper:] [:lower:])

  # do some language specific preparation to the chaincode before packaging
  if [ "$CC_SRC_LANGUAGE" = "go" ]; then
    CC_RUNTIME_LANGUAGE=golang

    infoln "Vendoring Go dependencies at $CC_SRC_PATH"
    pushd $CC_SRC_PATH
    GO111MODULE=on go mod vendor
    popd
    successln "Finished vendoring Go dependencies"

  elif [ "$CC_SRC_LANGUAGE" = "java" ]; then
    CC_RUNTIME_LANGUAGE=java

    infoln "Compiling Java code..."
    pushd $CC_SRC_PATH
    ./gradlew installDist
    popd
    successln "Finished compiling Java code"
    CC_SRC_PATH=$CC_SRC_PATH/build/install/$CC_NAME

  elif [ "$CC_SRC_LANGUAGE" = "javascript" ]; then
    CC_RUNTIME_LANGUAGE=node

  elif [ "$CC_SRC_LANGUAGE" = "typescript" ]; then
    CC_RUNTIME_LANGUAGE=node

    infoln "Compiling TypeScript code into JavaScript..."
    pushd $CC_SRC_PATH
    npm install
    npm run build
    popd
    successln "Finished compiling TypeScript code into JavaScript"

  else
    fatalln "The chaincode language ${CC_SRC_LANGUAGE} is not supported by this script. Supported chaincode languages are: go, java, javascript, and typescript"
    exit 1
  fi

  INIT_REQUIRED="--init-required"
  # check if the init fcn should be called
  if [ "$CC_INIT_FCN" = "NA" ]; then
    INIT_REQUIRED=""
  fi

  if [ "$CC_END_POLICY" = "NA" ]; then
    CC_END_POLICY=""
  else
    CC_END_POLICY="--signature-policy $CC_END_POLICY"
  fi

  if [ "$CC_COLL_CONFIG" = "NA" ]; then
    CC_COLL_CONFIG=""
  else
    CC_COLL_CONFIG="--collections-config $CC_COLL_CONFIG"
  fi
}

function buildSignaturePolicy() {
  . ./utils/port-env.sh
  for org in ${ORGS[*]}; do
    if [ "${SIGNATURE}" != "" ]; then
      SIGNATURE=${SIGNATURE},
    fi
    RULE="'${org}.peer'"
    SIGNATURE=${SIGNATURE}${RULE}
  done
  SIGNATURE_POLICY="AND(${SIGNATURE})"
}

function packageChaincode() {
  infoln "Package ${CC_NAME} chaincode"
  set -x
  peer lifecycle chaincode package ${CC_NAME}.tar.gz --path ${CC_SRC_PATH} --lang ${CC_RUNTIME_LANGUAGE} --label ${CC_NAME}_${CC_VERSION} >&deploy-log.txt
  res=$?
  { set +x; } 2>/dev/null
  cat deploy-log.txt
  verifyResult $res "Chaincode packaging has failed"
  successln "Chaincode is packaged"
}

function installChaincode() {
  . ./utils/port-env.sh

  local ORG=$1

  if [ ! -d "package" ]; then
    mkdir package
  fi

  ORG_PEERS=$((${ORG}_peers))

  # Iterate through org's peers to install the chaincode
  for ((i = 0; i < $ORG_PEERS; i += 1)); do
    setPeerGlobals $ORG $i
    set -x
    peer lifecycle chaincode install ${CC_NAME}.tar.gz --peerAddresses $CORE_PEER_ADDRESS --tlsRootCertFiles $CORE_PEER_TLS_ROOTCERT_FILE >&deploy-log.txt
    res=$?
    { set +x; } 2>/dev/null
    cat deploy-log.txt
    verifyResult $res "Chaincode installation on peer${peer}.${ORG} has failed"
    successln "Chaincode ${CC_NAME} is installed on peer${i}.${ORG}"
  done
}

function installPeerChaincode() {
  cd ..
  local ORG=$1
  local PEER=$2
  setPeerGlobals $ORG $PEER
  set -x
  peer lifecycle chaincode install package/${CC_NAME}.tar.gz --peerAddresses $CORE_PEER_ADDRESS --tlsRootCertFiles $CORE_PEER_TLS_ROOTCERT_FILE &>>log.txt
  res=$?
  { set +x; } 2>/dev/null
  verifyResult $res "Chaincode installation on peer${peer}.${ORG} has failed"
  successln "Chaincode ${CC_NAME} is installed on peer${i}.${ORG}"
}

function queryInstalled() {
  ORG=$1
  setGlobals $ORG
  set -x
  peer lifecycle chaincode queryinstalled >&deploy-log.txt
  res=$?
  { set +x; } 2>/dev/null
  cat deploy-log.txt
  PACKAGE_ID=$(sed -n "/${CC_NAME}_${CC_VERSION}/{s/^Package ID: //; s/, Label:.*$//; p;}" deploy-log.txt)
  verifyResult $res "Query installed on peer0.${ORG} has failed"
  successln "Query installed successful on peer0.${ORG} on channel"
}

function approveForMyOrg() {
  ORG=$1
  setGlobals $ORG
  set -x
  peer lifecycle chaincode approveformyorg -o localhost:$ORDERER_PORT --ordererTLSHostnameOverride orderer --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA --channelID $CHANNEL_NAME --name ${CC_NAME} --version ${CC_VERSION} --package-id ${PACKAGE_ID} --sequence ${CC_SEQUENCE} ${INIT_REQUIRED} ${CC_END_POLICY} ${CC_COLL_CONFIG} >&deploy-log.txt
  res=$?
  { set +x; } 2>/dev/null
  cat deploy-log.txt
  verifyResult $res "Chaincode definition approved on peer0.${ORG} on channel '$CHANNEL_NAME' failed"
  successln "Chaincode definition approved on peer0.${ORG} on channel '$CHANNEL_NAME'"
}

function checkCommitReadiness() {
  ORG=$1
  shift 1
  setGlobals $ORG
  infoln "Checking the commit readiness of the chaincode definition on peer0.${ORG} on channel '$CHANNEL_NAME'..."
  local rc=1
  local COUNTER=1
  # continue to poll
  # we either get a successful response, or reach MAX RETRY
  while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ]; do
    sleep $DELAY
    infoln "Attempting to check the commit readiness of the chaincode definition on peer0.${ORG}, Retry after $DELAY seconds."
    set -x
    peer lifecycle chaincode checkcommitreadiness --channelID $CHANNEL_NAME --name ${CC_NAME} --version ${CC_VERSION} --sequence ${CC_SEQUENCE} ${INIT_REQUIRED} ${CC_END_POLICY} ${CC_COLL_CONFIG} --output json >&deploy-log.txt
    res=$?
    { set +x; } 2>/dev/null
    let rc=0
    for var in "$@"; do
      grep "$var" deploy-log.txt &>/dev/null || let rc=1
    done
    COUNTER=$(expr $COUNTER + 1)
  done
  cat deploy-log.txt
  if test $rc -eq 0; then
    infoln "Checking the commit readiness of the chaincode definition successful on peer0.${ORG} on channel '$CHANNEL_NAME'"
  else
    fatalln "After $MAX_RETRY attempts, Check commit readiness result on peer0.${ORG} is INVALID!"
  fi
}

function commitChaincodeDefinition() {
  parsePeerConnectionParameters $@
  res=$?
  verifyResult $res "Invoke transaction failed on channel '$CHANNEL_NAME' due to uneven number of peer and org parameters "

  # while 'peer chaincode' command can get the orderer endpoint from the
  # peer (if join was successful), let's supply it directly as we know
  # it using the "-o" option
  set -x
  peer lifecycle chaincode commit -o localhost:$ORDERER_PORT --ordererTLSHostnameOverride orderer --tls --cafile $ORDERER_CA --channelID $CHANNEL_NAME --name ${CC_NAME} $PEER_CONN_PARMS --version ${CC_VERSION} --sequence ${CC_SEQUENCE} ${INIT_REQUIRED} ${CC_END_POLICY} ${CC_COLL_CONFIG} >&deploy-log.txt
  res=$?
  { set +x; } 2>/dev/null
  cat deploy-log.txt
  verifyResult $res "Chaincode definition commit failed on peer0.${ORG} on channel '$CHANNEL_NAME' failed"
  successln "Chaincode definition committed on channel '$CHANNEL_NAME'"
}

function queryCommitted() {
  ORG=$1
  setGlobals $ORG
  EXPECTED_RESULT="Version: ${CC_VERSION}, Sequence: ${CC_SEQUENCE}, Endorsement Plugin: escc, Validation Plugin: vscc"
  infoln "Querying chaincode definition on peer0.${ORG} on channel '$CHANNEL_NAME'..."
  local rc=1
  local COUNTER=1
  # continue to poll
  # we either get a successful response, or reach MAX RETRY
  while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ]; do
    sleep $DELAY
    infoln "Attempting to Query committed status on peer0.${ORG}, Retry after $DELAY seconds."
    set -x
    peer lifecycle chaincode querycommitted --channelID $CHANNEL_NAME --name ${CC_NAME} >&deploy-log.txt
    res=$?
    { set +x; } 2>/dev/null
    test $res -eq 0 && VALUE=$(cat deploy-log.txt | grep -o '^Version: '$CC_VERSION', Sequence: [0-9]*, Endorsement Plugin: escc, Validation Plugin: vscc')
    test "$VALUE" = "$EXPECTED_RESULT" && let rc=0
    COUNTER=$(expr $COUNTER + 1)
  done
  cat deploy-log.txt
  if test $rc -eq 0; then
    successln "Query chaincode definition successful on peer0.${ORG} on channel '$CHANNEL_NAME'"
  else
    fatalln "After $MAX_RETRY attempts, Query chaincode definition result on peer0.${ORG} is INVALID!"
  fi
}

function chaincodeInvokeInit() {
  . ./utils/port-env.sh
  parsePeerConnectionParameters ${ORGS[*]}
  setGlobals $1
  res=$?
  verifyResult $res "Invoke transaction failed on channel '$CHANNEL_NAME' due to uneven number of peer and org parameters "

  # while 'peer chaincode' command can get the orderer endpoint from the
  # peer (if join was successful), let's supply it directly as we know
  # it using the "-o" option
  set -x
  fcn_call='{"function":"'${CC_INIT_FCN}'","Args":[]}'
  infoln "invoke fcn call:${fcn_call}"
  peer chaincode invoke -o localhost:$ORDERER_PORT --ordererTLSHostnameOverride orderer --tls --cafile $ORDERER_CA -C $CHANNEL_NAME -n ${CC_NAME} $PEER_CONN_PARMS --isInit -c "${fcn_call}" >&deploy-log.txt
  res=$?
  { set +x; } 2>/dev/null
  cat deploy-log.txt
  verifyResult $res "Invoke execution on $PEERS failed "
  successln "Invoke transaction successful on $PEERS on channel '$CHANNEL_NAME'"
}

function chaincodeInvoke() {
  cd ..

  export FABRIC_CFG_PATH=$PWD/scripts/config/
  export ORDERER_CA=${PWD}/organizations/ordererOrganizations/orderers/orderer/msp/tlscacerts/tlsca-cert.pem
  . ./utils/port-env.sh

  PEER_ID=$3
  OWNER_ORG=$1

  if [ -z "$PEER_ID" ]; then
    parsePeerConnectionParameters ${ORGS[*]}
    setGlobals $1
  else
    parseOrganizationPeerConnectionParameters $OWNER_ORG $PEER_ID
    setPeerGlobals $1 $PEER_ID
  fi

  res=$?
  verifyResult $res "Invoke transaction failed on channel '$CHANNEL_NAME' due to uneven number of peer and org parameters "
  export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/${1}/users/${2}@${1}/msp
  set -x
  infoln "invoke fcn call:${fcn_call}"
  peer chaincode invoke -o localhost:$ORDERER_PORT --ordererTLSHostnameOverride orderer --tls --cafile $ORDERER_CA -C $CHANNEL_NAME -n ${CC_NAME} $PEER_CONN_PARMS -c "${fcn_call}" >&deploy-log.txt
  res=$?
  { set +x; } 2>/dev/null
  cat deploy-log.txt
  verifyResult $res "Invoke execution on $PEERS failed "
  successln "Invoke transaction successful on $PEERS on channel '$CHANNEL_NAME'"
}

function chaincodeQuery() {
  ORG=$1
  setGlobals $ORG
  infoln "Querying on peer0.${ORG} on channel '$CHANNEL_NAME'..."
  local rc=1
  local COUNTER=1
  # continue to poll
  # we either get a successful response, or reach MAX RETRY
  while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ]; do
    sleep $DELAY
    infoln "Attempting to Query peer0.${ORG}, Retry after $DELAY seconds."
    set -x
    peer chaincode query -C $CHANNEL_NAME -n ${CC_NAME} -c '{"Args":["queryAllCars"]}' >&deploy-log.txt
    res=$?
    { set +x; } 2>/dev/null
    let rc=$res
    COUNTER=$(expr $COUNTER + 1)
  done
  cat deploy-log.txt
  if test $rc -eq 0; then
    successln "Query successful on peer0.${ORG} on channel '$CHANNEL_NAME'"
  else
    fatalln "After $MAX_RETRY attempts, Query result on peer0.${ORG} is INVALID!"
  fi
}

function deployCC() {
  cd ..
  export FABRIC_CFG_PATH=$PWD/scripts/config/
  export ORDERER_CA=${PWD}/organizations/ordererOrganizations/orderers/orderer/msp/tlscacerts/tlsca-cert.pem

  ## build chaincode to install
  buildSignaturePolicy
  buildCC

  ## package the chaincode
  packageChaincode
  for ORGANIZATION in ${ORGANIZATIONS[*]}; do
    infoln "Instaling $CC_NAME chaincode ($CC_VERSION version) on ${ORGANIZATION} organization - ${CHANNEL_NAME} channel"
    installChaincode ${ORGANIZATION}
  done
  mv *.tar.gz package
  ## query whether the chaincode is installed
  i=0
  for ORGANIZATION in ${ORGANIZATIONS[*]}; do
    queryInstalled ${ORGANIZATION}
    COMMIT[$i]="\"${ORGANIZATION}\": true"
    i=$((i + 1))
  done

  for ORGANIZATION in ${ORGANIZATIONS[*]}; do
    ## approve the definition for org1
    approveForMyOrg ${ORGANIZATION}
    ## check whether the chaincode definition is ready to be committed
    checkCommitReadiness ${ORGANIZATION} ${COMMIT[*]}
  done

  # now that we know for sure both orgs have approved, commit the definition
  commitChaincodeDefinition ${ORGANIZATIONS[*]}

  ## query on both orgs to see that the definition committed successfully
  for ORGANIZATION in ${ORGANIZATIONS[*]}; do
    queryCommitted ${ORGANIZATION}
  done

  ## Invoke the chaincode - this does require that the chaincode have the 'initLedger'
  ## method defined
  if [ "$CC_INIT_FCN" = "NA" ]; then
    infoln "Chaincode initialization is not required"
  else
    chaincodeInvokeInit ${ORGANIZATIONS[*]}
  fi

  exit 0

  if [ $? -ne 0 ]; then
    fatalln "Deploying chaincode failed"
  fi
}

function initInvoke() {

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
    --cc-name)
      CC_NAME="$2"
      shift
      ;;
    --cc-args)
      fcn_call="$2"
      shift
      ;;
    --peer)
      PEER="$2"
      shift
      ;;
    --user-name)
      USER_NAME="$2"
      shift
      ;;
    --channel-name)
      CHANNEL_NAME="$2"
      shift
      ;;
    --org)
      if [ "${ORGANIZATIONS}" = "" ]; then
        ORGANIZATIONS=($2)
      else
        ORGANIZATIONS=(${ORGANIZATIONS[*]} $2)
      fi
      shift
      ;;
    *)
      fatalln "Unknown flag: $key. Use --help for more information"
      ;;
    esac
    shift
  done

  if [ -z "$ORGANIZATIONS" ]; then
    fatalln "--org flag not entered"
  fi

  if [ -z "$CC_NAME" ]; then
    fatalln "--cc-name flag not entered"
  fi

  if [ -z "$fcn_call" ]; then
    fatalln "--cc-args flag not entered"
  fi

  if [ -z "$USER_NAME" ]; then
    fatalln "--user-name flag not entered"
  fi

  if [ -z "$CHANNEL_NAME" ]; then
    fatalln "--channel-name flag not entered"
  fi

  echo
  println "Executing with the following"
  println "- ORGANIZATION/S NAME/S: ${C_GREEN}${ORGANIZATIONS}${C_RESET}"
  println "- USER NAME: ${C_GREEN}${USER_NAME}${C_RESET}"
  println "- CHANNEL NAME: ${C_GREEN}${CHANNEL_NAME}${C_RESET}"
  println "- ARGUMENTS: ${C_GREEN}${fcn_call}${C_RESET}"

  echo
  printf "${C_GREEN} Invoke ${CC_NAME} chaincode ${C_RESET}"
  echo
  chaincodeInvoke $ORGANIZATIONS $USER_NAME $PEER
}

function initChaincodePeer() {
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
    --cc-name)
      CC_NAME="$2"
      shift
      ;;
    --peer)
      PEER="$2"
      shift
      ;;
    --channel-name)
      CHANNEL_NAME="$2"
      shift
      ;;
    --org)
      ORGANIZATION="$2"
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

  if [ -z "$CC_NAME" ]; then
    fatalln "--cc-name flag not entered"
  fi

  if [ -z "$CHANNEL_NAME" ]; then
    fatalln "--channel-name flag not entered"
  fi

  if [ -z "$PEER" ]; then
    fatalln "--peer flag not entered"
  fi

  echo
  println "Executing with the following"
  println "- ORGANIZATION/S NAME/S: ${C_GREEN}${ORGANIZATION}${C_RESET}"
  println "- CHAINCODE NAME: ${C_GREEN}${CC_NAME}${C_RESET}"
  println "- PEER: ${C_GREEN}${PEER}${C_RESET}"

  installPeerChaincode $ORGANIZATION $PEER
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
  --invoke)
    shift
    initInvoke "$@"
    exit
    ;;
  --install-peer)
    shift
    initChaincodePeer "$@"
    exit
    ;;
  --cc-name)
    CC_NAME="$2"
    shift
    ;;
  --cc-path)
    CC_SRC_PATH="$2"
    shift
    ;;
  --cc-version)
    CC_VERSION="$2"
    shift
    ;;
  --cc-sequence)
    CC_SEQUENCE="$2"
    shift
    ;;
  --channel-name)
    CHANNEL_NAME="$2"
    shift
    ;;
  --org)
    if [ "${ORGANIZATIONS}" = "" ]; then
      ORGANIZATIONS=($2)
    else
      ORGANIZATIONS=(${ORGANIZATIONS[*]} $2)
    fi
    shift
    ;;
  --invoke)
    echo
    printf "${C_RED}Delete containers and ${NETWORK_NAME} network folders${C_RESET}"
    echo
    networkDown
    exit 0
    ;;
  *)
    fatalln "Unknown flag: $key. Use --help for more information"
    ;;
  esac
  shift
done

if [ -z "$ORGANIZATIONS" ]; then
  fatalln "--org flag not entered"
fi

if [ -z "$CC_NAME" ]; then
  fatalln "--cc-name flag not entered"
fi

if [ -z "$CC_SRC_PATH" ]; then
  fatalln "--cc-path flag not entered"
fi

if [ -z "$CC_VERSION" ]; then
  fatalln "--cc-version flag not entered"
fi

if [ -z "$CC_SEQUENCE" ]; then
  fatalln "--cc-sequence flag not entered"
fi

deployCC
