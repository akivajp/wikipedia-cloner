#!/bin/bash

CONTAINER_NAME=wikipedia
IMAGE=ubuntu:20.04
EXPORT_HTTP_PORT=8080

./run-docker.sh -p ${EXPORT_HTTP_PORT}:80 ${CONTAINER_NAME} ${IMAGE} --detach

cat build-on-ubuntu.sh | docker exec -i ${CONTAINER_NAME} bash
