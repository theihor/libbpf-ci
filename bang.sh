#!/bin/bash

set -x -euo pipefail

export LD_LIBRARY_PATH=/usr/local/lib:${LD_LIBRARY_PATH:-}

ACTIONS=/opt/actions

bash $ACTIONS/build-linux/build.sh \
     x86_64 gcc $GITHUB_WORKSPACE/kbuild-output

export KBUILD_OUTPUT=$GITHUB_WORKSPACE/kbuild-output
export REPO_ROOT=$GITHUB_WORKSPACE
export REPO_PATH=""

bash $ACTIONS/build-selftests/build_selftests.sh \
     x86_64 LATEST gcc $KBUILD_OUTPUT

exit 0
