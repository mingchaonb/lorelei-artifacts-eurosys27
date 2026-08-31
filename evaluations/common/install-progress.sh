#!/usr/bin/env bash

# Two-line terminal dashboard shared by the top-level installers. Child output
# scrolls above the current-item and aggregate-progress rows. Redirected output
# remains plain text without terminal control sequences.
install_progress_init() {
    install_progress_label=$1
    install_progress_total=$2
    install_progress_plain=$3
    install_progress_done=0
    install_progress_passed=0
    install_progress_failed=0
    install_progress_current=Preparing
    install_progress_detail="0 of $install_progress_total complete"
    install_progress_active=false
}

install_progress_restore() {
    if $install_progress_active; then
        printf '\033[r\033[%d;1H\033[0m\n' "$install_progress_rows"
        install_progress_active=false
    fi
}

install_progress_draw() {
    $install_progress_active || return 0
    local columns prefix suffix width filled empty bar empty_bar
    columns=$(tput cols 2>/dev/null || printf '80')
    prefix="$install_progress_label ["
    printf -v suffix '] %d/%d  PASS %d  FAIL %d' \
        "$install_progress_done" "$install_progress_total" \
        "$install_progress_passed" "$install_progress_failed"
    width=$((columns - ${#prefix} - ${#suffix}))
    if ((width < 12)); then width=12; fi
    if ((width > 100)); then width=100; fi
    filled=$((install_progress_done * width / install_progress_total))
    empty=$((width - filled))
    printf -v bar '%*s' "$filled" ''
    bar=${bar// /#}
    printf -v empty_bar '%*s' "$empty" ''
    bar+="${empty_bar// /-}"
    printf '\033[1;%dr' "$install_progress_log_bottom"
    printf '\033[%d;1H\033[2K\033[1m%s\033[0m  %s' \
        "$((install_progress_rows - 1))" "$install_progress_current" "$install_progress_detail"
    printf '\033[%d;1H\033[2K\033[1;36m%s [%s] %d/%d\033[0m  \033[1;32mPASS %d\033[0m  \033[1;31mFAIL %d\033[0m' \
        "$install_progress_rows" "$install_progress_label" "$bar" \
        "$install_progress_done" "$install_progress_total" \
        "$install_progress_passed" "$install_progress_failed"
    printf '\033[%d;1H' "$install_progress_log_bottom"
}

install_progress_stream() {
    local line
    while IFS= read -r line || [[ -n $line ]]; do
        printf '%s\n' "$line"
        install_progress_draw
    done
}

install_progress_resize() {
    $install_progress_active || return 0
    install_progress_rows=$(tput lines)
    ((install_progress_rows >= 7)) || return 0
    install_progress_log_bottom=$((install_progress_rows - 2))
    install_progress_draw
}

install_progress_setup() {
    $install_progress_plain && return 0
    [[ -t 1 && ${TERM:-dumb} != dumb ]] || return 0
    command -v tput >/dev/null 2>&1 || return 0
    install_progress_rows=$(tput lines)
    ((install_progress_rows >= 7)) || return 0
    install_progress_log_bottom=$((install_progress_rows - 2))
    install_progress_active=true
    printf '\033[2J\033[H\033[1;%dr\033[1;1H' "$install_progress_log_bottom"
    install_progress_draw
    trap install_progress_restore EXIT
    trap install_progress_resize WINCH
}

# Run one item without letting set -e abort the complete installation plan.
# The function returns the child status after updating the dashboard counters.
install_progress_run() {
    local item=$1 index=$2 status outcome
    shift 2
    install_progress_current="INSTALL $item"
    install_progress_detail="Item $index of $install_progress_total"
    install_progress_draw
    printf '\n[%d/%d] INSTALL %s\n' "$index" "$install_progress_total" "$item"
    printf '  $'; printf ' %q' "$@"; printf '\n'
    if $install_progress_active; then
        set +e
        "$@" 2>&1 | install_progress_stream
        status=${PIPESTATUS[0]}
        set -e
    else
        set +e
        "$@"
        status=$?
        set -e
    fi
    ((install_progress_done += 1))
    if ((status == 0)); then
        ((install_progress_passed += 1))
        outcome=PASS
    else
        ((install_progress_failed += 1))
        outcome=FAIL
    fi
    install_progress_current="$outcome $item"
    install_progress_detail="Exit $status, item $index of $install_progress_total"
    install_progress_draw
    printf '[%d/%d] %s %s, exit %d\n' "$index" "$install_progress_total" \
        "$outcome" "$item" "$status"
    return "$status"
}

install_progress_finish() {
    install_progress_current=COMPLETE
    install_progress_detail="$install_progress_passed passed, $install_progress_failed failed"
    install_progress_draw
    install_progress_restore
    printf '\nInstallation summary: %d passed, %d failed, %d total\n' \
        "$install_progress_passed" "$install_progress_failed" "$install_progress_total"
}
