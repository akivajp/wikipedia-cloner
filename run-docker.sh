#!/bin/bash

set -eu

args=()
volumes=()
ports=()
#interactive=false
background=false
gpus=""
while (( $# > 0 ))
do
    case $1 in
        --gpus)
            gpus="--gpus all"
            ;;
        #-it)
        #    interactive=true
        #    ;;
        -d)
            background=true
            ;;
        --detach)
            background=true
            ;;
        -v)
            if [[ -z "$2" ]]; then
                echo "-v requires an argument" > /dev/stderr
                exit 1
            fi
            volumes+=(-v $2)
            shift
            ;;
        -p)
            if [[ -z "$2" ]]; then
                echo "-p requires an argument" > /dev/stderr
                exit 1
            fi
            ports+=(-p $2)
            shift
            ;;
        *)
            args+=($1)
            ;;
    esac
    shift
done

if [ ${#args[@]} -lt 1 ]; then
    echo "usage: [--gpus] [-v host_dir:container_dir [-v ...] ...] [-p host_port:container_port [-p ...]] container_name [docker_image]" > /dev/stderr
    exit 1
fi

container_name=${args[0]}
echo "container: ${container_name}"

if [ ${#args[@]} -ge 2 ]; then
    docker_image=${args[1]}
    echo "image: ${docker_image}"
fi

if [ "$(docker ps -q -a -f name=/${container_name}$)" ]; then
    # 既にコンテナが存在
    echo "[exec] docker ps -a -f name=/${container_name}$"
    docker ps -a -f name=/${container_name}$
    #docker ps -a -f name=/${container_name}$ -f status=running
    #docker ps -a -f name=/${container_name}$ -f status=exited
    if [ "$(docker ps -q -a -f name=/${container_name}$ -f status=running)" ]; then
        # コンテナは稼働中
        if "${background}"; then
            :
        else
            echo "[exec] docker attach ${container_name}"
            docker attach ${container_name}
        fi
    elif [ "$(docker ps -q -a -f name=/${container_name}$ -f status=exited)" ]; then
        # コンテナは停止中
        echo "[exec] docker start ${container_name}"
        docker start ${container_name}
        if "${background}"; then
            :
        else
            echo "[exec] docker attach ${container_name}"
            docker attach ${container_name}
        fi
    #else
    #    # コンテナは何らかの理由で非稼働中
    #    echo "[exec] docker restart ${container_name}"
    #    docker restart ${container_name}
    #    echo "[exec] docker attach ${container_name}"
    #    docker attach ${container_name}
    fi
else
    # コンテナの作成と起動
    if [ ${#args[@]} -lt 2 ]; then
        echo "usage: [--gpus] [-v host_dir:container_dir [-v ...] ...] [-p host_port:container_port [-p ...]] container_name docker_image" > /dev/stderr
        exit 1
    fi
    detach=""
    if "${background}"; then
        detach="--detach"
    fi
    echo "[exec] docker run ${gpus} ${detach} --name ${container_name} --hostname ${container_name} ${volumes[@]} ${ports[@]} -it ${docker_image}"
    docker run ${gpus} ${detach} --name ${container_name} --hostname ${container_name} ${volumes[@]} ${ports[@]} -it ${docker_image}
fi
