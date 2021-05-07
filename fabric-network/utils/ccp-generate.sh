#!/bin/bash

function one_line_pem {
    echo "`awk 'NF {sub(/\\n/, ""); printf "%s\\\\\\\n",$0;}' ${1}`"
}

function json_ccp {
    local PP=$(one_line_pem $4)
    local CP=$(one_line_pem $5)
    sed -e "s/\${ORG}/$1/" \
    -e "s/\${P0PORT}/$2/" \
    -e "s/\${CAPORT}/$3/" \
    -e "s/\${NETWORK_NAME}/$NETWORK_NAME/" \
    -e "s#\${PEERPEM}#$PP#" \
    -e "s#\${CAPEM}#$CP#" \
    organizations/ccp-template.json
}

function yaml_ccp {
    local PP=$(one_line_pem $4)
    local CP=$(one_line_pem $5)
    sed -e "s/\${ORG}/$1/" \
    -e "s/\${P0PORT}/$2/" \
    -e "s/\${CAPORT}/$3/" \
    -e "s/\${NETWORK_NAME}/$NETWORK_NAME/" \
    -e "s#\${PEERPEM}#$PP#" \
    -e "s#\${CAPEM}#$CP#" \
    organizations/ccp-template.yaml | sed -e $'s/\\\\n/\\\n          /g'
}

ORG=$1
P0PORT=$3
CAPORT=$2
NETWORK_NAME=$4
PEERPEM=organizations/peerOrganizations/${1}/tlsca/tlsca.${1}-cert.pem
CAPEM=organizations/peerOrganizations/${1}/ca/ca.${1}-cert.pem

echo "$(json_ccp $ORG $P0PORT $CAPORT $PEERPEM $CAPEM)" >organizations/peerOrganizations/${1}/connection-${1}.json
echo "$(yaml_ccp $ORG $P0PORT $CAPORT $PEERPEM $CAPEM)" >organizations/peerOrganizations/${1}/connection-${1}.yaml
