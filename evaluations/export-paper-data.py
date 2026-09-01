#!/usr/bin/env python3
"""Export evaluation evidence to readable CSV files used by paper plots."""

from __future__ import annotations

import argparse
import csv
import hashlib
import importlib.util
import json
import pathlib
import re
import shutil
import statistics
import subprocess
from typing import Iterable


LANES = [
    "native",
    "qemu",
    "blink",
    "box64",
    "fex",
    "qemu-hecate",
    "blink-hecate",
    "box64-hecate",
    "fex-hecate",
]

GAME_LANES = ["qemu-hecate", "native", "box64", "box64-hecate"]
GAME_FPS_UPPER_BOUND = 300.0
GAME_ORDER = [
    "supertux",
    "supertuxkart",
    "assaultcube",
    "redeclipse",
    "hollow-knight",
    "openarena",
]


def newest_directory(root: pathlib.Path, required: str) -> pathlib.Path | None:
    if not root.is_dir():
        return None
    candidates = [path for path in root.iterdir() if path.is_dir() and (path / required).is_file()]
    return sorted(candidates)[-1] if candidates else None


def newest_lane_results(root: pathlib.Path) -> dict[str, pathlib.Path]:
    """Return the newest evidence file for every lane independently.

    A workload runner normally writes all selected lanes into one timestamped
    directory.  During bring-up, however, lanes are often measured in several
    invocations.  Selecting a directory solely because it contains native.json
    silently discards newer evidence for every other lane.
    """
    results: dict[str, pathlib.Path] = {}
    if not root.is_dir():
        return results
    for result_dir in sorted((path for path in root.iterdir() if path.is_dir()), reverse=True):
        for lane in LANES:
            candidate = result_dir / f"{lane}.json"
            if lane not in results and candidate.is_file():
                results[lane] = candidate
    return results


