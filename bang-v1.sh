#!/bin/bash

set -x -euo pipefail

# sudo apt-get update &&
# sudo apt-get install -y \
#      curl cpu-checker ethtool keyutils iptables gawk \
#      qemu-kvm qemu-utils qemu-system-x86 qemu-guest-agent

export GITHUB_REPOSITORY="$(realpath $1)"
export ACTIONS="$(realpath $2)"

if ! [ -d $GITHUB_REPOSITORY ]; then
  echo "$GITHUB_REPOSITORY must be a directory"
  exit 1
fi

pushd $GITHUB_REPOSITORY
image_name=$(make -s image_name)
mkdir -p $(dirname kbuild-output/$image_name)
if [ ! -f kbuild-output/$image_name ]; then
  ln -sr $image_name kbuild-output/$image_name
fi
if [ ! -d selftests ]; then
  ln -s tools/testing/selftests selftests
fi
popd

export GITHUB_WORKSPACE=$GITHUB_REPOSITORY
export GITHUB_ACTION_PATH=$(realpath run-vmtest)
export GITHUB_STEP_SUMMARY=.github-step-summary

export KERNEL=LATEST
export KERNEL_ROOT=$GITHUB_REPOSITORY


# echo "build_id" > $KERNEL_ROOT/selftests/bpf/ALLOWLIST

export KBUILD_OUTPUT=$KERNEL_ROOT/kbuild-output
export VMLINUZ=$KBUILD_OUTPUT/arch/x86/boot/bzImage

export PROJECT_NAME="$KERNEL_ROOT"

export VMTEST_SCRIPT="$ACTIONS/ci/vmtest/sched_ext_selftests.sh"
export KERNEL_TEST="" #"-t dsp_local"
# export VMTEST_SCRIPT="$ACTIONS/ci/vmtest/vmtest_selftests.sh"
# export KERNEL_TEST="test_progs"

mkdir -p bin
if ! [ -f bin/vmtest ]; then
  curl -L https://github.com/danobi/vmtest/releases/download/v0.14.0/vmtest-$(uname -m) -o bin/vmtest
  chmod 755 bin/vmtest
fi

export PATH=$(pwd)/bin:$PATH

bash $ACTIONS/run-vmtest/run.sh | tee

