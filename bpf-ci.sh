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


# - name: Build selftests/bpf
export GITHUB_ACTION_PATH=$ACTIONS/build-selftests
$GITHUB_ACTION_PATH/build_selftests.sh $ARCH $TOOLCHAIN $KERNEL_ROOT

# - name: Build selftests/sched_ext
export MAX_MAKE_JOBS=32
export REPO_ROOT=$GITHUB_WORKSPACE
export GITHUB_ACTION_PATH=$ACTIONS/build-scx-selftests
$GITHUB_ACTION_PATH/build.sh $ARCH $TOOLCHAIN $LLVM_VERSION

exit 0



# - name: Prepare to build BPF selftests
source $GITHUB_WORKSPACE/ci/vmtest/helpers.sh
# cd $GITHUB_WORKSPACE/.kernel
SELFTESTS_BPF=$GITHUB_WORKSPACE/.kernel/tools/testing/selftests/bpf
configs=(
    "${SELFTESTS_BPF}/config"
    "${SELFTESTS_BPF}/config.$ARCH"
    "${SELFTESTS_BPF}/config.vm"
)
kbuild_config="${KERNEL_ROOT}/.config"

echo -n > $kbuild_config
for config in "${configs[@]}"; do
    cat "$config" >> $kbuild_config || true
done

cd $GITHUB_WORKSPACE/.kernel
make olddefconfig && make prepare
cd -

if [[ "$KERNEL" == "LATEST" ]]; then
    cd $GITHUB_WORKSPACE/.kernel
    make -j $((4*$(nproc))) all # > /dev/null
    cp vmlinux $GITHUB_WORKSPACE
    cd -
fi

if [[ "$KERNEL" != "LATEST" && ! -f "${GITHUB_WORKSPACE}/vmlinux" ]]; then
    # cp vmlinux.bak vmlinux
    rm -f $GITHUB_WORKSPACE/vmlinux
    export GITHUB_ACTION_PATH=$ACTIONS/download-vmlinux
    $GITHUB_ACTION_PATH/run.sh -k $KERNEL
    # vmlinux="${GITHUB_WORKSPACE}/vmlinux"
    # zstd -d -i "${ARCH}/vmlinuz-${KERNEL}" -o "$vmlinux"
fi

# libbpf/libbpf build selftests
# export REPO_PATH=.kernel
# if [[ ! -d $GITHUB_WORKSPACE/selftests ]]; then
#         # export KERNEL=${{ inputs.kernel }}
#         # export REPO_ROOT="${{ github.workspace }}"
#         # export REPO_PATH="${{ inputs.repo-path }}"
#         # export VMLINUX_BTF="${{ inputs.vmlinux }}"
#         # export LLVM_VERSION="${{ inputs.llvm-version }}"
#     export GITHUB_ACTION_PATH=$GITHUB_WORKSPACE/.github/actions/build-selftests
#     source $GITHUB_ACTION_PATH/../../../ci/vmtest/helpers.sh
#     cd $GITHUB_ACTION_PATH
#     ./build_selftests.sh 
#     cd -
# fi


# Prepare to build selftests
export PREPARE_SCRIPT=$GITHUB_WORKSPACE/ci/vmtest/prepare-selftests-build-${KERNEL}.sh
export SELFTESTS_BPF=$GITHUB_WORKSPACE/.kernel/tools/testing/selftests/bpf

if [ -f "${PREPARE_SCRIPT}" ]; then
    bash "${PREPARE_SCRIPT}"
fi

# libbpf/ci build selftests

export MAX_MAKE_JOBS=32
export VMLINUX_BTF=$GITHUB_WORKSPACE/vmlinux
if [[ "$KERNEL" != "LATEST" ]]; then
    export VMLINUX_H=$GITHUB_WORKSPACE/.github/actions/build-selftests/vmlinux.h
fi

if [[ ! -f $GITHUB_WORKSPACE/.kernel/tools/testing/selftests/bpf/test_progs ]]; then
    export GITHUB_ACTION_PATH=$ACTIONS/build-selftests
    export LLVM_VERSION=${LLVM_VERSION}
    $GITHUB_ACTION_PATH/build_selftests.sh $ARCH gcc $(realpath .kernel)
fi

# Prepare to run selftests
export ALLOWLIST_FILE=/tmp/allowlist
export DENYLIST_FILE=/tmp/denylist
# export ARCH=$ARCH
# export KERNEL=$KERNEL
export SELFTESTS_BPF=$GITHUB_WORKSPACE/.kernel/tools/testing/selftests/bpf
export VMTEST_CONFIGS=$GITHUB_WORKSPACE/ci/vmtest/configs

$GITHUB_WORKSPACE/ci/vmtest/prepare-selftests-run.sh


# # libbpf/ci/prepare-rootfs@main
# export PROJECT_NAME=libbpf
# export KBUILD_OUTPUT=$(realpath .kernel)
# export KERNEL_ROOT=$(realpath .kernel)
# export IMG=/tmp/root.img
# export GITHUB_ACTION_PATH=$ACTIONS/prepare-rootfs
# $GITHUB_ACTION_PATH/run_vmtest.sh $KBUILD_OUTPUT $IMG

# # libbpf/ci/run-qemu@main
# # KERNEL: ${{ inputs.kernel }}
# # REPO_ROOT: ${{ github.workspace }}
# export VMLINUZ=vmlinuz
# export MAX_CPU=32
# export KERNEL_TEST=
# export OUTPUT_DIR=
# export GITHUB_ACTION_PATH=$ACTIONS/run-qemu
# $GITHUB_ACTION_PATH/run.sh


mkdir -p bin
if ! [ -f bin/vmtest ]; then
  curl -L https://github.com/danobi/vmtest/releases/download/v0.15.0/vmtest-$(uname -m) -o bin/vmtest
  chmod 755 bin/vmtest
fi
export PATH=$GITHUB_WORKSPACE/bin:$PATH


# export ALLOWLIST_FILE=/tmp/allowlist
# export DENYLIST_FILE=/tmp/denylist
# export KERNEL=$KERNEL
export VMLINUX=$GITHUB_WORKSPACE/vmlinux

export GITHUB_ACTION_PATH=$ACTIONS/run-vmtest
export GITHUB_STEP_SUMMARY=$(mktemp /tmp/.gh-step-summary.XXXX)

export KBUILD_OUTPUT=$GITHUB_WORKSPACE/.kernel
export VMLINUZ=$ARCH/vmlinuz-$KERNEL

export KERNEL_TEST=${KERNEL_TEST:-}

$GITHUB_ACTION_PATH/run.sh | cat

