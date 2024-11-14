#!/bin/bash

set -x -euo pipefail

# run inside ./iamci.sh

clean=${1:-}

export GITHUB_REPOSITORY=libbpf/libbpf

export KERNEL=4.19.323

export ACTIONS=/ci/actions
export GITHUB_WORKSPACE=/ci/workspace
export KERNEL_ROOT=$GITHUB_WORKSPACE/.kernel

export ARCH=x86_64
# export TARGET_ARCH=$ARCH

export GITHUB_ENV=$GITHUB_WORKSPACE/.github-env
echo -n > $GITHUB_ENV

# download lts kernel
wget https://cdn.kernel.org/pub/linux/kernel/v4.x/


cat CHECKPOINT-COMMIT
echo "CHECKPOINT=$(cat CHECKPOINT-COMMIT)" >> $GITHUB_ENV


#     - name: Prepare to build BPF selftests
source $GITHUB_WORKSPACE/ci/vmtest/helpers.sh
# cd $GITHUB_WORKSPACE/.kernel
SELFTESTS_BPF=$GITHUB_WORKSPACE/selftests/bpf
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
    $GITHUB_ACTION_PATH/build_selftests.sh $ARCH llvm $(realpath .kernel)
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

