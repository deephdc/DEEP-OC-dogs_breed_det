#!/usr/bin/env bash

#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --output=slurm-%j.out
#SBATCH -p fast

### DEFAULT IP:PORT FOR DEEPaaS API
deepaas_host=127.0.0.1
port=5001

### SET OF USER PARAMETERS
DockerImage="deephdc/deep-oc-dogs_breed_det:cpu"
ContainerName="deep-oc-dogs-cpu"

### Matching between Host directories and Container ones
# Comment out if not used
HostData=$HOME/datasets/dogs_breed/data
ContainerData=/srv/dogs_breed_det/data
#HostModels=$HOME/datasets/dogs_breed/models
#ContainerModels=/srv/dogs_breed_det/models
###


### rclone settings
# rclone configuration is specified either in the rclone.conf file
# OR via environment settings
# we skip later environment settings if "HostRclone" is provided
# HostRclone = Host directory where rclone.conf is located at the host
rclone_config="/srv/.rclone/rclone.conf"
HostRclone=$HOME/.config/rclone
rclone_vendor="nextcloud"
rclone_type="webdav"
rclone_url="https://nc.deep-hybrid-datacloud.eu/remote.php/webdav/"
rclone_user="DEEP-XYXYXYXYXXYXY"
rclone_pass="jXYXYXYXYXXYXYXYXY"
### rclone

flaat_disable="yes"

### END OF SET OF USER PARAMETERS


### MAIN SCRIPT:

train_args=""
predict_arg=""
SCRIPT_PID=$$
echo $SCRIPT_PID

function usage()
{
    echo "Usage: $0 [-h|--help] [-t|--training Training arguments] [-d|--predict File name used for prediction]" 1>&2; exit 0; 
}

function check_arguments()
{

    OPTIONS=h,t:,d:
    LONGOPTS=help,training:,predict:
    # https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash
    #set -o errexit -o pipefail -o noclobber -o nounset
    set  +o nounset
    ! getopt --test > /dev/null
    if [[ ${PIPESTATUS[0]} -ne 4 ]]; then
        echo '`getopt --test` failed in this environment.'
        exit 1
    fi

    # -use ! and PIPESTATUS to get exit code with errexit set
    # -temporarily store output to be able to check for errors
    # -activate quoting/enhanced mode (e.g. by writing out “--options”)
    # -pass arguments only via   -- "$@"   to separate them correctly
    ! PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTS --name "$0" -- "$@")
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        # e.g. return value is 1
        #  then getopt has complained about wrong arguments to stdout
        exit 2
    fi
    # read getopt’s output this way to handle the quoting right:
    eval set -- "$PARSED"
    echo "$1"   "$2"

    if [ "$1" == "--" ]; then
        echo "[INFO] No arguments provided. DEEPaaS URL is set to http://${deepaas_host}:${port}/models. Exiting."
        exit 1
    fi
    # now enjoy the options in order and nicely split until we see --
    while true; do
        case "$1" in
            -h|--help)
                usage
                shift
                ;;
            -t|--training)
                train_args="$2"
                shift 2
                ;;
            -d|--predict)
                predict_arg="$2"
                shift 2
                ;;
            --)
                shift
                break
                ;;
            *)
                break
                ;;
        esac
    done

    echo "train_args: '$train_args', predict_arg: '$predict_arg'"
}

function get_node()
{
    if [ -z "${SLURM_JOB_NODELIST}" ]; then
        return
    fi
    IFS="," read -a sjl <<< "${SLURM_JOB_NODELIST}"
    node=${sjl[0]}
    echo $node
}

: << 'COMMENT'
function is_service_running()
{
    running=true
    if [ -z "$1" ] || [ -z "$2" ]; then
        return 1
    fi
    node=$1
    port=$2
    echo "Node: "$node" port: "$port
    while [[ "$running" == true ]]
    do
       command="cat < /dev/null > /dev/tcp/$node/$port"
       srv_check="timeout 1 bash -c '$command'"
       eval $srv_check > /dev/null 2>&1
       if [[ $? == 0 ]]; then
           echo "service is responding"
           #cmd=`timeout ${TIMEOUT} $ssh $node hostname`
           running=false
       else
           echo "service is NOT responding"
           sleep 10
       fi
    done
    return 0
}
COMMENT

