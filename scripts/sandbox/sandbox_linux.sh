#!/usr/bin/env bash
set -euo pipefail

#
# sandbox_linux.sh
# ------------------
# Creates a short-lived, network-isolated execution environment for running
# validation commands on Linux hosts. The script relies exclusively on
# kernel namespaces (no containers) so that it can run on minimal build
# agents while still providing strong isolation guarantees.
#
# Key behaviours:
#   * Creates an ephemeral workspace directory with 0700 permissions.
#   * Launches the requested command inside new user, PID, UTS, IPC and
#     network namespaces.
#   * Configures the sandbox so that only the loopback interface is
#     available – no external network access is possible.
#   * Propagates a small, deterministic environment for reproducible builds.
#
# Requirements: unshare(1), ip(8), mktemp(1), bash(1), git (optional when
#                using --checkout).
#

PROGRAM_NAME=$(basename "${0}")
DEFAULT_PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

usage() {
    cat <<USAGE
Usage: ${PROGRAM_NAME} [options] -- <command>

Options:
  -w, --workspace PATH   Existing directory to bind as sandbox workspace.
                         If omitted, a secure temporary directory is created.
  -c, --checkout REF     Optional Git ref to checkout into the workspace
                         (requires git). Ignored when --workspace is provided.
  -k, --keep             Preserve the workspace directory after execution.
  -e, --env KEY=VALUE    Additional environment variables to expose inside
                         the sandbox. May be specified multiple times.
  -h, --help             Show this help text and exit.

The command following "--" is executed inside the sandbox. Example:
  ${PROGRAM_NAME} -c main -- pytest -q
USAGE
}

fatal() {
    echo "${PROGRAM_NAME}: $*" >&2
    exit 1
}

require_binary() {
    local binary=$1
    command -v "${binary}" >/dev/null 2>&1 || fatal "Required dependency '${binary}' is not available in PATH"
}

WORKSPACE=""
KEEP_WORKSPACE=false
CHECKOUT_REF=""
declare -a SANDBOX_ENVS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        -w|--workspace)
            [[ $# -lt 2 ]] && fatal "--workspace requires a path argument"
            WORKSPACE=$(realpath "$2")
            shift 2
            ;;
        -c|--checkout)
            [[ $# -lt 2 ]] && fatal "--checkout requires a Git ref"
            CHECKOUT_REF=$2
            shift 2
            ;;
        -k|--keep)
            KEEP_WORKSPACE=true
            shift
            ;;
        -e|--env)
            [[ $# -lt 2 ]] && fatal "--env requires KEY=VALUE"
            SANDBOX_ENVS+=("$2")
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            break
            ;;
        *)
            fatal "Unknown option: $1"
            ;;
    esac
done

[[ $# -gt 0 ]] || fatal "A command to execute is required. Use -- to separate options from the command."

COMMAND=("$@")

require_binary "unshare"
require_binary "ip"
require_binary "mktemp"

if [[ -z "${WORKSPACE}" ]]; then
    WORKSPACE=$(mktemp -d -t aiuokeep-sandbox-XXXXXX)
    chmod 700 "${WORKSPACE}"
    CREATED_TEMP_WORKSPACE=true
else
    [[ -d "${WORKSPACE}" ]] || fatal "Workspace path '${WORKSPACE}' does not exist"
    CREATED_TEMP_WORKSPACE=false
fi

if [[ -n "${CHECKOUT_REF}" ]]; then
    require_binary "git"
    if [[ -d "${WORKSPACE}/.git" ]]; then
        fatal "--checkout cannot be used with an existing Git repository"
    fi
    git init -q "${WORKSPACE}"
    git -C "${WORKSPACE}" remote add origin "$(git -C "${PWD}" config --get remote.origin.url || echo '.')" 2>/dev/null || true
    git -C "${WORKSPACE}" fetch --depth 1 origin "${CHECKOUT_REF}" >/dev/null 2>&1 || fatal "Unable to fetch ref '${CHECKOUT_REF}'"
    git -C "${WORKSPACE}" checkout -q FETCH_HEAD || fatal "Failed to checkout ref '${CHECKOUT_REF}'"
fi

if [[ ! -w "${WORKSPACE}" ]]; then
    fatal "Workspace '${WORKSPACE}' is not writable"
fi

cleanup() {
    local exit_code=$?
    if [[ ${KEEP_WORKSPACE} == false && ${CREATED_TEMP_WORKSPACE:-false} == true ]]; then
        rm -rf "${WORKSPACE}"
    fi
    exit ${exit_code}
}

trap cleanup EXIT

# Prepare environment variables for the sandboxed process.
SANDBOX_ENV_OPTS=("HOME=${WORKSPACE}" "PATH=${DEFAULT_PATH}" "SANDBOX_WORKSPACE=${WORKSPACE}")
for env_kv in "${SANDBOX_ENVS[@]}"; do
    SANDBOX_ENV_OPTS+=("${env_kv}")
done

# Build the command executed inside the namespace. The loopback interface is
# brought up explicitly so local services (e.g., test servers) continue to work.
SANDBOX_SCRIPT=$(cat <<'INNER'
set -euo pipefail
ip link set lo up >/dev/null 2>&1 || true
cd "${SANDBOX_WORKSPACE}"
umask 077
export HOME="${SANDBOX_WORKSPACE}"
export PATH="${PATH:-}"
exec "${SANDBOX_SHELL}" -lc "${SANDBOX_COMMAND}"
INNER
)

# Export command and shell via environment to avoid injection issues.
SANDBOX_SHELL=${SHELL:-/bin/bash}
SANDBOX_COMMAND=$(printf ' %q' "${COMMAND[@]}")
SANDBOX_COMMAND=${SANDBOX_COMMAND:1}

export SANDBOX_COMMAND SANDBOX_SHELL SANDBOX_WORKSPACE="${WORKSPACE}"

unshare --user --map-root-user --pid --ipc --uts --net --mount --fork --mount-proc \
    env -i "${SANDBOX_ENV_OPTS[@]}" SANDBOX_COMMAND="${SANDBOX_COMMAND}" SANDBOX_SHELL="${SANDBOX_SHELL}" SANDBOX_WORKSPACE="${WORKSPACE}" \
    bash -c "${SANDBOX_SCRIPT}"

INNER_EXIT=$?
exit ${INNER_EXIT}
