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

if [[ -z "${RUN_NAME}" ]]; then
    RUN_NAME="$(date +%Y%m%d_%H%M%S)"
fi

RUN_DIR="${REPO_ROOT}/formal/runs/${TARGET}/${RUN_NAME}"
PROJECT_DIR="${RUN_DIR}/jgproject"
LOG_FILE="${RUN_DIR}/jg.log"
mkdir -p "${PROJECT_DIR}"

{
    echo "target=${TARGET}"
    echo "gui=${GUI}"
    echo "tcl=${TCL_FILE}"
    echo "run_dir=${RUN_DIR}"
    echo "project_dir=${PROJECT_DIR}"
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