function is_deepaas_up()
{   #curl -X GET "http://127.0.0.1:5000/models/" -H  "accept: application/json"

    if [ -z "$1" ]; then
       max_try=11
    else
       max_try=$1
    fi

    running=false

    c_url="http://${deepaas_host}:${port}/models/"
    c_args_h1="Accept: application/json"

    itry=1

    while [ "$running" == false ] && [ $itry -lt $max_try ];
    do
       curl_call=$(curl -s -X GET $c_url -H "$c_args_h1")
       if (echo $curl_call | grep -q 'id\":') then
           echo "[INFO] Service is responding"
           running=true
       else
           echo "[INFO] Service is NOT (yet) responding. Try #"$itry
           sleep 10
           let itry=itry+1
       fi
    done

    return 0
}

function get_model_id()
{
    # curl -X GET "http://127.0.0.1:5000/models/" -H  "accept: application/json"
    #
    # - have to skip jq since it is not everywhere installed
    # - also some deepaas-based apps produce curl response in one string
    #   have to parse this string
    # Old version:
    # model_id=$(curl -s -X GET $c_url -H "$c_args_h1" | grep 'id\":' \
    #                                                  | awk '{print $2}' \
    #                                                  | cut -d'"' -f2)

    c_url="http://${deepaas_host}:${port}/models/"
    c_args_h1="Accept: application/json"

    curl_call=($(curl -s -X GET $c_url -H "$c_args_h1"))

    found=false
    counter=0
    while [ "$found" == false ] && [ $counter -lt ${#curl_call[@]} ];
    do
        if [[ "${curl_call[counter]}" == "\"id\":" ]]; then
           let ielem=counter+1
           model_id=${curl_call[ielem]}
           found=true
        fi
        let counter=counter+1
    done

    model_id=$(echo $model_id | cut -d'"' -f2)

    if [ -z "$model_id" ]; then
        echo "Unknown"
    else
        echo $model_id
    fi
}

function start_service()
{
    #udocker run -p $port:$port  deephdc/deep-oc-generic-container &

    IFExist=$(udocker ps |grep "${ContainerName}")
    if [ ${#IFExist} -le 1 ]; then
        udocker pull ${DockerImage}
        echo Creating container ${ContainerName}
        udocker create --name=${ContainerName} ${DockerImage}
    else
        echo "=== [INFO] ==="
        echo " ${ContainerName} already exists!"
        echo " Trying to re-use it..."
        echo "=== [INFO] ==="
    fi
    ##udocker setup --nvidia ${ContainerName}

    MountOpts=""

    if [ ! -z "$HostData" ] && [ ! -z "$ContainerData" ]; then
        MountOpts+=" -v ${HostData}:${ContainerData}"
    fi
    if [ ! -z "$HostModels" ] && [ ! -z "$ContainerModels" ]; then
        MountOpts+=" -v ${HostModels}:${ContainerModels}"
    fi
    if [ ! -z "$HostRclone" ] && [ ! -z "$rclone_config" ]; then
        rclone_dir=$(dirname "${rclone_config}")
        MountOpts+=" -v ${HostRclone}:${rclone_dir}"
    fi
    echo "MountOpts: "$MountOpts

    RcloneEnvOpts=""

    [[ ! -z "$rclone_config" ]] && RcloneEnvOpts+=" -e RCLONE_CONFIG=${rclone_config}"

    # rclone configuration is specified either in the rclone.conf file
    # OR via environment settings
    # we skip environment settings if $HostRclone is provided
    if [ -z "$HostRclone" ]; then
        [[ ! -z "$rclone_type" ]] && RcloneEnvOpts+=" -e RCLONE_CONFIG_DEEPNC_TYPE='webdav'"
        [[ ! -z "$rclone_vendor" ]] && RcloneEnvOpts+=" -e RCLONE_CONFIG_DEEPNC_VENDOR='nextcloud'"
        [[ ! -z "$rclone_url" ]] && RcloneEnvOpts+="-e RCLONE_CONFIG_DEEPNC_URL=${rclone_url}"
        [[ ! -z "$rclone_user" ]] && RcloneEnvOpts+=" -e RCLONE_CONFIG_DEEPNC_USER=$rclone_user"
        [[ ! -z "$rclone_pass" ]] && RcloneEnvOpts+="-e RCLONE_CONFIG_DEEPNC_PASS=$rclone_pass"
    fi

    echo "RcloneEnvOpts: "$RcloneEnvOpts

    (udocker run -p ${port}:5000 ${MountOpts} ${RcloneEnvOpts} \
                 ${ContainerName} deepaas-run --listen-ip=0.0.0.0) &
}


function train()
{
    # curl -X PUT "http://localhost:5000/models/Dogs_Breed/train?${train_args}"
    if [ -z "$1" ] || [ -z "$2" ]; then
        return 1
    fi
    echo ${deepaas_host}  ${port}
    model_id=$1
    train_args=$2
    echo "Model_id: ${model_id}, train_args: ${train_args}"
    c_url="http://${deepaas_host}:${port}/models/${model_id}/train?${train_args}"
    c_args_h1="accept: application/json"
    curl_call=$(curl -X PUT $c_url -H "$c_args_h1")
    if [ -z "$curl_call" ]; then
        echo ""
    else
        echo "[INFO] TRAINING OUTPUT:"
        echo $curl_call
    fi
}

function predict()
{
    # curl -X POST "http://localhost:5000/models/Dogs_Breed/predict"
    # -H "accept: application/json" -H  "Content-Type: multipart/form-data"
    # -F "data=@St_Bernard_wiki_2.jpg;type=image/jpeg"

    if [ -z "$1" ] || [ -z "$2" ]; then
        return 1
    fi
    model_id=$1
    predict_file_name=$2

    c_url="http://${deepaas_host}:${port}/models/${model_id}/predict"
    c_args_h1="accept: application/json"
    c_args_h2="Content-Type: multipart/form-data"
    c_args_f1="data=@${predict_file_name};type=image/jpeg"

    echo curl -X POST $c_url -H "$c_args_h1" -H "$c_args_h2" -F "$c_args_f1"
    curl_call=$(curl -X POST $c_url -H "$c_args_h1" -H "$c_args_h2" -F "$c_args_f1")
    if [ -z "$curl_call" ]; then
        echo ""
    else
        echo "[INFO] PREDICTION OUTPUT:"
        echo $curl_call
    fi
}

check_arguments "$0" "$@"
node=$(get_node)
if [ -z  "$node" ]; then
  echo "[INFO] Node name unknown"
fi

echo "[INFO] Starting service"
start_service
echo "[INFO] Service started..."

is_deepaas_up

#is_service_running $node $port
#if [ "$?" -ne 0 ]; then
#   echo "Service not running - exiting"
#   exit 1
#fi

echo "[INFO] Let's call the web services here"
# ALL curl operations here...
id=$(get_model_id)
echo "ID="$id

if [ "${id}" != "Unknown" ]; then
    if [ "$train_args" ]; then
        train "$id" "$train_args"
    else
        if [ "$predict_arg" ]; then
            predict "$id" "$predict_arg"
        else
            echo "[INFO] Model loaded: $id. Prediction file name not provided. Exiting."
        fi
    fi

    # Remove all children started by the script
    echo ""
    echo "[INFO] Cleaning processes..."
    echo "[INFO] Killing PID=${SCRIPT_PID} with all its children (PGID=${SCRIPT_PID})"
    pkill -g $SCRIPT_PID
fi

###
# kill -9 $(ps aux |grep deep-oc-dogs-cpu |awk '{print $2}')
#