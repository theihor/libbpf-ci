#!/bin/bash

set -x -euo pipefail

# run inside ./iamci.sh

clean=${1:-}

export ACTIONS=/ci/actions
export GITHUB_REPOSITORY=libbpf/ci
export GITHUB_WORKSPACE=/ci/workspace

export GITHUB_ENV=$GITHUB_WORKSPACE/.github-env
echo -n > $GITHUB_ENV

export ARCH=x86_64
export TOOLCHAIN=gcc
export TOOLCHAIN_FULL=gcc

export ARTIFACTS_ARCHIVE="vmlinux-${ARCH}-${TOOLCHAIN_FULL}.tar.zst"
export BUILD_SCHED_EXT_SELFTESTS=true
export CACHED_KERNEL_BUILD=true
export KBUILD_OUTPUT=$GITHUB_WORKSPACE/kbuild-output
export KERNEL=LATEST
export REPO_PATH=""
export REPO_ROOT=$GITHUB_WORKSPACE
export KERNEL_ROOT=$GITHUB_WORKSPACE

# actions/checkout@v4

# Download bpf-next tree

# Prepare incremental build
if [[ -n "${CACHED_KERNEL_BUILD}" ]]; then
    export GITHUB_ACTION_PATH=$ACTIONS/prepare-incremental-build
    export GITHUB_OUTPUT=$GITHUB_WORKSPACE/.github-output
    echo -n > $GITHUB_OUTPUT
    ${GITHUB_ACTION_PATH}/get-commit-metadata.sh master
    COMMIT=$(cat $GITHUB_OUTPUT | grep 'commit=' | cut -d= -f2)
    $GITHUB_ACTION_PATH/prepare-incremental-builds.sh $COMMIT
fi

# Move linux source in place

# ./patch-kernel
export GITHUB_ACTION_PATH=$ACTIONS/patch-kernel
$GITHUB_ACTION_PATH/patch_kernel.sh $GITHUB_WORKSPACE/ci/diffs


#  - name: Build kernel image
export KBUILD_OUTPUT=$(realpath $GITHUB_WORKSPACE/kbuild-output)
# export LLVM_VERSION=${{ inputs.llvm-version }}
export GITHUB_ACTION_PATH=$ACTIONS/build-linux
$GITHUB_ACTION_PATH/build.sh $ARCH $TOOLCHAIN $KBUILD_OUTPUT



# export KBUILD_OUTPUT=$(realpath kbuild-output); GITHUB_ACTION_PATH=/ci/actions/build-selftests /ci/actions/build-selftests/build_selftests.sh x86_64 gcc $(pwd)

# - name: Build selftests/bpf
export GITHUB_ACTION_PATH=$ACTIONS/build-selftests
$GITHUB_ACTION_PATH/build_selftests.sh $ARCH $TOOLCHAIN $KERNEL_ROOT

# - name: Build selftests/sched_ext
# export MAX_MAKE_JOBS=32
# export REPO_ROOT=$GITHUB_WORKSPACE
# export GITHUB_ACTION_PATH=$ACTIONS/build-scx-selftests
# $GITHUB_ACTION_PATH/build.sh $ARCH $TOOLCHAIN $LLVM_VERSION

export GITHUB_ACTION_PATH=$ACTIONS/tar-artifacts
$GITHUB_ACTION_PATH/tar-artifacts.sh $ARTIFACTS_ARCHIVE


################ kernel-test.yml #################

zstd -d -T0 $ARTIFACTS_ARCHIVE --stdout | tar -xf -


export ALLOWLIST_FILE=/tmp/allowlist
export DENYLIST_FILE=/tmp/denylist

SELFTESTS_BPF=$GITHUB_WORKSPACE/selftests/bpf
VMTEST_CONFIGS=$GITHUB_WORKSPACE/ci/vmtest/configs
cat "${SELFTESTS_BPF}/ALLOWLIST"          \
        "${SELFTESTS_BPF}/ALLOWLIST.${ARCH}"  \
        "${VMTEST_CONFIGS}/ALLOWLIST"         \
        "${VMTEST_CONFIGS}/ALLOWLIST.${ARCH}" \
      2> /dev/null > "${ALLOWLIST_FILE}" || true
cat "${SELFTESTS_BPF}/DENYLIST" \
        "${SELFTESTS_BPF}/DENYLIST.${ARCH}" \
        "${VMTEST_CONFIGS}/DENYLIST" \
        "${VMTEST_CONFIGS}/DENYLIST.${ARCH}" \
        "${VMTEST_CONFIGS}/DENYLIST.${DEPLOYMENT}" \
      2> /dev/null > "${DENYLIST_FILE}" || true


mkdir -p bin
if ! [ -f bin/vmtest ]; then
  curl -L https://github.com/danobi/vmtest/releases/download/v0.15.0/vmtest-$(uname -m) -o bin/vmtest
  chmod 755 bin/vmtest
fi
export PATH=$GITHUB_WORKSPACE/bin:$PATH

export GITHUB_ACTION_PATH=$ACTIONS/run-vmtest
export GITHUB_STEP_SUMMARY=$(mktemp /tmp/.gh-step-summary.XXXX)
export KBUILD_OUTPUT=$GITHUB_WORKSPACE/.kernel
export VMLINUZ=$ARCH/vmlinuz-$KERNEL

export KERNEL_TEST=${KERNEL_TEST:-}

$GITHUB_ACTION_PATH/run.sh | cat

