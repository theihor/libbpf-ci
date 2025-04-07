#!/bin/bash

set -x -euo pipefail

tag=bpfci-runner
# container=$1

sudo docker run -it --privileged \
           --device=/dev/kvm \
           --cap-add ALL \
           --entrypoint /bin/bash \
           $tag

# docker cp . $container:/opt
# docker exec $container /bin/bash -c "cd /opt && ./bang.sh"

