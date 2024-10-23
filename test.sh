#!/bin/bash

set -x -euo pipefail

# sudo apt-get update && 
# sudo apt-get install -y \
#      curl cpu-checker ethtool keyutils iptables gawk \
#      qemu-kvm qemu-utils qemu-system-x86 qemu-guest-agent

export ACTIONS=/opt/actions

export GITHUB_REPOSITORY=/opt/linux

if ! [ -d $GITHUB_REPOSITORY ]; then
  echo "$GITHUB_REPOSITORY must be a directory"
  exit 1
fi

cd $GITHUB_REPOSITORY

if [ ! -d selftests ]; then
  ln -s tools/testing/selftests selftests
fi

export GITHUB_WORKSPACE=$(pwd)
export GITHUB_ACTION_PATH=$(realpath run-vmtest)
export GITHUB_STEP_SUMMARY=.github-step-summary

export KERNEL=LATEST
export KERNEL_ROOT=$GITHUB_WORKSPACE
export KERNEL_TEST="test_progs"

echo "build_id" > $KERNEL_ROOT/selftests/bpf/ALLOWLIST

export KBUILD_OUTPUT=$KERNEL_ROOT/kbuild-output
export VMLINUZ=$KBUILD_OUTPUT/arch/x86/boot/bzImage

export PROJECT_NAME="/opt/linux"

mkdir -p bin
if ! [ -f bin/vmtest ]; then
  curl -L https://github.com/danobi/vmtest/releases/download/v0.12.0/vmtest-$(uname -m) -o bin/vmtest
  chmod 755 bin/vmtest
fi

export PATH=$(pwd)/bin:$PATH

bash $ACTIONS/run-vmtest/run.sh | tee 

