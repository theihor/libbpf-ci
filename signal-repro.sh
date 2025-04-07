#!/bin/bash

set -x -euo pipefail

# run inside ./iamci.sh

clean=${1:-}

export GITHUB_REPOSITORY=libbpf/libbpf

export KERNEL=LATEST # 5.5.0

export ACTIONS=/ci/actions
export GITHUB_WORKSPACE=/ci/workspace
export KERNEL_ROOT=$GITHUB_WORKSPACE/.kernel

export ARCH=x86_64
# export TARGET_ARCH=$ARCH

export GITHUB_ENV=$GITHUB_WORKSPACE/.github-env
echo -n > $GITHUB_ENV


if [[ -n "$clean" ]]; then
    rm -f $GITHUB_WORKSPACE/vmlinux
    rm -rf $GITHUB_WORKSPACE/selftests
fi

###################################
#### libbpf/.github/actions/setup
export REPO_ROOT=$GITHUB_WORKSPACE
export CI_ROOT=$REPO_ROOT/ci
# this is somewhat ugly, but that is the easiest way to share this code with
# arch specific docker
echo 'echo ::group::Env setup' > /tmp/ci_setup
echo export DEBIAN_FRONTEND=noninteractive >> /tmp/ci_setup
echo sudo apt-get update >> /tmp/ci_setup
echo sudo apt-get install -y aptitude qemu-kvm zstd binutils-dev elfutils libcap-dev libelf-dev libdw-dev libguestfs-tools >> /tmp/ci_setup
echo export PROJECT_NAME='libbpf' >> /tmp/ci_setup
echo export AUTHOR_EMAIL="$(git log -1 --pretty=\"%aE\")" >> /tmp/ci_setup
echo export REPO_ROOT=$GITHUB_WORKSPACE >> /tmp/ci_setup
echo export CI_ROOT=$REPO_ROOT/ci >> /tmp/ci_setup
echo export VMTEST_ROOT=$CI_ROOT/vmtest >> /tmp/ci_setup
echo 'echo ::endgroup::' >> /tmp/ci_setup

###################################
#### libbpf/ci/setup-build-env

# sudo apt-get update
# sudo apt-get install -y cmake flex bison build-essential libssl-dev ncurses-dev xz-utils bc rsync libguestfs-tools qemu-kvm qemu-utils linux-image-generic zstd binutils-dev elfutils libcap-dev libelf-dev libdw-dev python3-docutils

# this one set in Dockerfile
# export LLVM_VERSION=
# $ACTIONS/setup-build-env/install_clang.sh

# done in Dockerfile
# $ACTIONS/setup-build-env/build_pahole.sh

# skipped because x86_64
# $ACTIONS/setup-build-env/install_cross_compilation_toolchain.sh $ARCH
###################################

cat CHECKPOINT-COMMIT
echo "CHECKPOINT=$(cat CHECKPOINT-COMMIT)" >> $GITHUB_ENV

###  skip libbpf/ci/get-linux-source@main

# cd $GITHUB_WORKSPACE/.kernel
# $ACTIONS/patch-kernel/patch_kernel.sh $GITHUB_WORKSPACE/ci/diffs
# cd $GITHUB_WORKSPACE

#     - name: Prepare to build BPF selftests
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

# libbpf/libbpf build selftests
export REPO_PATH=.kernel
if [[ ! -d $GITHUB_WORKSPACE/selftests ]]; then
    export VMLINUX_BTF="${GITHUB_WORKSPACE}/vmlinux"
    export GITHUB_ACTION_PATH=$GITHUB_WORKSPACE/.github/actions/build-selftests
    source $GITHUB_ACTION_PATH/../../../ci/vmtest/helpers.sh
    cd $GITHUB_ACTION_PATH
    alias git=echo # the script does unnecessary git commands...
    ./build_selftests.sh
    unalias git
    cd -
fi

# Prepare to run selftests
export ALLOWLIST_FILE=/tmp/allowlist
export DENYLIST_FILE=/tmp/denylist
export SELFTESTS_BPF=$GITHUB_WORKSPACE/.kernel/tools/testing/selftests/bpf
export VMTEST_CONFIGS=$GITHUB_WORKSPACE/ci/vmtest/configs

echo 'send_signal' > $SELFTESTS_BPF/ALLOWLIST

KERNEL_TEST='test_progs'

mkdir -p "${GITHUB_WORKSPACE}/selftests"
cp -R "${SELFTESTS_BPF}" "${GITHUB_WORKSPACE}/selftests"

# # libbpf/ci/prepare-rootfs@main
export PROJECT_NAME=libbpf
export KBUILD_OUTPUT=$(realpath .kernel)
export KERNEL_ROOT=$(realpath .kernel)
export IMG=/tmp/root.img
export GITHUB_ACTION_PATH=$ACTIONS/prepare-rootfs
export TARGET_ARCH=$ARCH
$GITHUB_ACTION_PATH/run_vmtest.sh $KBUILD_OUTPUT $IMG

# # libbpf/ci/run-qemu@main
# KERNEL: ${{ inputs.kernel }}
# REPO_ROOT: ${{ github.workspace }}
export VMLINUZ=vmlinuz
export MAX_CPU=32
export KERNEL_TEST=test_progs
export OUTPUT_DIR=
export GITHUB_ACTION_PATH=$ACTIONS/run-qemu
$GITHUB_ACTION_PATH/run.sh




# mkdir -p bin
# if ! [ -f bin/vmtest ]; then
#   curl -L https://github.com/danobi/vmtest/releases/download/v0.15.0/vmtest-$(uname -m) -o bin/vmtest
#   chmod 755 bin/vmtest
# fi
# export PATH=$GITHUB_WORKSPACE/bin:$PATH


# # export ALLOWLIST_FILE=/tmp/allowlist
# # export DENYLIST_FILE=/tmp/denylist
# # export KERNEL=$KERNEL
# export VMLINUX=$GITHUB_WORKSPACE/vmlinux

# export GITHUB_ACTION_PATH=$ACTIONS/run-vmtest
# export GITHUB_STEP_SUMMARY=$(mktemp /tmp/.gh-step-summary.XXXX)

# export KBUILD_OUTPUT=$GITHUB_WORKSPACE/.kernel
# export VMLINUZ=$ARCH/vmlinuz-$KERNEL

# export KERNEL_TEST=${KERNEL_TEST:-}

# $GITHUB_ACTION_PATH/run.sh | cat

