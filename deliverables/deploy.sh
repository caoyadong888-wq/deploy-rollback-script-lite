#!/usr/bin/env bash
# Lite deploy: dry-run prints rsync and ssh steps for one current symlink.
# --lab --apply copies into a local releases/<id> and points current at it.
# This file does not create previous, shared links, or prune, and it never calls ssh.
# Rollback, previous, shared paths, and prune are in the full pack.
# Check upstream docs before you change the printed OpenSSH or rsync flags.
set -euo pipefail

MODE="dry-run"
LAB=0
CONFIG=""
HOST="${DEPLOY_HOST:-app.example.com}"
USER_NAME="${DEPLOY_USER:-deploy}"
PORT="${DEPLOY_PORT:-22}"
BASE="${DEPLOY_BASE:-/var/www/app}"
SRC="${DEPLOY_SRC:-}"
RELEASE_ID="${DEPLOY_RELEASE_ID:-}"
BASE_SET=0
SET_HOST=0
SET_USER=0
SET_PORT=0
SET_BASE=0
SET_SRC=0
SET_RELEASE=0
CLI_HOST=""
CLI_USER=""
CLI_PORT=""
CLI_BASE=""
CLI_SRC=""
CLI_RELEASE=""
if [[ -n "${DEPLOY_BASE:-}" ]]; then
  BASE_SET=1
fi

usage() {
  cat <<'EOF'
usage: deploy.sh [--dry-run|--apply] [--lab] [--config FILE]
                 [--src DIR] [--base DIR] [--host HOST] [--user USER]
                 [--port PORT] [--release-id ID]

Default is --dry-run. Prints rsync and ssh steps and does not connect.
--lab --apply copies files locally and sets current -> releases/<id>.
This lite script does not set previous and does not call ssh.
EOF
}

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

parse_config() {
  local file="$1" line key val last
  [[ -f "$file" ]] || { echo "missing config: $file" >&2; exit 2; }
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    line="${line%%#*}"
    line="$(trim "$line")"
    [[ -z "$line" ]] && continue
    [[ "$line" == *=* ]] || { echo "bad config line" >&2; exit 2; }
    key="$(trim "${line%%=*}")"
    val="$(trim "${line#*=}")"
    if [[ ${#val} -ge 2 ]]; then
      last="${val: -1}"
      if [[ "$val" == \"* && "$last" == '"' ]] || [[ "$val" == \'* && "$last" == "'" ]]; then
        val="${val:1:${#val}-2}"
      fi
    fi
    case "$key" in
      DEPLOY_HOST) HOST="$val" ;;
      DEPLOY_USER) USER_NAME="$val" ;;
      DEPLOY_PORT) PORT="$val" ;;
      DEPLOY_BASE) BASE="$val"; BASE_SET=1 ;;
      DEPLOY_SRC) SRC="$val" ;;
      DEPLOY_RELEASE_ID) RELEASE_ID="$val" ;;
      *) echo "unknown config key: $key" >&2; exit 2 ;;
    esac
  done <"$file"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) MODE="dry-run" ;;
    --apply) MODE="apply" ;;
    --lab) LAB=1 ;;
    --config) CONFIG="${2:-}"; [[ -n "$CONFIG" ]] || { echo "missing value for $1" >&2; exit 2; }; shift ;;
    --src) CLI_SRC="${2:-}"; SET_SRC=1; [[ -n "$CLI_SRC" ]] || { echo "missing value for $1" >&2; exit 2; }; shift ;;
    --base) CLI_BASE="${2:-}"; SET_BASE=1; [[ -n "$CLI_BASE" ]] || { echo "missing value for $1" >&2; exit 2; }; shift ;;
    --host) CLI_HOST="${2:-}"; SET_HOST=1; [[ -n "$CLI_HOST" ]] || { echo "missing value for $1" >&2; exit 2; }; shift ;;
    --user) CLI_USER="${2:-}"; SET_USER=1; [[ -n "$CLI_USER" ]] || { echo "missing value for $1" >&2; exit 2; }; shift ;;
    --port) CLI_PORT="${2:-}"; SET_PORT=1; [[ -n "$CLI_PORT" ]] || { echo "missing value for $1" >&2; exit 2; }; shift ;;
    --release-id) CLI_RELEASE="${2:-}"; SET_RELEASE=1; [[ -n "$CLI_RELEASE" ]] || { echo "missing value for $1" >&2; exit 2; }; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

