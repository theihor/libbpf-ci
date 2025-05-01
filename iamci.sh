#!/bin/bash

set -x -euo pipefail

linux_repo=$1
actions=${2:-"$(pwd)"}

LLVM_VERSION=${LLVM_VERSION:-18}

tag=$(echo "$(pwd)" | sed "s:^$HOME/::" | tr '/' '-')

podman build -t $tag --network=host .

function podman_run {
    podman run -d --privileged \
           --network=host \
           --device=/dev/kvm \
           --cap-add ALL \
           --user root \
           -v $(realpath $actions):/ci/actions \
           -v $(realpath $linux_repo):/ci/workspace \
           $tag sleep infinity
}

container_id=$(podman_run)

podman exec -it $container_id /bin/bash

echo "Container $container_id is still running."
read -p "Would you like to stop it? (y/n): " confirm
if [[ $confirm =~ ^[Yy]$ ]]; then
    podman stop $container_id
else
    exit 0
fi