def write_csv(path: pathlib.Path, fields: list[str], rows: Iterable[dict]) -> None:
    with path.open("w", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def mangohud_samples(path: pathlib.Path) -> list[dict[str, float]]:
    """Read the numeric sample table from a MangoHud CSV log."""
    with path.open(newline="", errors="replace") as stream:
        rows = list(csv.reader(stream))
    try:
        header_index = next(
            index for index, row in enumerate(rows) if row and row[0].strip().lower() == "fps"
        )
    except StopIteration as error:
        raise ValueError("no MangoHud FPS header") from error
    header = [field.strip().lower() for field in rows[header_index]]
    samples = []
    for row in rows[header_index + 1 :]:
        if len(row) != len(header):
            continue
        try:
            samples.append(dict(zip(header, map(float, row))))
        except ValueError:
            continue
    if not samples or "fps" not in samples[0]:
        raise ValueError("no numeric MangoHud FPS samples")
    return samples


def game_fps_window(
    samples: list[dict[str, float]], sample_interval_ms: int
) -> list[dict[str, float]]:
    """Select [end - 12 seconds, end - 2 seconds) from MangoHud samples."""
    if sample_interval_ms <= 0:
        raise ValueError("sample interval must be positive")
    elapsed = [sample.get("elapsed") for sample in samples]
    if all(value is not None for value in elapsed):
        timestamps = [float(value) for value in elapsed if value is not None]
        if any(right < left for left, right in zip(timestamps, timestamps[1:])):
            raise ValueError("MangoHud elapsed timestamps are not monotonic")
        end_ns = timestamps[-1]
        start_ns = end_ns - 12_000_000_000
        stop_ns = end_ns - 2_000_000_000
        window = [
            sample
            for sample, timestamp in zip(samples, timestamps)
            if start_ns <= timestamp < stop_ns
        ]
        if not window or timestamps[0] > start_ns:
            raise ValueError("MangoHud recording is shorter than the 12-second window requirement")
        return window

    # Older logs without elapsed timestamps are sampled at the fixed interval
    # configured by the runner. Preserve compatibility with those files.
    samples_per_second = 1000 / sample_interval_ms
    trailing_samples = round(2 * samples_per_second)
    window_samples = round(10 * samples_per_second)
    required_samples = trailing_samples + window_samples
    if len(samples) < required_samples:
        raise ValueError(
            f"need at least {required_samples} samples for the 12-to-2-second window, "
            f"found {len(samples)}"
        )
    end = len(samples) - trailing_samples
    return samples[end - window_samples : end]


class Inputs:
    def __init__(self, root: pathlib.Path):
        self.root = root
        self.entries: dict[str, str] = {}

    def add(self, path: pathlib.Path) -> None:
        path = path.resolve()
        try:
            name = str(path.relative_to(self.root.resolve()))
        except ValueError:
            name = str(path)
        self.entries[name] = hashlib.sha256(path.read_bytes()).hexdigest()


def export_overall(repo: pathlib.Path, kind: str, output: pathlib.Path, inputs: Inputs) -> None:
    cli = repo / "evaluations/2-cli-benchmarks"
    rows = []
    for runner in sorted(cli.glob("*/run.sh")):
        workload = runner.parent.name
        lane_results = newest_lane_results(runner.parent / kind)
        native_path = lane_results.get("native")
        native_median = None
        if native_path:
            inputs.add(native_path)
            native = json.loads(native_path.read_text())
            if native.get("status") == "pass":
                native_median = native["seconds"]["median"]
        for lane in LANES:
            lane_path = lane_results.get(lane)
            row = {
                "workload": workload,
                "lane": lane,
                "status": "missing",
                "exclusion_reason": "",
                "repetitions": "",
                "minimum_seconds": "",
                "median_seconds": "",
                "maximum_seconds": "",
                "normalized_time": "",
                "result_dir": str(lane_path.parent.relative_to(repo)) if lane_path else "",
            }
            if lane_path:
                inputs.add(lane_path)
                data = json.loads(lane_path.read_text())
                row["status"] = data.get("status", "unknown")
                if row["status"] == "excluded":
                    row["exclusion_reason"] = data.get("exclusion_reason", "")
                row["repetitions"] = len(data.get("runs", []))
                seconds = data.get("seconds")
                if seconds and data.get("status") == "pass":
                    row["minimum_seconds"] = f'{seconds["minimum"]:.9f}'
                    row["median_seconds"] = f'{seconds["median"]:.9f}'
                    row["maximum_seconds"] = f'{seconds["maximum"]:.9f}'
                    if native_median:
                        normalized = seconds["median"] / native_median
                        if lane != "native" and normalized > 20:
                            row["status"] = "excluded"
                            row["exclusion_reason"] = "median_exceeded_20x_native"
                            row["minimum_seconds"] = ""
                            row["median_seconds"] = ""
                            row["maximum_seconds"] = ""
                        else:
                            row["normalized_time"] = f"{normalized:.9f}"
                elif any(run.get("timed_out") for run in data.get("runs", [])):
                    row["status"] = "excluded"
                    row["exclusion_reason"] = data.get(
                        "exclusion_reason",
                        "exceeded_20x_native_or_100_second_figure_17_cutoff",
                    )
            rows.append(row)
    write_csv(
        output / "overall.csv",
        [
            "workload",
            "lane",
            "status",
            "exclusion_reason",
            "repetitions",
            "minimum_seconds",
            "median_seconds",
            "maximum_seconds",
            "normalized_time",
            "result_dir",
        ],
        rows,
    )


def read_env_file(path: pathlib.Path) -> dict[str, str]:
    values = {}
    if not path.is_file():
        return values
    for line in path.read_text(errors="replace").splitlines():
        key, separator, value = line.partition("=")
        if separator:
            values[key] = value
    return values


def game_raw_csv(result_dir: pathlib.Path) -> pathlib.Path | None:
    summary_path = result_dir / "fps-summary.json"
    if summary_path.is_file():
        try:
            name = json.loads(summary_path.read_text()).get("raw_csv")
            matches = list(result_dir.rglob(name)) if name else []
            if len(matches) == 1:
                return matches[0]
        except (json.JSONDecodeError, OSError):
            pass
    candidates = sorted(
        path
        for path in (result_dir / "mangohud").glob("*.csv")
        if not path.name.endswith("_summary.csv")
    )
    return candidates[0] if candidates else None


def export_game_fps(repo: pathlib.Path, kind: str, output: pathlib.Path, inputs: Inputs) -> None:
    """Export the paper's fixed ten-second FPS window for every game lane."""
    games_root = repo / "evaluations/4-games"
    rows = []
    runners = {runner.parent.name: runner for runner in games_root.glob("*/run.sh")}
    ordered_games = [game for game in GAME_ORDER if game in runners]
    ordered_games.extend(sorted(set(runners) - set(ordered_games)))
    for game in ordered_games:
        runner = runners[game]
        result_dirs = sorted(
            (path for path in (runner.parent / kind).glob("*") if path.is_dir()), reverse=True
        )
        lane_results: dict[str, pathlib.Path] = {}
        for result_dir in result_dirs:
            run_env = read_env_file(result_dir / "run.env")
            lane = run_env.get("lane")
            if lane in GAME_LANES and lane not in lane_results:
                lane_results[lane] = result_dir

        for lane in GAME_LANES:
            result_dir = lane_results.get(lane)
            row = {
                "game": game,
                "lane": lane,
                "status": "missing",
                "physical_gpu": "",
                "sample_interval_ms": "",
                "total_sample_count": "",
                "window_sample_count": "",
                "ignored_high_fps_sample_count": "",
                "fps_upper_bound": f"{GAME_FPS_UPPER_BOUND:g}",
                "window_start_seconds_from_end": "-12",
                "window_end_seconds_from_end": "-2",
                "fps_mean": "",
                "fps_minimum": "",
                "fps_maximum": "",
                "fps_variance": "",
                "result_dir": "",
                "raw_csv": "",
            }
            if not result_dir:
                rows.append(row)
                continue

            raw_path = game_raw_csv(result_dir)
            summary_path = result_dir / "fps-summary.json"
            run_env_path = result_dir / "run.env"
            preflight_path = result_dir / "preflight-status.tsv"
            status_path = result_dir / "status.txt"
            fps_status_path = result_dir / "fps-status.txt"
            game_log_path = result_dir / "game.log"
            interval_ms = 100
            if summary_path.is_file():
                try:
                    interval_ms = int(json.loads(summary_path.read_text()).get("sample_interval_ms", 100))
                except (json.JSONDecodeError, TypeError, ValueError):
                    pass
            row.update(
                {
                    "sample_interval_ms": interval_ms,
                    "result_dir": str(result_dir.relative_to(repo)),
                    "raw_csv": str(raw_path.relative_to(repo)) if raw_path else "",
                }
            )
            physical_gpu = "unknown"
            if preflight_path.is_file():
                with preflight_path.open(newline="") as stream:
                    statuses = {entry[0]: entry[1] for entry in csv.reader(stream, delimiter="\t") if len(entry) >= 2}
                marker = statuses.get("physical-gpu-renderer")
                if marker == "0":
                    physical_gpu = "yes"
                elif marker == "1":
                    physical_gpu = "no"
            row["physical_gpu"] = physical_gpu
            if not raw_path:
                try:
                    exit_status = int(status_path.read_text().strip())
                except (OSError, ValueError):
                    row["status"] = "missing execution status"
                else:
                    signal_names = {132: "SIGILL", 134: "SIGABRT", 139: "SIGSEGV"}
                    if exit_status in signal_names:
                        row["status"] = f"crash: {signal_names[exit_status]}"
                    elif exit_status == 143 and (result_dir / "watchdog-fired").is_file():
                        row["status"] = "ran without FPS sample"
                    elif exit_status == 0:
                        row["status"] = "completed without FPS sample"
                    else:
                        row["status"] = f"failed: exit {exit_status}"
                for evidence in (run_env_path, preflight_path, status_path, fps_status_path, game_log_path):
                    if evidence.is_file():
                        inputs.add(evidence)
                rows.append(row)
                continue
            try:
                samples = mangohud_samples(raw_path)
                row["total_sample_count"] = len(samples)
                window = game_fps_window(samples, interval_ms)
                fps = [sample["fps"] for sample in window if sample["fps"] <= GAME_FPS_UPPER_BOUND]
                ignored = len(window) - len(fps)
                if not fps:
                    raise ValueError(
                        f"no FPS samples at or below {GAME_FPS_UPPER_BOUND:g} in the selected window"
                    )
                row.update(
                    {
                        "status": "measured",
                        "window_sample_count": len(fps),
                        "ignored_high_fps_sample_count": ignored,
                        "fps_mean": f"{statistics.fmean(fps):.9f}",
                        "fps_minimum": f"{min(fps):.9f}",
                        "fps_maximum": f"{max(fps):.9f}",
                        "fps_variance": f"{statistics.pvariance(fps):.9f}",
                    }
                )
                if physical_gpu == "no":
                    row["status"] = "invalid: non-physical OpenGL renderer"
            except (OSError, ValueError, KeyError) as error:
                row["status"] = f"insufficient: {error}"
            for evidence in (raw_path, summary_path, run_env_path, preflight_path, status_path, fps_status_path, game_log_path):
                if evidence.is_file():
                    inputs.add(evidence)
            rows.append(row)
    write_csv(
        output / "game-fps.csv",
        [
            "game",
            "lane",
            "status",
            "physical_gpu",
            "sample_interval_ms",
            "total_sample_count",
            "window_sample_count",
            "ignored_high_fps_sample_count",
            "fps_upper_bound",
            "window_start_seconds_from_end",
            "window_end_seconds_from_end",
            "fps_mean",
            "fps_minimum",
            "fps_maximum",
            "fps_variance",
            "result_dir",
            "raw_csv",
        ],
        rows,
    )


def median_row(path: pathlib.Path) -> dict[str, str]:
    with path.open(newline="") as stream:
        rows = list(csv.DictReader(stream))
    for row in rows:
        if row.get("round") == "median":
            return row
    raise RuntimeError(f"No median row in {path}")


def median_rows(path: pathlib.Path) -> list[dict[str, str]]:
    with path.open(newline="") as stream:
        return [row for row in csv.DictReader(stream) if row.get("round") == "median"]


def export_breakdowns(repo: pathlib.Path, kind: str, output: pathlib.Path, inputs: Inputs) -> None:
    root = repo / "evaluations/3-breakdown"
    function_result = newest_directory(root / "breakdown-test" / kind, "summary.csv")
    function_rows = []
    if function_result:
        summary = function_result / "summary.csv"
        inputs.add(summary)
        labels = [
            ("GTL packing", "gtl_ns"),
            ("HecMID trigger", "hecmid_ns"),
            ("QEMU syscall dispatch", "qemu_ns"),
            ("HTL unpacking", "htl_ns"),
        ]
        for row in median_rows(summary):
            case = row.get("case", "")
            match = re.fullmatch(r"(\d+)-arg", case)
            if not match:
                continue
            for order, (component, field) in enumerate(labels, 1):
                function_rows.append(
                    {
                        "case": case,
                        "argument_count": match.group(1),
                        "component_order": order,
                        "component": component,
                        "median_ns": row[field],
                        "result_dir": str(function_result.relative_to(repo)),
                    }
                )
    write_csv(
        output / "function-breakdown.csv",
        ["case", "argument_count", "component_order", "component", "median_ns", "result_dir"],
        function_rows,
    )

    callback_result = newest_directory(root / "box64-callback-track" / kind, "summary.csv")
    callback_rows = []
    if callback_result:
        summary = callback_result / "summary.csv"
        inputs.add(summary)
        row = median_row(summary)
        labels = [
            ("Find in guest libs", "guest_libs_ns"),
            ("Find in host libs", "host_libs_ns"),
            ("Check mapping", "protection_ns"),
            ("Find in GOT", "got_ns"),
            ("Find in wrapper", "wrapper_ns"),
        ]
        for order, (component, field) in enumerate(labels, 1):
            callback_rows.append(
                {
                    "system": "Box64",
                    "component_order": order,
                    "component": component,
                    "median_ns": row[field],
                    "status": "measured",
                    "result_dir": str(callback_result.relative_to(repo)),
                }
            )
    hecate_result = newest_directory(root / "hecate-callback-track" / kind, "summary.csv")
    if hecate_result:
        summary = hecate_result / "summary.csv"
        inputs.add(summary)
        row = median_row(summary)
        callback_rows.append(
            {
                "system": "Hecate",
                "component_order": 1,
                "component": "Compare address boundary",
                "median_ns": row["compare_ns"],
                "status": "measured",
                "result_dir": str(hecate_result.relative_to(repo)),
            }
        )
    else:
        callback_rows.append(
            {
                "system": "Hecate",
                "component_order": 1,
                "component": "Compare address boundary",
                "median_ns": "",
                "status": "missing",
                "result_dir": "",
            }
        )
    write_csv(
        output / "callback-track.csv",
        ["system", "component_order", "component", "median_ns", "status", "result_dir"],
        callback_rows,
    )


def count_symbols(path: pathlib.Path) -> int:
    section = None
    symbols = set()
    for raw in path.read_text(errors="replace").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("[") and line.endswith("]"):
            section = line
        elif section == "[Function]":
            symbols.add(line.split()[0])
    return len(symbols)


def exported_function_names(path: pathlib.Path) -> set[str]:
    output = subprocess.check_output(["nm", "-D", "--defined-only", str(path)], text=True)
    symbols = set()
    for line in output.splitlines():
        fields = line.split()
        if len(fields) >= 3 and fields[-2].upper() in {"T", "W"}:
            name = fields[-1].split("@", 1)[0]
            if name != "LoreGetFileContext":
                symbols.add(name)
    return symbols


def box64_wrapper_names(path: pathlib.Path) -> set[str]:
    pattern = re.compile(r"^\s*(?:GO|GOM|GO2|GOW|GOWM|GOS)\(\s*([^,\s]+)")
    return {
        match.group(1)
        for line in path.read_text(errors="replace").splitlines()
        if (match := pattern.match(line))
    }


def thunk_function_names(path: pathlib.Path) -> set[str]:
    data = json.loads(path.read_text())
    return {entry["name"] for entry in data["functions"]["GuestToHost"]}


def manual_configuration_loc(path: pathlib.Path, classify) -> int:
    """Count reviewed adaptation code, excluding generated API inventories."""
    if path.name == "Symbols.conf":
        return 0
    return classify(path.read_text(errors="replace"))["code"]


def box64_manual_configuration_loc(path: pathlib.Path, classify) -> int:
    """Count active code and manually maintained wrapper declarations."""
    pattern = re.compile(
        r"^\s*//\s*(?:GO|GOM|GO2|GOW|GOWM|GOS|DATA|DATAB|DATAM)\s*\("
    )
    text = path.read_text(errors="replace")
    return classify(text)["code"] + sum(
        bool(pattern.match(line)) for line in text.splitlines()
    )


def load_loc_counter(repo: pathlib.Path):
    path = repo / "evaluations/common/tools/count-configuration-loc.py"
    spec = importlib.util.spec_from_file_location("configuration_loc", path)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader
    spec.loader.exec_module(module)
    return module.classify_lines


def export_coverage(repo: pathlib.Path, output: pathlib.Path, inputs: Inputs) -> None:
    classify = load_loc_counter(repo)
    audit_result = newest_directory(
        repo / "evaluations/3-breakdown/coverage-effort/results", "summary.json"
    )
    audit_rows = {}
    audit_summary = None
    if audit_result:
        audit_summary = audit_result / "summary.json"
        inputs.add(audit_summary)
        audit_rows = {
            row["library"]: row for row in json.loads(audit_summary.read_text())
        }
    box64_roots = sorted(
        (repo / "vcpkg/installed").glob("*/share/box64-ae/coverage-source")
    )
    if not box64_roots:
        box64_roots = sorted(
            (repo / "vcpkg/buildtrees/box64-ae/src").glob("*.clean/src/wrapped")
        )
    box64_root = box64_roots[-1] if box64_roots else None
    specs = [
        ("zstd", "zstd", "hecate", "libzstd.so.*", "wrappedzstd", ["vcpkg-overlay/ports/zstd/lorelei"]),
        ("avformat", "ffmpeg", "hecate", "libavformat.so.*", "wrappedlibavformat58", ["vcpkg-overlay/ports/ffmpeg/lorelei/avformat"]),
        ("avcodec", "ffmpeg", "hecate", "libavcodec.so.*", "wrappedlibavcodec58", ["vcpkg-overlay/ports/ffmpeg/lorelei/avcodec"]),
        ("avutil", "ffmpeg", "hecate", "libavutil.so.*", "wrappedlibavutil56", ["vcpkg-overlay/ports/ffmpeg/lorelei/avutil"]),
        ("SDL2", "sdl2", "hecate", "libSDL2-2.0.so.*", "wrappedsdl2", ["vcpkg-overlay/ports/sdl2/lorelei"]),
        ("Vulkan", "vulkan-loader", "direct", "libvulkan.so.*", "wrappedvulkan", ["vcpkg-overlay/ports/vulkan-loader/lorelei"]),
        ("OpenGL", "glvnd", "direct", "libGL.so.*", "wrappedlibgl", ["vcpkg-overlay/ports/glvnd/lorelei"]),
        ("zlib", "zlib", "hecate", "libz.so.*", "wrappedlibz", ["vcpkg-overlay/ports/zlib/lorelei"]),
        ("X11", "libx11", "hecate", "libX11.so.*", "wrappedlibx11", ["vcpkg-overlay/ports/libx11/lorelei"]),
        ("XCB", "libxcb", "hecate", "libxcb.so.*", "wrappedlibxcb", ["vcpkg-overlay/ports/libxcb/lorelei"]),
        ("bzip2", "bzip2", "hecate", "libbz2.so.*", "wrappedbz2", ["vcpkg-overlay/ports/bzip2/lorelei"]),
        ("Brotli", "brotli", "hecate", "libbrotlidec.so.*", "wrappedbrotlidec", ["vcpkg-overlay/ports/brotli/lorelei"]),
        ("Expat", "expat", "hecate", "libexpat.so.*", "wrappedexpat", ["vcpkg-overlay/ports/expat/lorelei"]),
        ("curl", "libcurl", "hecate", "libcurl.so.*", "wrappedcurl", ["vcpkg-overlay/ports/libcurl/lorelei"]),
        ("libevent", "libevent", "hecate", "libevent_core-2.1.so.*", "wrappedevent21", ["vcpkg-overlay/ports/libevent/lorelei"]),
        ("IDN2", "libidn2", "hecate", "libidn2.so.*", "wrappedidn2", ["vcpkg-overlay/ports/libidn2/lorelei"]),
        ("LZMA", "liblzma", "hecate", "liblzma.so.*", "wrappedlzma", ["vcpkg-overlay/ports/liblzma/lorelei"]),
        ("Ogg", "libogg", "host", "libogg.so.*", "wrappedlibogg", ["vcpkg-overlay/ports/libogg/lorelei"]),
        ("Opus", "opus", "host", "libopus.so.*", "wrappedlibopus", ["vcpkg-overlay/ports/opus/lorelei"]),
        ("sndfile", "libsndfile", "host", "libsndfile.so.*", "wrappedlibsndfile", ["vcpkg-overlay/ports/libsndfile/lorelei"]),
    ]
    rows = []
    for library, state, lane, dso_glob, stem, config_roots in specs:
        row = {
            "library": library,
            "box64_supported_functions": "",
            "hecate_supported_functions": "",
            "exported_functions": "",
            "box64_coverage": "",
            "hecate_coverage": "",
            "box64_manual_loc": "",
            "hecate_manual_loc": "",
            "status": "missing",
        }
        if lane == "direct":
            install = repo / f".work/evaluations/{state}/installed/arm64-linux-ae"
        else:
            install = repo / f".work/evaluations/{state}/installed/{lane}/arm64-linux-ae"
        dsos = sorted((install / "lib").glob(dso_glob))
        # The graphics ports intentionally wrap the distribution's system
        # loader libraries instead of copying them into the vcpkg prefix.
        if state == "vulkan-loader":
            dsos = sorted(pathlib.Path("/usr/lib").glob("*-linux-gnu/libvulkan.so.1"))
        elif state == "glvnd":
            dsos = sorted(pathlib.Path("/usr/lib").glob("*-linux-gnu/libGL.so.1"))
        private = box64_root / f"{stem}_private.h" if box64_root else None
        box64_files = []
        if box64_root:
            box64_files = [box64_root / f"{stem}.c", box64_root / f"{stem}_private.h"]
        config_files = []
        for root_name in config_roots:
            config_files.extend(path for path in (repo / root_name).rglob("*") if path.is_file())
        audit = audit_rows.get(library)
        if dsos and audit and private and private.is_file() and all(path.is_file() for path in box64_files):
            exports = exported_function_names(dsos[0])
            box_supported = len(exports & box64_wrapper_names(private))
            hecate_supported = int(audit["hecate_supported_functions"])
            total = int(audit["exported_functions"])
            box_loc = sum(
                box64_manual_configuration_loc(path, classify) for path in box64_files
            )
            hecate_loc = sum(manual_configuration_loc(path, classify) for path in config_files)
            evidence_dir = repo / audit["evidence_dir"]
            audit_stat = evidence_dir / "ThunkStat.json"
            for path in [dsos[0], audit_stat, *box64_files, *config_files]:
                inputs.add(path)
            row.update(
                {
                    "box64_supported_functions": box_supported,
                    "hecate_supported_functions": hecate_supported,
                    "exported_functions": total,
                    "box64_coverage": f"{min(box_supported, total) / total:.9f}" if total else "",
                    "hecate_coverage": f"{min(hecate_supported, total) / total:.9f}" if total else "",
                    "box64_manual_loc": box_loc,
                    "hecate_manual_loc": hecate_loc,
                    "status": "measured",
                }
            )
        rows.append(row)
    write_csv(
        output / "coverage-effort.csv",
        [
            "library",
            "box64_supported_functions",
            "hecate_supported_functions",
            "exported_functions",
            "box64_coverage",
            "hecate_coverage",
            "box64_manual_loc",
            "hecate_manual_loc",
            "status",
        ],
        rows,
    )


def export_modifications(repo: pathlib.Path, kind: str, output: pathlib.Path, inputs: Inputs) -> None:
    result = newest_directory(repo / f"evaluations/5-modifications/{kind}", "summary.csv")
    destination = output / "modifications.csv"
    if result:
        source = result / "summary.csv"
        inputs.add(source)
        shutil.copyfile(source, destination)
    else:
        write_csv(
            destination,
            [
                "project",
                "modified_files",
                "modified_hunks",
                "modified_added_lines",
                "modified_deleted_lines",
                "modified_changed_lines",
                "new_files",
                "new_file_lines",
                "base",
                "head",
            ],
            [],
        )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--reference", action="store_true")
    parser.add_argument("--output", type=pathlib.Path)
    args = parser.parse_args()
    repo = pathlib.Path(__file__).resolve().parent.parent
    output = (args.output or repo / "evaluations/paper-data").resolve()
    output.mkdir(parents=True, exist_ok=True)
    kind = "reference-results" if args.reference else "results"
    inputs = Inputs(repo)

    export_overall(repo, kind, output, inputs)
    export_game_fps(repo, kind, output, inputs)
    export_breakdowns(repo, kind, output, inputs)
    export_coverage(repo, output, inputs)
    export_modifications(repo, kind, output, inputs)
    (output / "manifest.json").write_text(
        json.dumps(
            {
                "schema_version": 1,
                "result_kind": kind,
                "inputs": inputs.entries,
                "excluded": [
                    "Risotto performance",
                    "VA and FP statistics",
                    "library distribution",
                ],
            },
            indent=2,
            sort_keys=True,
        )
        + "\n"
    )
    print(f"Paper CSV data: {output}")


if __name__ == "__main__":
    main()
