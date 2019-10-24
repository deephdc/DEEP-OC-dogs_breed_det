#!/usr/bin/env bash
# -*- coding: utf-8 -*-
#
# Copyright (c) 2017 - 2019 Karlsruhe Institute of Technology - Steinbuch Centre for Computing
# This code is distributed under the MIT License
# Please, see the LICENSE file
#
# @author: vykozlov

### info
# the bash script starts a DEEP-OC container
# and checks that the default execution is ok 
# (defined in the CMD field of the Dockerfile)
# by requesting get_metadata method
###

DOCKER_IMAGE=deephdc/deep-oc-generic
EXPECT_AUTHOR="\"V.Kozlov (KIT)\""
EXPECT_NAME="\"dogs_breed_det\""
CONTAINER_NAME=$(date +%s)
DEEPaaS_PORT=5000          # DEEPaaS Port inside the container

### Usage message (params can be re-defined) ###
USAGEMESSAGE="Usage: $0 <docker_image>"

#### Parse input ###
arr=("$@")
if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
    # print usagemessage
    shopt -s xpg_echo
    echo $USAGEMESSAGE
    exit 1
elif [ $# -eq 1 ]; then
    DOCKER_IMAGE=$1
else
    # Wrong number of arguments is given (!=1)
    echo "[ERROR] Wrong number of arguments provided!"
    shopt -s xpg_echo    
    echo $USAGEMESSAGE
    exit 2
fi

## try to install jq manually
wget -O jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
chmod +x ./jq

# Start docker, let system to bind the port
echo "[INFO] Starting Docker image ${DOCKER_IMAGE}"
docker run --name ${CONTAINER_NAME} -p ${DEEPaaS_PORT} ${DOCKER_IMAGE} &
sleep 20
# Figure out which host port was binded
HOST_PORT=$(docker inspect -f '{{ (index (index .NetworkSettings.Ports "'"$DEEPaaS_PORT/tcp"'") 0).HostPort }}'  ${CONTAINER_NAME})
echo "[INFO] bind port: ${HOST_PORT}"

# Trying to access the deployment
c_url="http://localhost:${HOST_PORT}/models/"
c_args_h1="Accept: application/json"

max_try=10     # max number of tries to access DEEPaaS API
itry=1         # initial try number
running=false

while [ "$running" == false ] && [ $itry -lt $max_try ];
    do
       curl_call=$(curl -s -X GET $c_url -H "$c_args_h")
       if (echo $curl_call | grep -q 'id\":') then
           echo "[INFO] Service is responding (tries = $itry)"
           running=true
       else
           echo "[INFO] Service is NOT (yet) responding. Try #"$itry
           sleep 10
           let itry=itry+1
       fi
    done

if [[ $itry -ge $max_try ]]; then
    echo "[ERROR] DEEPaaS API does not respond (tries = $itry). Exiting"
    exit 3
fi

# Access the running DEEPaaS API. Get models
META_DATA=$(curl -X GET $c_url -H "$c_arg_h")

# Check if Author and Name correspond to the expected values
# Remove uncertainty on "-" or "_" signs
EXPECT_AUTHOR=${EXPECT_AUTHOR//_/-}
EXPECT_NAME=${EXPECT_NAME//_/-}

TEST_AUTHOR=$(echo ${META_DATA} |./jq '.models[0].Author')
TEST_NAME=$(echo ${META_DATA} |./jq '.models[0].Name')

TEST_AUTHOR=${TEST_AUTHOR//_/-}
TEST_NAME=${TEST_NAME//_/-}

# remove downloaded jq
rm ./jq

if [[ "$TEST_AUTHOR" != "${EXPECT_AUTHOR}" ]]; then
    echo "[ERROR] Author does not match! Expected: ${EXPECT_AUTHOR}. Got: $TEST_AUTHOR"
    exit 4
fi
if [ "$TEST_NAME" != "${EXPECT_NAME}" ]; then
    echo "[ERROR] Name does not match! Expected: ${EXPECT_NAME}. Got: $TEST_NAME"
    exit 5
fi

echo "[SUCCESS]. Author=${TEST_AUTHOR}, Name=${TEST_NAME}. Now removing ${CONTAINER_NAME} container"
docker stop ${CONTAINER_NAME}
docker rm ${CONTAINER_NAME}
echo "[INFO] Finished. Exit with the code 0 (success)"
exit 0

### todo: the following can be removed #vykozlov
# one other method using "docker port" command to identify the host port:
###
#docker_port_info=$(docker port ${CONTAINER_NAME} $DEEPaaS_PORT/tcp)
#HOST_BIND=(${docker_port_info//:/" "})
#HOST_PORT=${HOST_BIND[1]}
####
