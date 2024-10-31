#!/bin/bash

set -x -euo pipefail

repo_dir=$1

tag=$(echo "$(pwd)" | sed "s:^$HOME/::" | tr '/' '-')

docker build -t $tag                 \
       --build-arg C_GID=$(id -g)    \
       --build-arg C_GROUP=$(id -gn) \
       --build-arg C_UID=$(id -u)    \
       --build-arg C_USER=$(id -un)  \
       --build-arg LLVM_VERSION=18   \
       .

function docker_run {
    docker run -d --privileged \
           --device=/dev/kvm \
           --cap-add ALL \
           --user "$(id -u):$(id -gn)" \
           -v $(pwd):/opt/actions \
           -v $(realpath $repo_dir):/opt/workspace \
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
