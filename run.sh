#!/bin/bash
#
# This script is meant to support running the speedtest with docker-compose
#
# You can:
# - call it without any arguments to run the speed test using IRIS. 
# - call it with an argument to run the speed test using another datbase. The available options are: 
#   - mysql
#
# Each option will lead to using a diffent docker-compose.yml file.
#

YELLOW="\033[1;33m"
BLUE="\033[1;34m"
PURPLE="\033[1;35m"
CYAN="\033[1;36m"
WHITE="\033[1;37m"
RESET="\033[0m"

cleanup()
{
    printf "\n\n${PURPLE}CTRL+C detected. Removing containters...${RESET}\n"
    if [ -z "$1" ];
    then
        docker-compose stop
        docker-compose rm -f
    else
        docker-compose -f docker-compose-$1.yml stop
        docker-compose -f docker-compose-$1.yml rm -f
    fi

    printf "\n\n${PURPLE}Cleaning up complete.${RESET}\n"
    trap - INT
}
trap cleanup INT

if [ -z "$1" ];
then
    docker-compose stop
    docker-compose rm -f
    docker-compose up --remove-orphans
else
    if [ "$1" == "hana" ];
    then
        printf "\n\n${PURPLE}SAP HANA requires some kernel parameters to be configured so it can run properly.\n"
        if [ "$OSTYPE" == "linux-gnu" ]; 
        then
            # Following instructions on https://hub.docker.com/_/sap-hana-express-edition/plans/f2dc436a-d851-4c22-a2ba-9de07db7a9ac?tab=instructions
            # But we are setting these kernel parameters to be TEMPORARY. After a reboot, they will be
            # reset to their original values.
            
            printf "\nYou will be asked for your sudo password.\n${RESET}"
            
            sudo sysctl -w fs.file-max=20000000
            sudo sysctl -w fs.aio-max-nr=262144
            sudo sysctl -w vm.memory_failure_early_kill=1
            sudo sysctl -w vm.max_map_count=135217728
            sudo sysctl -w net.ipv4.ip_local_port_range="40000 60999"

            printf "\n${PURPLE}Kernel variables set.\n\n${RESET}"
        else
            printf "\n\n${PURPLE}SAP HANA for Docekrs is only supported in native Linux. It may not work correctly on Docker for Mac or Windows.${RESET}"
        fi
    fi
    docker-compose -f docker-compose-$1.yml stop
    docker-compose -f docker-compose-$1.yml rm -f
    docker-compose -f docker-compose-$1.yml up --remove-orphans
fi