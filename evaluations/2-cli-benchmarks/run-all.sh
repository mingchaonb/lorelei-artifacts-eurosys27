#!/usr/bin/env bash
set -euo pipefail

# Run every command-line workload sequentially while preserving enough state to
# resume after a failure, interruption, or terminal disconnect.
base_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd "$base_dir/../.." && pwd)

reference=false
install_only=false
restart=false
plain=false
lanes=${LANES:-native,qemu,blink,box64,fex,qemu-hecate,blink-hecate,box64-hecate,fex-hecate}
while (($#)); do
    case $1 in
        --reference) reference=true ;;
        --install-only) install_only=true ;;
        --restart) restart=true ;;
        --plain) plain=true ;;
        --lanes)
            shift
            lanes=${1:?--lanes requires a comma-separated value}
            ;;
        -h|--help)
            cat <<EOF
Usage: $0 [--reference] [--install-only] [--lanes LIST] [--restart] [--plain]

Run every command-line workload in a stable order. A repeated command resumes
automatically, skips successful workloads, and retries failed or interrupted
workloads.

  --reference     Write author-side reference results.
  --install-only  Prepare every workload without running measurements.
  --lanes LIST    Run the comma-separated lane list.
  --restart       Archive the saved controller state and start again.
  --plain         Disable the sticky terminal progress display.

REPETITIONS and TIMEOUT_SECONDS are forwarded through the environment.
EOF
            exit 0
            ;;
        --*) echo "Unknown option: $1" >&2; exit 2 ;;
        *) echo "Unexpected positional argument: $1" >&2; exit 2 ;;
    esac
    shift
done

if $reference && $install_only; then
    echo "--reference and --install-only cannot be combined" >&2
    exit 2
fi

devkit=$(realpath -m "${LORELEI_DEVKIT:-$repo_root/.work/devkit}")
[[ -d $devkit ]] || { echo "Devkit not found: $devkit" >&2; exit 2; }

# A second controller can otherwise write stale status into a newly restarted
# batch. Keep one controller for this evaluation group, including installation.
batch_root=$repo_root/.work/evaluations/2-cli-benchmarks-batch
mkdir -p "$batch_root"
exec 9>"$batch_root/controller.lock"
flock -n 9 || { echo "Another command-line benchmark controller is running" >&2; exit 2; }

# Make the public batch command self-contained. vcpkg returns immediately for
# tools that are already installed and retains its shared downloads and cache.
"$repo_root/evaluations/install-tools.sh"

# Keep independent resumable states for evaluator, reference, and installation
# runs. A lane change within a mode requires --restart and is checked below.
mode=evaluator
$reference && mode=reference
$install_only && mode=install-only
state_dir=$batch_root/$mode

if $restart && [[ -d $state_dir ]]; then
    archive=$batch_root/history/$(date -u +%Y%m%dT%H%M%SZ)-$mode
    mkdir -p "$(dirname "$archive")"
    mv "$state_dir" "$archive"
    echo "Archived previous batch state: $archive"
fi
mkdir -p "$state_dir"/{logs,status}

# Freeze the discovered workload set for the lifetime of this batch. New
# recipes are picked up after --restart, never halfway through a resumed run.
plan=$state_dir/plan.txt
discovered_plan=$(mktemp)
find "$base_dir" -mindepth 2 -maxdepth 2 -type f -name run.sh -printf '%h\n' \
    | xargs -r -n1 basename | sort -u >"$discovered_plan"
if [[ ! -f $plan ]]; then
    cp "$discovered_plan" "$plan"
elif ! cmp -s "$plan" "$discovered_plan"; then
    echo "The available workload recipes changed after this batch was created:" >&2
    diff -u "$plan" "$discovered_plan" >&2 || true
    rm -f "$discovered_plan"
    echo "Use --restart to create a batch plan containing the current recipes." >&2
    exit 2
fi
rm -f "$discovered_plan"
[[ -s $plan ]] || { echo "No command-line workloads found" >&2; exit 1; }

