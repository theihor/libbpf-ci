#!/bin/bash

set -x -euo pipefail

# run inside ./iamci.sh

clean=${1:-}

export GITHUB_REPOSITORY=libbpf/libbpf

export KERNEL=LATEST # 4.9.0

export ACTIONS=/ci/actions
export GITHUB_WORKSPACE=/ci/workspace
export KERNEL_ROOT=$GITHUB_WORKSPACE/.kernel

export ARCH=x86_64
# export TARGET_ARCH=$ARCH

export GITHUB_ENV=$GITHUB_WORKSPACE/.github-env


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
export TOOLCHAIN=llvm
if [[ "${KERNEL}" = 'LATEST' ]]; then
	export VMLINUX_H=
else
	export VMLINUX_H=$GITHUB_WORKSPACE/.github/actions/build-selftests/vmlinux.h
fi

# export LLVM_VERSION="${{ inputs.llvm-version }}"
if [[ ! -d $GITHUB_WORKSPACE/selftests ]]; then
    PREPARE_SELFTESTS_SCRIPT=${GITHUB_WORKSPACE}/.github/build-selftests/prepare_selftests-${KERNEL}.sh
    if [ -f "${PREPARE_SELFTESTS_SCRIPT}" ]; then
	(cd "${GITHUB_WORKSPACE}/.kernel/tools/testing/selftests/bpf" && ${PREPARE_SELFTESTS_SCRIPT})
    fi
    $ACTIONS/build-selftests/build_selftests.sh $ARCH $KERNEL $TOOLCHAIN $(realpath .kernel)
    cp -R $GITHUB_WORKSPACE/.kernel/tools/testing/selftests $GITHUB_WORKSPACE/selftests
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
export KERNEL_TEST="test_progs_no_alu32" # "test_progs test_progs-no_alu32 test_verifier"

if [[ "$KERNEL" == "LATEST" ]]; then
    image_name=$(make -C $KERNEL_ROOT -s image_name)
    export VMLINUZ=$(realpath $KERNEL_ROOT/$image_name)
else
    export VMLINUZ=$GITHUB_WORKSPACE/$ARCH/vmlinuz-$KERNEL
fi


mkdir -p bin
if ! [ -f bin/vmtest ]; then
  curl -L https://github.com/danobi/vmtest/releases/download/v0.15.0/vmtest-$(uname -m) -o bin/vmtest
  chmod 755 bin/vmtest
fi
export PATH=$GITHUB_WORKSPACE/bin:$PATH

# export VMTEST_SCRIPT=$GITHUB_WORKSPACE/ci/vmtest/run_selftests.sh
export QEMU_ROOTFS=$GITHUB_WORKSPACE/rootfs
# export PROJECT_NAME=/mnt/vmtest

# sudo -E PATH=$PATH

export ALLOWLIST_FILE=/tmp/.allowlist
cat "$GITHUB_WORKSPACE/selftests/bpf/ALLOWLIST" \
    "$GITHUB_WORKSPACE/selftests/bpf/ALLOWLIST.${ARCH}" \
    "$GITHUB_WORKSPACE/ci/vmtest/configs/ALLOWLIST" \
    "$GITHUB_WORKSPACE/ci/vmtest/configs/ALLOWLIST-${KERNEL}" \
    "$GITHUB_WORKSPACE/ci/vmtest/configs/ALLOWLIST-${KERNEL}.${ARCH}" \
    2> /dev/null > "${ALLOWLIST_FILE}" || true

export DENYLIST_FILE=/tmp/.denylist
cat "$GITHUB_WORKSPACE/selftests/bpf/DENYLIST" \
    "$GITHUB_WORKSPACE/selftests/bpf/DENYLIST.${ARCH}" \
    "$GITHUB_WORKSPACE/ci/vmtest/configs/DENYLIST" \
    "$GITHUB_WORKSPACE/ci/vmtest/configs/DENYLIST-${KERNEL}" \
    "$GITHUB_WORKSPACE/ci/vmtest/configs/DENYLIST-${KERNEL}.${ARCH}" \
    2> /dev/null > "${DENYLIST_FILE}" || true

$GITHUB_ACTION_PATH/run.sh | cat

