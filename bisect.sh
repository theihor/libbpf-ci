#!/bin/bash

# This script will only work in BPF CI-like environment,
# assuming Linux Kernel source at /ci/workspace and
# kernel-patches/libbpf/ci repo at /ci/actions

TESTS_ONLY=${1:-}

export KBUILD_OUTPUT=$(realpath kbuild-output)

if [ -z "$TESTS_ONLY" ]; then
    # make -C tools/testing/selftests/bpf -j48
    # rm -rf kbuild-output
    /ci/actions/build-linux/build.sh x86_64 llvm kbuild-output

    export GITHUB_ACTION_PATH=/ci/actions/build-selftests
    export SELFTESTS_BPF_TARGETS=test_progs
    /ci/actions/build-selftests/build_selftests.sh x86_64 llvm $(pwd)

    rm -rf selftests
    cp -r tools/testing/selftests selftests
fi

# export ALLOWLIST_FILE=$(realpath selftests/bpf/ALLOWLIST)
# echo "sockmap_ktls" > $ALLOWLIST_FILE
export DENYLIST_FILE=$(realpath selftests/bpf/DENYLIST)
echo "sockmap_ktls/sockmap_ktls disconnect_after_delete" > $DENYLIST_FILE

# export TEST_PROGS_WATCHDOG_TIMEOUT=20

# test_progs_parallel
export KERNEL_TEST=test_progs
export KERNEL=LATEST
export KERNEL_ROOT=$(pwd)
export PATH=$(pwd):$PATH
export GITHUB_ACTION_PATH=/ci/actions/run-vmtest

## /ci/actions/run-vmtest/run.sh | tee /ci/run.log

### bisection

log=$(mktemp test_progs.log.XXXXXX)
echo -n > $log
/ci/actions/run-vmtest/run.sh 2>&1 > $log &
tail -f $log &

while true; do
    # echo "run.sh: checking test_progs.log"
    if grep -q "sockmap_ktls:FAIL" $log; then
        killall -TERM qemu-system-x86_64
        exit 1
    fi
    # Check if background process is still running
    if grep -q  "Summary: .*/.* PASSED, .* SKIPPED, .* FAILED" $log; then
        exit 0
    fi
    sleep 1
done

