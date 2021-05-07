#!/bin/bash
. ../utils/cli-utils.sh

# Print the usage message
function printHelp() {
    println "Usage: "
    println "  install [mode: prereqs/bootstrap]"
    println "    install prereqs - Install prerequisites"
    println "    install bootstrap - Download the docker's images and the hyperledger's bineries"
}

function installPrereqs() {
    echo
    printf "${C_YELLOW}-----------Installing git-----------${C_RESET}"
    choco install git.install --verbose
    printf "${C_GREEN}-----------git installed-----------${C_RESET}"
    printf "${C_YELLOW}-----------Installing cURL-----------${C_RESET}"
    choco install curl --verbose
    printf "${C_GREEN}cURL installed.${C_RESET}"
    printf "${C_YELLOW}-----------Installing Docker-----------${C_RESET}"
    choco install docker-desktop --pre --verbose
    printf "${C_GREEN}Docker installed.${C_RESET}"
    printf "${C_YELLOW}-----------Installing Docker Compose-----------${C_RESET}"
    choco install docker-compose
    printf "${C_GREEN}Docker Compose installed.${C_RESET}"
    echo
}
function bootstrap() {
    echo
    printf "${C_YELLOW}-----------Downloading binaries and images-----------${C_RESET}"
    . ../utils/bootstrap.sh
    printf "${C_GREEN}Binaries and images downloaded.${C_RESET}"
    echo
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
    --prereqs)
        installPrereqs
        exit 0
        ;;
    --bootstrap)
        bootstrap
        exit 0
        ;;
    *)
        fatalln "Unknown flag: $key. Use --help for more information"
        ;;
    esac
    shift
done
