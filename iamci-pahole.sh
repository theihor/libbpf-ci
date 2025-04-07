#!/bin/bash

set -x -euo pipefail

libbpf_repo=$1
linux_repo=$2
actions=${3:-"$(pwd)"}

LLVM_VERSION=${LLVM_VERSION:-17}

tag="$(echo "$(pwd)" | sed "s:^$HOME/::" | tr '/' '-')-pahole"

docker build -t $tag \
       -f pahole.Dockerfile                 \
       --build-arg=LLVM_VERSION=${LLVM_VERSION} \
       .

function docker_run {
    docker run -d --privileged \
           --device=/dev/kvm \
           --cap-add ALL \
           -v $(realpath $libbpf_repo):/ci/workspace \
           -v $(realpath $actions):/ci/actions \
           -v $(realpath $linux_repo):/ci/workspace/.kernel \
           $tag
}

container_id=$(docker_run)

docker exec -it $container_id /bin/bash

echo "Container $container_id is still running."
read -p "Would you like to stop it? (y/n): " confirm
if [[ $confirm =~ ^[Yy]$ ]]; then
    docker stop $container_id
else
    exit 0
fi
