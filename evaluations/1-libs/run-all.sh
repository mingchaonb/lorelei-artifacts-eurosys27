#!/usr/bin/env bash
set -euo pipefail

base_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd "$base_dir/../.." && pwd)

run_all=false
restart=false
verbose=false
plain=false
positional=()
while (($#)); do
    case $1 in
        --all) run_all=true ;;
        --restart) restart=true ;;
        --verbose) verbose=true ;;
        --plain) plain=true ;;
        -h|--help)
            echo "Usage: $0 [--all] [--restart] [--verbose] [--plain]"
            echo "Default: run only recipes marked [ALL TESTS PASSED]."
            echo "--all: run every library recipe except the synthetic breakdown-test."
            echo "--restart: archive the saved batch state and start every selected recipe again."
            echo "--plain: disable the sticky terminal progress display."
            echo "A repeated command resumes automatically, skipping successful recipes and retrying failures."
            exit 0
            ;;
        --*) echo "Unknown option: $1" >&2; exit 2 ;;
        *) echo "Unexpected positional argument: $1" >&2; exit 2 ;;
    esac
    shift
done

devkit=$(realpath -m "${LORELEI_DEVKIT:-$repo_root/.work/devkit}")
[[ -d $devkit ]] || { echo "Devkit not found: $devkit" >&2; exit 2; }

mode=verified
if $run_all; then mode=all; fi
batch_root=$repo_root/.work/evaluations/1-libs-batch
state_dir=$batch_root/$mode

# A restart preserves the previous controller logs while clearing only the
# resumable status for this mode. Per-library results remain append-only.
if $restart && [[ -d $state_dir ]]; then
    archive=$batch_root/history/$(date -u +%Y%m%dT%H%M%SZ)-$mode
    mkdir -p "$(dirname "$archive")"
    mv "$state_dir" "$archive"
    echo "Archived previous batch state: $archive"
fi
mkdir -p "$state_dir"/{logs,status}

# Discover a stable, sorted plan on the first invocation. Resume always uses
# the recorded plan even if unrelated recipes appear while the batch runs.
plan=$state_dir/plan.txt
if [[ ! -f $plan ]]; then
    while IFS= read -r runner; do
        name=$(basename "$(dirname "$runner")")
        [[ $name != breakdown-test ]] || continue
        if ! $run_all; then
            readme=$(dirname "$runner")/README.md
            [[ -f $readme ]] || continue
            head -n 1 "$readme" | grep -Fq '[ALL TESTS PASSED]' || continue
        fi
        printf '%s\n' "$name"
    done < <(find "$base_dir" -mindepth 2 -maxdepth 2 -type f -name run.sh | sort) >"$plan"
fi
[[ -s $plan ]] || { echo "No recipes selected" >&2; exit 1; }

# Refuse to resume a state created with another devkit. This avoids combining
# evidence from two installations in one controller summary.
identity=$state_dir/devkit.txt
if [[ -f $identity && $(<"$identity") != "$devkit" ]]; then
    echo "Saved state uses a different devkit: $(<"$identity")" >&2
    echo "Use --restart to begin with $devkit" >&2
    exit 2
fi
printf '%s\n' "$devkit" >"$identity"

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

# An interactive terminal reserves five rows at the bottom for the three most
# recent results, the active recipe, and aggregate progress. Test output scrolls
# above them. Redirected output remains ordinary plain text
# so logs and CI captures never contain terminal control sequences.
ui_restore() {
    if $ui_active; then
        printf '\033[r\033[%d;1H\033[0m\n' "$ui_rows"
        ui_active=false
    fi
}

ui_refresh_counts() {
    ui_passed=$(find "$state_dir/status" -maxdepth 1 -type f -name '*.tsv' -exec awk -F '\t' '$1 == "pass" {n++} END {print n + 0}' {} + | awk '{n += $1} END {print n + 0}')
    ui_failed=$(find "$state_dir/status" -maxdepth 1 -type f -name '*.tsv' -exec awk -F '\t' '$1 == "fail" {n++} END {print n + 0}' {} + | awk '{n += $1} END {print n + 0}')
    ui_completed=$((ui_passed + ui_failed))
    ui_pending=$((total - ui_completed))
}