# Refuse to merge results made with different execution settings. Paths are
# recorded after normalization so launching from another directory is safe.
identity=$state_dir/configuration.txt
current_identity=$(mktemp)
trap 'rm -f "$current_identity"' EXIT
{
    printf 'devkit=%s\n' "$devkit"
    printf 'lanes=%s\n' "$lanes"
    printf 'repetitions=%s\n' "${REPETITIONS:-5}"
    printf 'timeout_seconds=%s\n' "$(python3 -c 'import sys; print(min(100.0, float(sys.argv[1])))' "${TIMEOUT_SECONDS:-100}")"
    printf 'qemu=%s\n' "$(realpath -m "${QEMU:-$repo_root/vcpkg/installed/arm64-linux/tools/qemu-ae/qemu-x86_64}")"
    printf 'blink=%s\n' "$(realpath -m "${BLINK:-$repo_root/vcpkg/installed/arm64-linux/tools/blink-ae/blink}")"
    printf 'box64=%s\n' "$(realpath -m "${BOX64:-$repo_root/vcpkg/installed/arm64-linux/tools/box64-ae/box64}")"
    printf 'fex=%s\n' "$(realpath -m "${FEX:-$repo_root/vcpkg/installed/arm64-linux/tools/fex-ae/FEX}")"
} >"$current_identity"
if [[ -f $identity ]] && ! cmp -s "$identity" "$current_identity"; then
    echo "Saved batch state uses different execution settings:" >&2
    diff -u "$identity" "$current_identity" >&2 || true
    echo "Use --restart to begin with the current settings." >&2
    exit 2
fi
cp "$current_identity" "$identity"

total=$(wc -l <"$plan")
stop_requested=false
ui_active=false
ui_current=Preparing
ui_detail="Loading saved batch state"
recent_entries=()
ui_passed=0
ui_failed=0
ui_completed=0
ui_pending=$total

ui_restore() {
    if $ui_active; then
        printf '\033[r\033[%d;1H\033[0m\n' "$ui_rows"
        ui_active=false
    fi
}

cleanup() {
    ui_restore
    rm -f "$current_identity"
}
trap cleanup EXIT

ui_refresh_counts() {
    ui_passed=$(find "$state_dir/status" -maxdepth 1 -type f -name '*.tsv' \
        -exec awk -F '\t' '$1 == "pass" {n++} END {print n + 0}' {} + \
        | awk '{n += $1} END {print n + 0}')
    ui_failed=$(find "$state_dir/status" -maxdepth 1 -type f -name '*.tsv' \
        -exec awk -F '\t' '$1 == "fail" {n++} END {print n + 0}' {} + \
        | awk '{n += $1} END {print n + 0}')
    ui_completed=$((ui_passed + ui_failed))
    ui_pending=$((total - ui_completed))
}