if [[ -n "$CONFIG" ]]; then
  parse_config "$CONFIG"
fi
[[ "$SET_HOST" -eq 1 ]] && HOST="$CLI_HOST"
[[ "$SET_USER" -eq 1 ]] && USER_NAME="$CLI_USER"
[[ "$SET_PORT" -eq 1 ]] && PORT="$CLI_PORT"
[[ "$SET_BASE" -eq 1 ]] && BASE="$CLI_BASE" && BASE_SET=1
[[ "$SET_SRC" -eq 1 ]] && SRC="$CLI_SRC"
[[ "$SET_RELEASE" -eq 1 ]] && RELEASE_ID="$CLI_RELEASE"

if [[ -z "$RELEASE_ID" ]]; then
  RELEASE_ID="$(date -u +%Y%m%dT%H%M%SZ)"
fi
if [[ ! "$HOST" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$ ]]; then
  echo "DEPLOY_HOST must be a hostname" >&2
  exit 2
fi
if [[ ! "$USER_NAME" =~ ^[A-Za-z_][A-Za-z0-9._-]*$ ]]; then
  echo "DEPLOY_USER is not a safe ssh user" >&2
  exit 2
fi
if [[ ! "$PORT" =~ ^[0-9]+$ ]] || [[ "$PORT" -lt 1 ]] || [[ "$PORT" -gt 65535 ]]; then
  echo "DEPLOY_PORT is out of range" >&2
  exit 2
fi
if [[ ! "$BASE" =~ ^/[A-Za-z0-9._/-]+$ ]] || [[ "$BASE" == *..* ]]; then
  echo "DEPLOY_BASE must be an absolute path without .." >&2
  exit 2
fi
if [[ ! "$RELEASE_ID" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "bad release id" >&2
  exit 2
fi
if [[ -z "$SRC" || ! -d "$SRC" ]]; then
  echo "src is not a directory: ${SRC:-"(missing)"}" >&2
  exit 2
fi
if [[ "$LAB" -eq 1 && "$BASE_SET" -ne 1 ]]; then
  echo "lab mode requires --base or DEPLOY_BASE" >&2
  exit 2
fi
if [[ "$MODE" == "apply" && "$LAB" -ne 1 ]]; then
  echo "refusing remote apply: this lite script only applies with --lab" >&2
  exit 3
fi

echo "tool: deploy.sh"
echo "mode: ${MODE}"
echo "lab: ${LAB}"
echo "edition: lite"
if [[ "$LAB" -eq 1 ]]; then
  echo "note: lab mode uses local directories only; ssh is not called"
fi
echo "note: previous symlink, shared paths, prune, and rollback.sh are in the full version"
echo "host: ${USER_NAME}@${HOST}:${PORT}"
echo "base: ${BASE}"
echo "src: ${SRC}"
echo "release_id: ${RELEASE_ID}"
echo "pattern: current -> releases/<release_id>"

DEST="${BASE}/releases/${RELEASE_ID}"
if [[ "$LAB" -eq 1 && "$MODE" == "apply" ]]; then
  if [[ -e "$DEST" ]]; then
    echo "release already exists: $DEST" >&2
    exit 2
  fi
  if [[ -e "${BASE}/current" && ! -L "${BASE}/current" ]]; then
    echo "current exists and is not a symlink" >&2
    exit 2
  fi
  echo "run: mkdir -p -- ${DEST}"
  mkdir -p -- "$DEST"
  echo "run: rsync -a --delete ${SRC}/ ${DEST}/"
  command rsync -a --delete "${SRC}/" "${DEST}/"
  echo "run: ln -sfn -- releases/${RELEASE_ID} ${BASE}/current"
  ln -sfn -- "releases/${RELEASE_ID}" "${BASE}/current"
  echo "result: applied"
  exit 0
fi

echo "step: ssh -p ${PORT} -o BatchMode=yes ${USER_NAME}@${HOST} -- mkdir -p ${DEST}"
echo "step: rsync -a --delete -e \"ssh -p ${PORT} -o BatchMode=yes\" ${SRC}/ ${USER_NAME}@${HOST}:${DEST}/"
echo "step: ssh -p ${PORT} -o BatchMode=yes ${USER_NAME}@${HOST} -- ln -sfn releases/${RELEASE_ID} ${BASE}/current"
echo "result: dry-run"
