#!/bin/bash

# This script will only work in BPF CI-like environment,
# assuming Linux Kernel source at /ci/workspace and
# kernel-patches/libbpf/ci repo at /ci/actions

TESTS_ONLY=${1:-}

export ARCH=x86_64
export TOOLCHAIN=llvm
export MAX_MAKE_JOBS=$(nproc)
export KBUILD_OUTPUT=$(realpath kbuild-output)

if [ -z "$TESTS_ONLY" ]; then
    # make -C tools/testing/selftests/bpf -j48
    # rm -rf kbuild-output
    /ci/actions/build-linux/build.sh $ARCH $TOOLCHAIN kbuild-output

    export GITHUB_ACTION_PATH=/ci/actions/build-selftests
    export SELFTESTS_BPF_TARGETS=test_progs
    /ci/actions/build-selftests/build_selftests.sh $ARCH $TOOLCHAIN $(pwd)

    rm -rf selftests
    cp -r tools/testing/selftests selftests
fi

export ALLOWLIST_FILE=$(realpath selftests/bpf/ALLOWLIST)
echo "trace" > $ALLOWLIST_FILE
# export DENYLIST_FILE=$(realpath selftests/bpf/DENYLIST)
# echo "sockmap_ktls/sockmap_ktls disconnect_after_delete" > $DENYLIST_FILE

# export TEST_PROGS_WATCHDOG_TIMEOUT=20

# test_progs_parallel
export KERNEL_TEST=test_progs_parallel
export KERNEL=LATEST
export KERNEL_ROOT=$(pwd)
export PATH=$(pwd):$PATH
export GITHUB_ACTION_PATH=/ci/actions/run-vmtest

/ci/actions/run-vmtest/run.sh | tee /ci/run.log
exit 0

### bisection

log=$(mktemp test_progs.log.XXXXXX)
echo -n > $log
/ci/actions/run-vmtest/run.sh 2>&1 > $log &
tail -f $log &

while true; do
    # echo "run.sh: checking test_progs.log"
    if grep -q "btf_tag/btf_type_tag_percpu_vmlinux_helper:FAIL" $log; then
        # killall -TERM qemu-system-amd64
        exit 1
    fi
    # Check if background process is still running
    if grep -q  "Summary: .*/.* PASSED, .* SKIPPED, 0 FAILED" $log; then
        exit 0
    fi
    sleep 1
done