ui_draw() {
    $ui_active || return 0
    local columns prefix='Libraries [' suffix width filled empty bar empty_bar
    local recent_row=$((ui_rows - 4))
    local current_row=$((ui_rows - 1))
    local progress_row=$ui_rows
    columns=$(tput cols 2>/dev/null || printf '80')
    printf -v suffix '] %d/%d  PASS %d  FAIL %d  pending %d' \
        "$ui_completed" "$total" "$ui_passed" "$ui_failed" "$ui_pending"
    width=$((columns - ${#prefix} - ${#suffix}))
    if ((width < 12)); then width=12; fi
    if ((width > 100)); then width=100; fi
    filled=$((ui_completed * width / total))
    empty=$((width - filled))
    printf -v bar '%*s' "$filled" ''
    bar=${bar// /#}
    printf -v empty_bar '%*s' "$empty" ''
    bar+="${empty_bar// /-}"
    # Reapply the upper scrolling region on every redraw because a child
    # process may reset terminal margins while printing its own progress.
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
    printf '\033[%d;1H\033[2K\033[1;36mLibraries [%s] %d/%d\033[0m  \033[1;32mPASS %d\033[0m  \033[1;31mFAIL %d\033[0m  pending %d' \
        "$progress_row" "$bar" "$ui_completed" "$total" "$ui_passed" "$ui_failed" "$ui_pending"
    # Always return output to the last row of the log region. This prevents a
    # child cursor-control sequence from placing later output in the dashboard.
    printf '\033[%d;1H' "$ui_log_bottom"
}

# Child output passes through this renderer only in interactive mode. The raw
# stream is written by tee before this function sees it, so evidence logs never
# contain the dashboard's control sequences.
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
    ui_detail="Waiting for the active library runner to return"
    ui_draw
}

trap handle_stop INT TERM HUP
trap ui_resize WINCH
trap ui_restore EXIT

write_summary() {
    local summary=$state_dir/summary.tsv name status_file
    printf 'library\tstatus\texit_status\telapsed_seconds\tattempt\tresult_dir\n' >"$summary"
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
for name in $(<"$plan"); do
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
    before=$(find "$base_dir/$name/results" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | tail -1 || true)
    started=$SECONDS
    command=(env "LORELEI_DEVKIT=$devkit" "$runner")
    if $verbose; then command+=(--verbose); fi

    ui_current="RUN $name"
    ui_detail="Attempt $attempt of this recipe, batch item $index of $total"
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
    after=$(find "$base_dir/$name/results" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | tail -1 || true)
    result_dir=$after
    if [[ $after == "$before" ]]; then result_dir=; fi

    status=fail
    if ((exit_status == 0)); then status=pass; fi
    printf '%s\t%s\t%s\t%s\t%s\n' "$status" "$exit_status" "$elapsed" "$attempt" "$result_dir" >"$status_file"
    write_summary
    ui_refresh_counts
    ui_current="${status^^} $name"
    ui_detail="Exit $exit_status after ${elapsed}s"
    ui_add_recent "[$index/$total] $name  ${status^^}  exit=$exit_status  ${elapsed}s"
    printf '[%d/%d] %s %s, exit %d, %ds\n' "$index" "$total" "${status^^}" "$name" "$exit_status" "$elapsed"

    if $stop_requested || ((exit_status == 130 || exit_status == 143)); then
        echo "Batch interrupted. Re-run the same command to resume."
        exit 130
    fi
done

write_summary
"$base_dir/_common/summarize-library-inventory.sh" >"$state_dir/inventory.tsv"
passed=$(awk -F '\t' 'NR > 1 && $2 == "pass" {n++} END {print n + 0}' "$state_dir/summary.tsv")
failed=$(awk -F '\t' 'NR > 1 && $2 == "fail" {n++} END {print n + 0}' "$state_dir/summary.tsv")
pending=$((total - passed - failed))

ui_current="COMPLETE"
ui_detail="$passed passed, $failed failed, $pending pending"
ui_draw
ui_restore
printf '\nBatch summary: %d passed, %d failed, %d pending, %d selected\n' "$passed" "$failed" "$pending" "$total"
echo "Controller state: $state_dir"
echo "Per-library status: $state_dir/summary.tsv"
echo "Inventory snapshot: $state_dir/inventory.tsv"
if ((failed || pending)); then
    echo "Re-run the same command to retry every non-passing recipe."
    exit 1
fi
