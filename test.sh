#!/bin/bash

# This script will only work in BPF CI-like environment,
# assuming Linux Kernel source at /ci/workspace and
# kernel-patches/libbpf/ci repo at /ci/actions

TESTS_ONLY=${1:-}

export KBUILD_OUTPUT=${KBUILD_OUTPUT:-$(realpath kbuild-output)}

if [ -z "$TESTS_ONLY" ]; then
    /ci/actions/build-linux/build.sh x86_64 llvm $KBUILD_OUTPUT

    # export BPF_GCC=/ci/workspace/gcc-bpf/gcc-bpf
    export GITHUB_ACTION_PATH=/ci/actions/build-selftests
    export SELFTESTS_BPF_TARGETS=test_progs
    /ci/actions/build-selftests/build_selftests.sh x86_64 llvm $(pwd)

    rm -rf selftests
    cp -r tools/testing/selftests selftests
fi

# export ALLOWLIST_FILE=$(realpath selftests/bpf/ALLOWLIST)
# echo "sockmap_ktls" > $ALLOWLIST_FILE
# export DENYLIST_FILE=$(realpath selftests/bpf/DENYLIST)
# echo "verif_scale_pyperf600" > $DENYLIST_FILE

# export DENYLIST_FILE=$(realpath denylist.tmp)

# export TEST_PROGS_WATCHDOG_TIMEOUT=20

# test_progs_parallel

export KERNEL_TEST=test_progs
export KERNEL=LATEST
export KERNEL_ROOT=$(pwd)
export PATH=$(pwd):$PATH
export GITHUB_ACTION_PATH=/ci/actions/run-vmtest

if ! [ -f /usr/bin/vmtest ]; then
  curl -L https://github.com/danobi/vmtest/releases/download/v0.15.0/vmtest-$(uname -m) -o vmtest
  chmod 755 vmtest
  sudo cp vmtest /usr/bin/vmtest
fi

/ci/actions/run-vmtest/run.sh | tee /ci/run.log
