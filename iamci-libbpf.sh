#!/bin/bash

set -x -euo pipefail

libbpf_repo=$1
linux_repo=$2
actions=${3:-"$(pwd)"}

LLVM_VERSION=${LLVM_VERSION:-18}

# tag=$(echo "$(pwd)" | sed "s:^$HOME/::" | tr '/' '-')

tag=gha-runner

docker build -t $tag \
       -f gha-runner.Dockerfile                 \
       --build-arg=RUNNER_VERSION=2.320.0 \
       .


       # --build-arg C_GID=$(id -g)    \
       # --build-arg C_GROUP=$(id -gn) \
       # --build-arg C_UID=$(id -u)    \
       # --build-arg C_USER=$(id -un)  \
       # --build-arg LLVM_VERSION=$LLVM_VERSION   \


#            --user "$(id -u):$(id -gn)" 
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

# docker cp $(realpath $repo)/. $container_id:/ci/workspace/

docker exec -it $container_id /bin/bash

echo "Container $container_id is still running."
read -p "Would you like to stop it? (y/n): " confirm
if [[ $confirm =~ ^[Yy]$ ]]; then
    docker stop $container_id
else
    exit 0
fi
