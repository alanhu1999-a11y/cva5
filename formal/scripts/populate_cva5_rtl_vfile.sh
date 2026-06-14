#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"

COMPILE_ORDER="${COMPILE_ORDER:-${REPO_ROOT}/tools/compile_order}"
OUT_FILE="${1:-${REPO_ROOT}/formal/filelists/cva5_rtl.vfile}"
RTL_VAR="${RTL_VAR:-JG_CVA5_RTL_PATH}"

if [[ ! -f "${COMPILE_ORDER}" ]]; then
    echo "error: compile order file not found: ${COMPILE_ORDER}" >&2
    exit 1
fi

mkdir -p "$(dirname -- "${OUT_FILE}")"

tmp_file="$(mktemp "${OUT_FILE}.tmp.XXXXXX")"
trap 'rm -f "${tmp_file}"' EXIT

missing=0
mapfile -t rtl_sources < <(
    awk '
        NF == 0 { next }
        /^[[:space:]]*#/ { next }
        { print $1 }
    ' "${COMPILE_ORDER}"
)

if [[ "${#rtl_sources[@]}" -eq 0 ]]; then
    echo "error: no RTL sources found in ${COMPILE_ORDER}" >&2
    exit 1
fi

for source in "${rtl_sources[@]}"; do
    if [[ ! -f "${REPO_ROOT}/${source}" ]]; then
        echo "error: missing RTL source from compile order: ${source}" >&2
        missing=1
    fi
done

if [[ "${missing}" -ne 0 ]]; then
    exit 1
fi

{
    printf '+incdir+${%s}\\\n' "${RTL_VAR}"
    for i in "${!rtl_sources[@]}"; do
        source="${rtl_sources[$i]}"
        if [[ "${i}" -eq "$((${#rtl_sources[@]} - 1))" ]]; then
            printf '${%s}/%s\n' "${RTL_VAR}" "${source}"
        else
            printf '${%s}/%s \\\n' "${RTL_VAR}" "${source}"
        fi
    done
} > "${tmp_file}"

mv "${tmp_file}" "${OUT_FILE}"
chmod 0644 "${OUT_FILE}"
trap - EXIT

echo "wrote ${#rtl_sources[@]} RTL sources to ${OUT_FILE}"