ui_draw() {
    $ui_active || return 0
    local filled empty bar empty_bar width=32
    local recent_row=$((ui_rows - 4))
    local current_row=$((ui_rows - 1))
    filled=$((ui_completed * width / total))
    empty=$((width - filled))
    printf -v bar '%*s' "$filled" ''
    bar=${bar// /#}
    printf -v empty_bar '%*s' "$empty" ''
    bar+="${empty_bar// /-}"
    printf '\033[1;%dr' "$ui_log_bottom"
    local row=$recent_row entry
    for entry in "${recent_entries[@]}"; do
        printf '\033[%d;1H\033[2K  %s' "$row" "$entry"
        ((row += 1))
    done
    while ((row < current_row)); do
        printf '\033[%d;1H\033[2K' "$row"
        ((row += 1))
    done
    printf '\033[%d;1H\033[2K\033[1m%s\033[0m  %s' "$current_row" "$ui_current" "$ui_detail"
    printf '\033[%d;1H\033[2K\033[1;36mWorkloads [%s] %d/%d\033[0m  \033[1;32mPASS %d\033[0m  \033[1;31mFAIL %d\033[0m  pending %d' \
        "$ui_rows" "$bar" "$ui_completed" "$total" "$ui_passed" "$ui_failed" "$ui_pending"
    printf '\033[%d;1H' "$ui_log_bottom"
}

ui_stream_output() {
    local line
    while IFS= read -r line || [[ -n $line ]]; do
        printf '%s\n' "$line"
        ui_draw
    done
}

ui_add_recent() {
    recent_entries+=("$1")
    if ((${#recent_entries[@]} > 3)); then
        recent_entries=("${recent_entries[@]:1}")
    fi
    ui_draw
}

ui_setup() {
    $plain && return 0
    [[ -t 1 && ${TERM:-dumb} != dumb ]] || return 0
    command -v tput >/dev/null 2>&1 || return 0
    ui_rows=$(tput lines)
    ((ui_rows >= 10)) || return 0
    ui_log_bottom=$((ui_rows - 5))
    ui_active=true
    printf '\033[2J\033[H\033[1;%dr\033[1;1H' "$ui_log_bottom"
    ui_refresh_counts
    ui_draw
}

ui_resize() {
    $ui_active || return 0
    ui_rows=$(tput lines)
    ((ui_rows >= 10)) || return 0
    ui_log_bottom=$((ui_rows - 5))
    ui_draw
}

handle_stop() {
    stop_requested=true
    ui_current=Stopping
    ui_detail="Waiting for the active workload runner to return"
    ui_draw
}

trap handle_stop INT TERM HUP
trap ui_resize WINCH

write_summary() {
    local summary=$state_dir/summary.tsv name status_file
    printf 'workload\tstatus\texit_status\telapsed_seconds\tattempt\tresult_dir\n' >"$summary"
    while IFS= read -r name; do
        status_file=$state_dir/status/$name.tsv
        if [[ -f $status_file ]]; then
            printf '%s\t' "$name" >>"$summary"
            cat "$status_file" >>"$summary"
        else
            printf '%s\tpending\t\t\t\t\n' "$name" >>"$summary"
        fi
    done <"$plan"
}

index=0
ui_setup
while IFS= read -r name; do
    ((index += 1))
    runner=$base_dir/$name/run.sh
    status_file=$state_dir/status/$name.tsv
    if [[ -f $status_file && $(cut -f1 "$status_file") == pass ]]; then
        ui_current="SKIP $name"
        ui_detail="Already passed in the saved batch state"
        ui_draw
        printf '[%d/%d] SKIP %s, already passed\n' "$index" "$total" "$name"
        continue
    fi

    attempt=$(find "$state_dir/logs" -maxdepth 1 -type f -name "$name-attempt-*.log" | wc -l)
    ((attempt += 1))
    log=$state_dir/logs/$name-attempt-$attempt.log
    result_root=$base_dir/$name/results
    $reference && result_root=$base_dir/$name/reference-results
    before=$(find "$result_root" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | tail -1 || true)
    started=$SECONDS
    command=(env "LORELEI_DEVKIT=$devkit" "$runner")
    $reference && command+=(--reference)
    $install_only && command+=(--install-only)
    if ! $install_only; then command+=(--lanes "$lanes"); fi

    ui_current="RUN $name"
    ui_detail="Attempt $attempt, batch item $index of $total"
    ui_draw
    printf '\n[%d/%d] RUN %s, attempt %d\n' "$index" "$total" "$name" "$attempt"
    printf '  $'; printf ' %q' "${command[@]}"; printf '\n'
    printf 'running\t\t\t%s\t\n' "$attempt" >"$status_file"
    ui_refresh_counts
    ui_draw
    set +e
    if $ui_active; then
        "${command[@]}" 2>&1 | tee "$log" | ui_stream_output
        exit_status=${PIPESTATUS[0]}
    else
        "${command[@]}" 2>&1 | tee "$log"
        exit_status=${PIPESTATUS[0]}
    fi
    set -e
    elapsed=$((SECONDS - started))
    after=$(find "$result_root" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | tail -1 || true)
    result_dir=$after
    if [[ $after == "$before" ]]; then result_dir=; fi

    status=fail
    if ((exit_status == 0)); then status=pass; fi
    printf '%s\t%s\t%s\t%s\t%s\n' \
        "$status" "$exit_status" "$elapsed" "$attempt" "$result_dir" >"$status_file"
    write_summary
    ui_refresh_counts
    ui_current="${status^^} $name"
    ui_detail="Exit $exit_status after ${elapsed}s"
    ui_add_recent "[$index/$total] $name  ${status^^}  exit=$exit_status  ${elapsed}s"
    printf '[%d/%d] %s %s, exit %d, %ds\n' \
        "$index" "$total" "${status^^}" "$name" "$exit_status" "$elapsed"

    if $stop_requested || ((exit_status == 130 || exit_status == 143)); then
        echo "Batch interrupted. Re-run the same command to resume."
        exit 130
    fi
done <"$plan"

write_summary
passed=$(awk -F '\t' 'NR > 1 && $2 == "pass" {n++} END {print n + 0}' "$state_dir/summary.tsv")
failed=$(awk -F '\t' 'NR > 1 && $2 == "fail" {n++} END {print n + 0}' "$state_dir/summary.tsv")
pending=$((total - passed - failed))

ui_current=COMPLETE
ui_detail="$passed passed, $failed failed, $pending pending"
ui_draw
ui_restore
printf '\nBatch summary: %d passed, %d failed, %d pending, %d selected\n' \
    "$passed" "$failed" "$pending" "$total"
echo "Controller state: $state_dir"
echo "Per-workload status: $state_dir/summary.tsv"
if ((failed || pending)); then
    echo "Re-run the same command to retry every non-passing workload."
    exit 1
fi
