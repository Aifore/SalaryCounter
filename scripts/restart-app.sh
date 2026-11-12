#!/usr/bin/env bash
# 只退出 SalaryCounter.app，再用参数给出的这个 .app 重新打开。
# 按可执行文件路径识别，避免杀掉名字碰巧相似的进程。
# 用绝对路径打开 build 产物，避免按应用名启动“应用程序”文件夹里的旧副本。
set -euo pipefail

APP=${1:-}
if [ -z "$APP" ]; then
  echo "用法: restart-app.sh /绝对路径/SalaryCounter.app" >&2
  exit 1
fi

APP=$(cd "$(dirname "$APP")" && pwd)/$(basename "$APP")
BIN="$APP/Contents/MacOS/SalaryCounter"
BUNDLE_ID="local.salarycounter.app"
WAIT_SLICE=${SALARYCOUNTER_WAIT_SLICE:-0.2}
WAIT_TRIES=${SALARYCOUNTER_WAIT_TRIES:-10}

if [ ! -f "$BIN" ]; then
  echo "找不到刚编译的程序：${BIN}" >&2
  exit 1
fi

is_app_args() {
  case "$1" in
    *"/SalaryCounter.app/Contents/MacOS/SalaryCounter"*) return 0 ;;
    *) return 1 ;;
  esac
}

is_built_args() {
  case "$1" in
    *"$BIN"*) return 0 ;;
    *) return 1 ;;
  esac
}

each_pid() {
  local pid
  while IFS= read -r pid; do
    [ -n "$pid" ] || continue
    printf '%s\n' "$pid"
  done < <(pgrep -x SalaryCounter || true)
}

args_of() {
  ps -p "$1" -ww -o args= 2>/dev/null || true
}

list_app_pids() {
  local pid args
  for pid in $(each_pid); do
    args=$(args_of "$pid")
    if is_app_args "$args"; then
      printf '%s\n' "$pid"
    fi
  done
}

wait_until_gone() {
  local i
  for i in $(seq 1 "$WAIT_TRIES"); do
    if [ -z "$(list_app_pids)" ]; then
      return 0
    fi
    sleep "$WAIT_SLICE"
  done
  return 1
}

signal_pids() {
  local signal=$1
  local pid
  local pids
  pids=$(list_app_pids)
  [ -n "$pids" ] || return 0
  for pid in $pids; do
    env kill "-$signal" "$pid" 2>/dev/null || true
  done
}

stop_running_copies() {
  if [ -z "$(list_app_pids)" ]; then
    return 0
  fi
  if command -v osascript >/dev/null 2>&1; then
    osascript -e "tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1 || true
    wait_until_gone || true
  fi
  if [ -n "$(list_app_pids)" ]; then
    signal_pids TERM
    wait_until_gone || true
  fi
  if [ -n "$(list_app_pids)" ]; then
    signal_pids KILL
    wait_until_gone || true
  fi
  if [ -n "$(list_app_pids)" ]; then
    echo "仍有 SalaryCounter.app 在运行，没有启动新副本。" >&2
    return 1
  fi
}

stop_other_copies() {
  local pid args
  for pid in $(list_app_pids); do
    args=$(args_of "$pid")
    if ! is_built_args "$args"; then
      env kill -TERM "$pid" 2>/dev/null || true
    fi
  done
}

wait_for_built() {
  local i pid args
  for i in $(seq 1 "$WAIT_TRIES"); do
    for pid in $(list_app_pids); do
      args=$(args_of "$pid")
      if is_built_args "$args"; then
        return 0
      fi
    done
    sleep "$WAIT_SLICE"
  done
  return 1
}

stop_running_copies

if ! open -n "$APP"; then
  echo "无法打开 $APP" >&2
  exit 1
fi

if ! wait_for_built; then
  stop_other_copies || true
  echo "没有启动刚编译的 ${APP}。" >&2
  echo "如果应用程序文件夹里还有同名 SalaryCounter，系统可能按 bundle id 打开了旧副本。请先移走旧版本后再运行 make update 或 make run。" >&2
  exit 1
fi

stop_other_copies || true
echo "已启动 $APP"
