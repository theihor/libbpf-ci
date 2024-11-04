#!/bin/bash

set -x -euo pipefail

# run inside ./iamci.sh

clean=${1:-}

export GITHUB_REPOSITORY=libbpf/libbpf

export ACTIONS=/ci/actions
export GITHUB_WORKSPACE=/ci/workspace
export KERNEL_ROOT=$GITHUB_WORKSPACE/.kernel

export ARCH=x86_64
# export TARGET_ARCH=$ARCH

export GITHUB_ENV=$GITHUB_WORKSPACE/.github-env

export KERNEL=LATEST # 4.9.0 # LATEST


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

cd $GITHUB_WORKSPACE/.kernel
$ACTIONS/patch-kernel/patch_kernel.sh $GITHUB_WORKSPACE/ci/diffs
cd $GITHUB_WORKSPACE

#     - name: Prepare to build BPF selftests
source $GITHUB_WORKSPACE/ci/vmtest/helpers.sh
cd $GITHUB_WORKSPACE/.kernel
cat tools/testing/selftests/bpf/config \
    tools/testing/selftests/bpf/config.$ARCH \
    > .config
cat tools/testing/selftests/bpf/config.vm >> .config || :
make olddefconfig && make prepare
cd -

if [[ "$KERNEL" == "LATEST" ]]; then
    cd $GITHUB_WORKSPACE/.kernel
    make -j $((4*$(nproc))) all # > /dev/null
    cp vmlinux $GITHUB_WORKSPACE
    cd -
fi

if [[ "$KERNEL" != "LATEST" ]]; then
    rm -f $GITHUB_WORKSPACE/vmlinux
    # export GITHUB_ACTION_PATH=$ACTIONS/download-vmlinux
    # $GITHUB_ACTION_PATH/run.sh -k $KERNEL
    cp vmlinux.bak vmlinux
    # vmlinux="${GITHUB_WORKSPACE}/vmlinux"
    # zstd -d -i "${ARCH}/vmlinuz-${KERNEL}" -o "$vmlinux"
fi

# ./.github/actions/build-selftests
source $GITHUB_WORKSPACE/ci/vmtest/helpers.sh
# sudo apt-get install -y qemu-kvm zstd binutils-dev elfutils libcap-dev libelf-dev libdw-dev python3-docutils
# export KERNEL=LATEST
# export REPO_ROOT="${{ github.workspace }}"
export REPO_PATH=.kernel
export VMLINUX_BTF=$GITHUB_WORKSPACE/vmlinux
# export LLVM_VERSION="${{ inputs.llvm-version }}"
if [[ ! -d $GITHUB_WORKSPACE/selftests ]]; then
    $GITHUB_WORKSPACE/.github/actions/build-selftests/build_selftests.sh
fi


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

export GITHUB_ACTION_PATH=$ACTIONS/run-vmtest
export KERNEL_TEST= # "test_progs test_progs-no_alu32 test_verifier"

if [[ "$KERNEL" == "LATEST" ]]; then
    image_name=$(make -C $KERNEL_ROOT -s image_name)
    export VMLINUZ=$(realpath $KERNEL_ROOT/$image_name)
else
    export VMLINUZ=$GITHUB_WORKSPACE/vmlinux
fi

export PROJECT_NAME=/mnt/vmtest

mkdir -p bin
if ! [ -f bin/vmtest ]; then
  curl -L https://github.com/danobi/vmtest/releases/download/v0.15.0/vmtest-$(uname -m) -o bin/vmtest
  chmod 755 bin/vmtest
fi
export PATH=bin:$PATH

$GITHUB_ACTION_PATH/run.sh | tee

