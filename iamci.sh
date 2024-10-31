#!/bin/bash

set -x -euo pipefail

repo=$1
linux_repo=$2
actions=${3:-"$(pwd)"}

LLVM_VERSION=${LLVM_VERSION:-18}

tag=$(echo "$(pwd)" | sed "s:^$HOME/::" | tr '/' '-')

docker build -t $tag                 \
       --build-arg C_GID=$(id -g)    \
       --build-arg C_GROUP=$(id -gn) \
       --build-arg C_UID=$(id -u)    \
       --build-arg C_USER=$(id -un)  \
       --build-arg LLVM_VERSION=$LLVM_VERSION   \
       .

function docker_run {
    docker run -d --privileged \
           --device=/dev/kvm \
           --cap-add ALL \
           --user "$(id -u):$(id -gn)" \
           -v $(realpath $linux_repo):/ci/workspace \
           -v $(realpath $actions):/ci/actions \
           $tag
}

container_id=$(docker_run)

# docker cp $(realpath $repo)/. $container_id:/ci/workspace/

docker exec -it $container_id /bin/bash

echo "Container $container_id is still running."
read -p "Would you like to stop it? (y/n): " confirm
if [[ $confirm =~ ^[Yy]$ ]]; then
    docker stop $container_id
else
    exit 0
fi
