#!/bin/bash

. ../utils/cli-utils.sh
. ../utils/env.sh
export PATH=${PWD}/bin:$PATH
export FABRIC_CFG_PATH=$PWD/../scripts/config/

# Print the usage message
function printHelp() {
    println "Usage: "
    println "  user [mode: create/list]"
    println "    user create - Create a new user in an organization"
    println "      user create [--user-name <user name>] [--user-pwd <user password>] [--user-role <user role>] [--org <organization name>]"
    println "      user create --help (print this message)"
    println "        --user-name <user name> - Name of the new user"
    println "        --user-pwd <user password> - Password of the new user"
    println "        --user-role <user role> - Role of the new user"
    println "        --org <organization name> - Name of the organization where the user will be created"
    println "        Examples:"
    println "          user create --user-name user --user-pwd pass --user-role role --org org1"
    println "    user list - List all the users that belong to a certain organization"
    println "      user list [--org <organization name>]"
    println "        --org <creator organization name> - Name of the organization from which the users will be listed"
    println "        Examples:"
    println "          user list --org org1"
}

function buildUser() {
    export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/peerOrganizations/${ORGANIZATION}/

    local ORG=${ORGANIZATION}
    local ATTRS="userRole=${USER_ROLE}:ecert"
    setGlobals $ORG
    local CA_PEER_PORT=$((CA_${ORG}_PORT))
    infoln "Creating ${ORG} user..."
    infoln "Registering $USER_NAME user with $USER_ROLE role..."
    set -x
    fabric-ca-client register --caname ca-$ORG --id.name $USER_NAME --id.secret ${USER_PASSWORD} --id.type client --id.attrs $ATTRS --tls.certfiles ${PWD}/organizations/fabric-ca/$ORG/tls-cert.pem &>>log.txt
    { set +x; } 2>/dev/null
    res=$?
    verifyResult $res "Create user $USER_NAME on $ORG failed"
    successln "User $USER_NAME created on $ORG organization"
    infoln "Enrolling $USER_NAME user with $USER_ROLE role..."
    set -x
    fabric-ca-client enroll -u https://${USER_NAME}:${USER_PASSWORD}@localhost:${CA_PEER_PORT} --caname ca-$ORG -M ${PWD}/organizations/peerOrganizations/${ORG}/users/${USER_NAME}@${ORG}/msp --tls.certfiles ${PWD}/organizations/fabric-ca/${ORG}/tls-cert.pem &>>log.txt
    { set +x; } 2>/dev/null
    res=$?
    verifyResult $res "Enroll $USER_NAME failed"
    cp ${PWD}/organizations/peerOrganizations/$ORG/msp/config.yaml ${PWD}/organizations/peerOrganizations/${ORG}/users/${USER_NAME}@${ORG}/msp/config.yaml
    successln "$USER_NAME user enrolled"
}

function userList() {

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
        *)
            fatalln "Unknown flag: $key. Use --help for more information"
            ;;
        esac
        shift
    done

    if [ -z "$ORGANIZATION" ]; then
        fatalln "--org flag not entered"
    fi

    echo
    printf "${C_GREEN}List users in ${ORGANIZATION} organization${C_RESET}"
    echo
    cd ..
    export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/peerOrganizations/${ORGANIZATION}/
    fabric-ca-client identity list --tls.certfiles ${PWD}/organizations/fabric-ca/${ORGANIZATION}/tls-cert.pem
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
    --list)
        shift
        userList "$@"
        exit 0
        ;;
    --org)
        ORGANIZATION="$2"
        shift
        ;;
    --user-name)
        USER_NAME="$2"
        shift
        ;;
    --user-pwd)
        USER_PASSWORD="$2"
        shift
        ;;
    --user-role)
        USER_ROLE="$2"
        shift
        ;;
    *)
        fatalln "Unknown flag: $key. Use --help for more information"
        ;;
    esac
    shift
done

if [ -z "$USER_NAME" ]; then
    fatalln "--user-name flag not entered"
fi

if [ -z "$USER_PASSWORD" ]; then
    fatalln "--user-pwd flag not entered"
fi

if [ -z "$USER_ROLE" ]; then
    fatalln "--user-role flag not entered"
fi

if [ -z "$ORGANIZATION" ]; then
    fatalln "--org flag not entered"
fi

cd ..

echo
println "Executing with the following"
println "- ORGANIZATION NAME: ${C_GREEN}${ORGANIZATION}${C_RESET}"
println "- USER NAME: ${C_GREEN}${USER_NAME}${C_RESET}"
println "- USER PASSWORD: ${C_GREEN}${USER_PASSWORD}${C_RESET}"
println "- USER ROLE: ${C_GREEN}${USER_ROLE}${C_RESET}"

buildUser
