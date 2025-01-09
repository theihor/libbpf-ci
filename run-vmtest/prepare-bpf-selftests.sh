#!/bin/bash

set -euo pipefail

function merge_test_lists_into() {
    local out="$1"
    shift
    local files=("$@")
    echo -n > "$out"

    # first, append all the input lists into one
    for file in "${files[@]}"; do
        if [[ -f "$file" ]]; then
            echo "cat $file >> $out"
            cat "$file" >> "$out"
        fi
    done

    # then merge the list of test names
    cat "$out" | python3 merge_test_lists.py > "$out"
}

merge_test_lists_into "${ALLOWLIST_FILE}" "${SELFTESTS_BPF_ALLOWLIST_FILES[@]}"
merge_test_lists_into "${DENYLIST_FILE}" "${SELFTESTS_BPF_ALLOWLIST_FILES[@]}"

exit 0
