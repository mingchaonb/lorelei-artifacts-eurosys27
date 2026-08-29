#!/usr/bin/env bash

set -euo pipefail
: "${REAL_CC:?REAL_CC is required}"
: "${PROGRAM_WRAPPER:?PROGRAM_WRAPPER is required}"

arguments=("$@")
output=
output_index=
for ((i = 0; i < ${#arguments[@]}; ++i)); do
    if [[ "${arguments[$i]}" == -o && $((i + 1)) -lt ${#arguments[@]} ]]; then
        output=${arguments[$((i + 1))]}
        output_index=$((i + 1))
        break
    fi
done

case "$(basename "${output:-}")" in
    genutf8|gengb18030z)
        arguments[$output_index]="$output.guest"
        "$REAL_CC" "${arguments[@]}"
        cp "$PROGRAM_WRAPPER" "$output"
        chmod +x "$output"
        ;;
    *)
        exec "$REAL_CC" "$@"
        ;;
esac
