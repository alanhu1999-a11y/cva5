#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'USAGE'
Usage: formal/scripts/run_jg.sh [options]

Options:
  --target NAME       Tcl target name under formal/scripts/tcl (default: axi_smoke)
  --gui 0|1           Run interactive GUI style when 1; batch when 0 (default: 0)
  --run-name NAME     Use NAME for the run directory instead of a timestamp
  --no-filelist       Do not regenerate the RTL filelist before launching Jasper
  -h, --help          Show this help
USAGE
}

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"

TARGET="axi_smoke"
GUI=0
RUN_NAME=""
UPDATE_FILELIST=1

while [[ $# -gt 0 ]]; do
    case "$1" in
        --target)
            TARGET="${2:?missing value for --target}"
            shift 2
            ;;
        --gui)
            GUI="${2:?missing value for --gui}"
            shift 2
            ;;
        --run-name)
            RUN_NAME="${2:?missing value for --run-name}"
            shift 2
            ;;
        --no-filelist)
            UPDATE_FILELIST=0
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "error: unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

TCL_FILE="${REPO_ROOT}/formal/scripts/tcl/${TARGET}.tcl"
if [[ ! -f "${TCL_FILE}" ]]; then
    echo "error: target Tcl not found: ${TCL_FILE}" >&2
    exit 1
fi

if ! command -v jg >/dev/null 2>&1; then
    echo "error: JasperGold command 'jg' not found in PATH" >&2
    echo "hint: source your Cadence/Jasper environment, then rerun this command" >&2
    exit 1
fi

if [[ "${UPDATE_FILELIST}" -eq 1 ]]; then
    "${REPO_ROOT}/formal/scripts/populate_cva5_rtl_vfile.sh"
fi

export CVA5_ROOT="${REPO_ROOT}"
export JG_CVA5_RTL_PATH="${REPO_ROOT}"
export JG_GUI="${GUI}"

if [[ -z "${RUN_NAME}" ]]; then
    RUN_NAME="$(date +%Y%m%d_%H%M%S)"
fi

RUN_DIR="${REPO_ROOT}/formal/runs/${TARGET}/${RUN_NAME}"
export JG_RUN_DIR="${RUN_DIR}"
PROJECT_DIR="${RUN_DIR}/jgproject"
LOG_FILE="${RUN_DIR}/jg.log"
mkdir -p "${PROJECT_DIR}"

{
    echo "target=${TARGET}"
    echo "gui=${GUI}"
    echo "tcl=${TCL_FILE}"
    echo "run_dir=${RUN_DIR}"
    echo "project_dir=${PROJECT_DIR}"
    if [[ -n "${JG_PROPERTY:-}" ]]; then
        echo "property=${JG_PROPERTY}"
    fi
    if [[ -n "${JG_STAGE:-}" ]]; then
        echo "stage=${JG_STAGE}"
    fi
    if [[ -n "${JG_TIME_LIMIT:-}" ]]; then
        echo "time_limit=${JG_TIME_LIMIT}"
    fi
    if [[ -n "${AXI_READ_USE_PROVEN_LEMMAS:-}" ]]; then
        echo "axi_read_use_proven_lemmas=${AXI_READ_USE_PROVEN_LEMMAS}"
    fi
    if [[ -n "${AXI_WRITE_INCLUDE_UNDRIVEN_FIELDS:-}" ]]; then
        echo "axi_write_include_undriven_fields=${AXI_WRITE_INCLUDE_UNDRIVEN_FIELDS}"
    fi
    if [[ -n "${JG_FRAMEWORK_RUN_PROOFS:-}" ]]; then
        echo "framework_run_proofs=${JG_FRAMEWORK_RUN_PROOFS}"
    fi
    if [[ -n "${JG_CVA5_FRAMEWORK_RUN_PROOFS:-}" ]]; then
        echo "cva5_framework_run_proofs=${JG_CVA5_FRAMEWORK_RUN_PROOFS}"
    fi
    if [[ -n "${JG_CVA5_FRAMEWORK_RUN_REACHABILITY:-}" ]]; then
        echo "cva5_framework_run_reachability=${JG_CVA5_FRAMEWORK_RUN_REACHABILITY}"
    fi
    if [[ -n "${JG_CVA5_FRAMEWORK_RUN_DEEP_RESPONSE:-}" ]]; then
        echo "cva5_framework_run_deep_response=${JG_CVA5_FRAMEWORK_RUN_DEEP_RESPONSE}"
    fi
    if [[ -n "${JG_CVA5_FRAMEWORK_LOAD_STAGE:-}" ]]; then
        echo "cva5_framework_load_stage=${JG_CVA5_FRAMEWORK_LOAD_STAGE}"
    fi
    if [[ -n "${JG_CVA5_FRAMEWORK_SAFETY_STAGE:-}" ]]; then
        echo "cva5_framework_safety_stage=${JG_CVA5_FRAMEWORK_SAFETY_STAGE}"
    fi
    if [[ -n "${JG_CVA5_LOAD_MAX_JOBS:-}" ]]; then
        echo "cva5_load_max_jobs=${JG_CVA5_LOAD_MAX_JOBS}"
    fi
    if [[ -n "${JG_CVA5_LOAD_ORCHESTRATION:-}" ]]; then
        echo "cva5_load_orchestration=${JG_CVA5_LOAD_ORCHESTRATION}"
    fi
    if [[ -n "${JG_CVA5_LOAD_DUMP_TRACE:-}" ]]; then
        echo "cva5_load_dump_trace=${JG_CVA5_LOAD_DUMP_TRACE}"
    fi
    if [[ -n "${JG_ENGINE_MODE:-}" ]]; then
        echo "engine_mode=${JG_ENGINE_MODE}"
    fi
    if command -v git >/dev/null 2>&1 && git -C "${REPO_ROOT}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "git_commit=$(git -C "${REPO_ROOT}" rev-parse --short HEAD)"
        if [[ -n "$(git -C "${REPO_ROOT}" status --short)" ]]; then
            echo "git_dirty=1"
        else
            echo "git_dirty=0"
        fi
    fi
    echo "started=$(date -Is)"
    jg -version 2>&1 || true
} > "${RUN_DIR}/command.txt"

cd "${REPO_ROOT}"

if [[ "${GUI}" == "1" ]]; then
    CMD=(jg -proj "${PROJECT_DIR}" -tcl "${TCL_FILE}")
else
    CMD=(jg -batch -proj "${PROJECT_DIR}" -tcl "${TCL_FILE}")
fi

printf '%q ' "${CMD[@]}" | tee -a "${RUN_DIR}/command.txt"
printf '\n' | tee -a "${RUN_DIR}/command.txt"

"${CMD[@]}" 2>&1 | tee "${LOG_FILE}"

echo
echo "Run directory: ${RUN_DIR}"
echo "Log: ${LOG_FILE}"
