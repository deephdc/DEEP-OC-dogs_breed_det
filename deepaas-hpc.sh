#!/usr/bin/env bash

#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --output=slurm-%j.out
#SBATCH -p fast

# DEFAULT IP:PORT FOR DEEPaaS API
deepaas_host=127.0.0.1
port=5001

# SET OF PARAMETERS, e.g.
DockerImage="deephdc/deep-oc-dogs_breed_det:cpu"
ContainerName="deep-oc-dogs-cpu"
rclone_config="/srv/.rclone/rclone.conf"
rclone_url="https://nc.deep-hybrid-datacloud.eu/remote.php/webdav/"
rclone_user="DEEP-XYXYXYXYXXYXY"
rclone_pass="jXYXYXYXYXXYXYXYXY"
flaat_disable="yes"
# HostData=...
# ContainerData=/srv/xxx/data
# HostModels=...
# ContainerModels=/srv/xxx/models

#run_info=- network=- num_epochs=-
train_args=""


function usage()
{
    echo "Usage: $0 [-h|--help] [-t|train_args Training arguments]" 1>&2; exit 0;
}

function check_arguments()
{

    OPTIONS=h,t:
    LONGOPTS=help,train_args:
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
    #echo "$PARSED"

    # now enjoy the options in order and nicely split until we see --
    while true; do
        case "$1" in
            -h|--help)
                usage
                shift
                ;;
            -t|--train_args)
                train_args="$2"
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


    echo "train_args: $train_args"
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

function is_deepaas_up()
{   #curl -X GET "http://127.0.0.1:5000/models/" -H  "accept: application/json"

    running=false

    c_url="http://${deepaas_host}:${port}/models/"
    c_args_h1="Accept: application/json"

    n_try=1

    while [ "$running" == false ] && [ $n_try -lt 21 ];
    do
       curl_call=$(curl -s -X GET $c_url -H "$c_args_h1")
       if (echo $curl_call | grep 'id\":') then
           echo "[INFO] Service is responding"
           running=true
       else
           echo "[INFO] Service is NOT (yet) responding. Try #"$n_try
           sleep 10
           let n_try=n_try+1
       fi
    done

    return 0
}

function get_model_id()
{
    #curl -X GET "http://127.0.0.1:5000/models/" -H  "accept: application/json"

    c_url="http://${deepaas_host}:${port}/models/"
    c_args_h1="Accept: application/json"
    model_id=$(curl -s -X GET $c_url -H "$c_args_h1" | jq '.models' \
                                                     | grep 'id\":' \
                                                     | awk '{print $2}' \
                                                     | cut -d'"' -f2)

    if [ -z "$model_id" ]; then
        echo "Unknown"
    else
        echo $model_id
    fi
}

function start_service()
{
    #udocker run -p $port:$port  deephdc/deep-oc-generic-container &

    echo "[INFO] Starting service"

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

    #udocker run -p 5000:5000 \
    #         -v ${HostData}:${ContainerData} \
    #         -v ${HostModels}:${ConatinerModels} \
    (udocker run -p ${port}:5000 \
             -e RCLONE_CONFIG=$rclone_config \
             -e RCLONE_CONFIG_DEEPNC_TYPE="webdav" \
             -e RCLONE_CONFIG_DEEPNC_VENDOR="nextcloud" \
             -e RCLONE_CONFIG_DEEPNC_URL=$rclone_url \
             -e RCLONE_CONFIG_DEEPNC_USER=$rclone_user \
             -e RCLONE_CONFIG_DEEPNC_PASS=$rclone_pass \
             ${ContainerName} deepaas-run --listen-ip=0.0.0.0) &
    echo "[INFO] Service started..."
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
        echo $curl_call
    fi
}

function predict()
{
    # curl -X POST "http://localhost:5000/models/Dogs_Breed/predict"
    # -H "accept: application/json" -H  "Content-Type: multipart/form-data"
    # -F "data=@St_Bernard_wiki_2.jpg;type=image/jpeg"
    model_id=$1
    c_url="http://${deepaas_host}:${port}/models/${model_id}/predict"
    c_args_h1="accept: application/json"
    c_args_h2="Content-Type: multipart/form-data"
    c_args_f1="data=@St_Bernard_wiki_2.jpg;type=image/jpeg"

    echo curl -X POST $c_url -H "$c_args_h1" -H "$c_args_h2" -F "$c_args_f1"
    curl_call=$(curl -X POST $c_url -H "$c_args_h1" -H "$c_args_h2" -F "$c_args_f1")
    if [ -z "$curl_call" ]; then
        echo ""
    else
        echo "[INFO] OUTPUT:"
        echo $curl_call
    fi
}

check_arguments "$0" "$@"
node=$(get_node)
if [ -z  "$node" ]; then
  echo "[INFO] Node name unknown"
fi
start_service
is_deepaas_up
sleep 10
echo "slept 10..."

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
       predict "$id"
    fi
fi
