#!/usr/bin/env bash
# Linux 上用临时仓库和命令替身检查 make update。不启动 macOS 应用。
set -euo pipefail

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
failures=0

fail() {
  echo "FAIL: $*" >&2
  failures=$((failures + 1))
}

ok() {
  echo "OK: $*"
}

assert_grep() {
  local file=$1 pattern=$2 message=$3
  if grep -E -q "$pattern" "$file"; then
    ok "$message"
  else
    fail "$message"
  fi
}

assert_no_grep() {
  local file=$1 pattern=$2 message=$3
  if grep -E -q "$pattern" "$file"; then
    fail "$message"
  else
    ok "$message"
  fi
}

if bash -n "$REPO/scripts/update.sh" && bash -n "$REPO/scripts/restart-app.sh" && bash -n "$REPO/build.sh"; then
  ok "bash -n"
else
  fail "bash -n"
fi

dry=$(make -C "$REPO" -n update build run)
printf '%s\n' "$dry" | grep -q 'build.sh' && ok "dry-run mentions build" || fail "dry-run mentions build"
printf '%s\n' "$dry" | grep -q 'scripts/update.sh' && ok "dry-run mentions update" || fail "dry-run mentions update"
printf '%s\n' "$dry" | grep -q 'scripts/restart-app.sh' && ok "dry-run mentions restart" || fail "dry-run mentions restart"

if grep -E -n 'git (reset|rebase|stash|clean|push|checkout|merge)|killall' "$REPO/scripts/update.sh" "$REPO/scripts/restart-app.sh"; then
  fail "update scripts contain a destructive or broad command"
else
  ok "no destructive git command or killall"
fi
assert_grep "$REPO/scripts/update.sh" 'git pull --no-rebase --ff-only' "pull is fast-forward only and does not rebase"
assert_grep "$REPO/scripts/update.sh" 'git status --porcelain' "dirty check uses porcelain and therefore ignores generated files"
assert_grep "$REPO/scripts/restart-app.sh" 'open -n' "relaunch uses the given app path"
assert_no_grep "$REPO/scripts/restart-app.sh" 'open -a' "relaunch does not look the app up by name"

make_repo() {
  local dir=$1
  git init -b main "$dir" >/dev/null
  git -C "$dir" config user.email test@example.com
  git -C "$dir" config user.name test
  echo base > "$dir/README"
  git -C "$dir" add README
  git -C "$dir" commit -m init >/dev/null
}

track() {
  local dir=$1 remote=$2
  git init --bare -b main "$remote" >/dev/null
  git -C "$dir" remote add origin "$remote"
  git -C "$dir" push -u origin main >/dev/null
}

clone_of() {
  local remote=$1 dest=$2
  git clone "$remote" "$dest" >/dev/null
  git -C "$dest" config user.email test@example.com
  git -C "$dest" config user.name test
}

write_stubs() {
  local bin=$1
  mkdir -p "$bin"
  cat > "$bin/pgrep" <<'EOF'
#!/bin/bash
if [ ! -s "$STATE/pids" ]; then
  exit 1
fi
cat "$STATE/pids"
exit 0
EOF
  cat > "$bin/ps" <<'EOF'
#!/bin/bash
pid=""
prev=""
for arg in "$@"; do
  if [ "$prev" = "-p" ]; then
    pid=$arg
  fi
  prev=$arg
done
if [ -z "$pid" ] || [ ! -f "$STATE/args-$pid" ]; then
  exit 1
fi
cat "$STATE/args-$pid"
exit 0
EOF
  cat > "$bin/kill" <<'EOF'
#!/bin/bash
echo "kill $*" >> "$LOG"
pid=""
for arg in "$@"; do
  case "$arg" in
    -*) ;;
    *) pid=$arg ;;
  esac
done
if [ -n "$pid" ] && [ -f "$STATE/pids" ]; then
  grep -vx "$pid" "$STATE/pids" > "$STATE/pids.next" || true
  mv "$STATE/pids.next" "$STATE/pids"
fi
exit 0
EOF
  cat > "$bin/osascript" <<'EOF'
#!/bin/bash
echo "osascript $*" >> "$LOG"
exit 0
EOF
  cat > "$bin/open" <<'EOF'
#!/bin/bash
echo "open $*" >> "$LOG"
app=""
for arg in "$@"; do
  case "$arg" in
    -*) ;;
    *) app=$arg ;;
  esac
done
echo 4242 >> "$STATE/pids"
if [ "${OPEN_STALE:-}" = "1" ]; then
  printf '%s\n' "/Applications/SalaryCounter.app/Contents/MacOS/SalaryCounter" > "$STATE/args-4242"
else
  printf '%s\n' "$app/Contents/MacOS/SalaryCounter" > "$STATE/args-4242"
fi
exit 0
EOF
  chmod +x "$bin/pgrep" "$bin/ps" "$bin/kill" "$bin/osascript" "$bin/open"
}

write_build() {
  local dir=$1 code=$2
  cat > "$dir/build.sh" <<EOF
#!/bin/bash
echo build >> "\$LOG"
if [ "$code" -ne 0 ]; then
  exit $code
fi
mkdir -p "\$SALARYCOUNTER_ROOT/build/SalaryCounter.app/Contents/MacOS"
echo bin > "\$SALARYCOUNTER_ROOT/build/SalaryCounter.app/Contents/MacOS/SalaryCounter"
exit 0
EOF
}

run_update() {
  local dir=$1
  set +e
  SALARYCOUNTER_ROOT="$dir" \
    SALARYCOUNTER_WAIT_SLICE=0 \
    SALARYCOUNTER_WAIT_TRIES=2 \
    STATE="$STATE" \
    LOG="$LOG" \
    OPEN_STALE="${OPEN_STALE:-}" \
    PATH="$STUBS:$PATH" \
    bash "$REPO/scripts/update.sh" >"$OUT" 2>&1
  UPDATE_CODE=$?
  set -e
}

prepare_case() {
  CASE=$(mktemp -d)
  REPO_DIR="$CASE/repo"
  REMOTE="$CASE/remote"
  STATE="$CASE/state"
  LOG="$CASE/log"
  OUT="$CASE/out"
  STUBS="$CASE/stubs"
  mkdir -p "$STATE"
  : > "$LOG"
  make_repo "$REPO_DIR"
  track "$REPO_DIR" "$REMOTE"
  write_stubs "$STUBS"
  OPEN_STALE=""
}

# 未提交的改动要停，而且不能去编译或重启。
prepare_case
echo dirty >> "$REPO_DIR/README"
head_before=$(git -C "$REPO_DIR" rev-parse HEAD)
run_update "$REPO_DIR"
if [ "$UPDATE_CODE" -ne 0 ] && grep -q "未提交" "$OUT" && ! grep -q '^build$' "$LOG" && [ "$(git -C "$REPO_DIR" rev-parse HEAD)" = "$head_before" ]; then
  ok "dirty tree aborts before pull side effects and build"
else
  fail "dirty tree aborts before pull side effects and build"
  cat "$OUT" >&2 || true
fi

# 已暂存的改动同样停。
prepare_case
echo staged >> "$REPO_DIR/README"
git -C "$REPO_DIR" add README
run_update "$REPO_DIR"
if [ "$UPDATE_CODE" -ne 0 ] && grep -q "未提交" "$OUT"; then
  ok "staged change aborts"
else
  fail "staged change aborts"
fi

# 未跟踪、且没有被忽略的文件要停。
prepare_case
echo notes > "$REPO_DIR/notes.txt"
run_update "$REPO_DIR"
if [ "$UPDATE_CODE" -ne 0 ] && grep -q "未提交" "$OUT"; then
  ok "untracked file aborts"
else
  fail "untracked file aborts"
fi

# 游离 HEAD。
prepare_case
git -C "$REPO_DIR" checkout --detach >/dev/null 2>&1
run_update "$REPO_DIR"
if [ "$UPDATE_CODE" -ne 0 ] && grep -q "游离" "$OUT"; then
  ok "detached HEAD aborts"
else
  fail "detached HEAD aborts"
fi

# 没有上游。
prepare_case
git -C "$REPO_DIR" checkout -b feature >/dev/null 2>&1
run_update "$REPO_DIR"
if [ "$UPDATE_CODE" -ne 0 ] && grep -q "没有上游" "$OUT" && ! grep -q '^build$' "$LOG"; then
  ok "missing upstream aborts before build"
else
  fail "missing upstream aborts before build"
  cat "$OUT" >&2 || true
fi

# 分叉时即使配置了 pull.rebase，也不变基、不编译、不杀进程。
prepare_case
write_build "$REPO_DIR" 0
git -C "$REPO_DIR" add build.sh
git -C "$REPO_DIR" commit -m build >/dev/null
git -C "$REPO_DIR" push origin main >/dev/null
printf '45671\n' > "$STATE/pids"
echo "/Applications/SalaryCounter.app/Contents/MacOS/SalaryCounter" > "$STATE/args-45671"
git -C "$REPO_DIR" config pull.rebase true
echo local >> "$REPO_DIR/README"
git -C "$REPO_DIR" add README
git -C "$REPO_DIR" commit -m local >/dev/null
local_commit=$(git -C "$REPO_DIR" rev-parse HEAD)
clone_of "$REMOTE" "$CASE/other"
echo remote >> "$CASE/other/README"
git -C "$CASE/other" add README
git -C "$CASE/other" commit -m remote >/dev/null
git -C "$CASE/other" push origin main >/dev/null
run_update "$REPO_DIR"
if [ "$UPDATE_CODE" -ne 0 ] \
  && grep -q "拉取失败" "$OUT" \
  && ! grep -q '^build$' "$LOG" \
  && ! grep -q '^kill ' "$LOG" \
  && [ "$(git -C "$REPO_DIR" rev-parse HEAD)" = "$local_commit" ] \
  && [ ! -d "$REPO_DIR/.git/rebase-merge" ] \
  && [ ! -d "$REPO_DIR/.git/rebase-apply" ]; then
  ok "diverged branch stops without rebase, build, or quit"
else
  fail "diverged branch stops without rebase, build, or quit"
  cat "$OUT" >&2 || true
fi

# 编译失败时，原来的进程还在。
prepare_case
write_build "$REPO_DIR" 1
git -C "$REPO_DIR" add build.sh
git -C "$REPO_DIR" commit -m build >/dev/null
git -C "$REPO_DIR" push origin main >/dev/null
printf '45671\n' > "$STATE/pids"
echo "/Applications/SalaryCounter.app/Contents/MacOS/SalaryCounter" > "$STATE/args-45671"
run_update "$REPO_DIR"
if [ "$UPDATE_CODE" -ne 0 ] \
  && grep -q "编译失败" "$OUT" \
  && grep -q '^build$' "$LOG" \
  && ! grep -q '^kill ' "$LOG" \
  && ! grep -q '^open ' "$LOG" \
  && grep -qx '45671' "$STATE/pids"; then
  ok "failed build leaves the running app alone"
else
  fail "failed build leaves the running app alone"
  echo "code=$UPDATE_CODE" >&2
  cat "$OUT" >&2 || true
  cat "$LOG" >&2 || true
fi

# 忽略的 build/ 不算本地改动。功能分支只快进自己的上游，并打开本次编译的 .app。
prepare_case
write_build "$REPO_DIR" 0
printf 'build/\n' > "$REPO_DIR/.gitignore"
git -C "$REPO_DIR" add .gitignore build.sh
git -C "$REPO_DIR" commit -m ignore >/dev/null
git -C "$REPO_DIR" push origin main >/dev/null
git -C "$REPO_DIR" checkout -b feature >/dev/null 2>&1
echo feature-note > "$REPO_DIR/FEATURE"
git -C "$REPO_DIR" add FEATURE
git -C "$REPO_DIR" commit -m feature >/dev/null
git -C "$REPO_DIR" push -u origin feature >/dev/null
clone_of "$REMOTE" "$CASE/other"
git -C "$CASE/other" checkout feature >/dev/null 2>&1
echo more >> "$CASE/other/FEATURE"
git -C "$CASE/other" add FEATURE
git -C "$CASE/other" commit -m more >/dev/null
git -C "$CASE/other" push origin feature >/dev/null
expected=$(git -C "$CASE/other" rev-parse HEAD)
mkdir -p "$REPO_DIR/build"
echo artifact > "$REPO_DIR/build/leftover.o"
printf '45671\n45672\n' > "$STATE/pids"
echo "/Applications/SalaryCounter.app/Contents/MacOS/SalaryCounter" > "$STATE/args-45671"
echo "/usr/local/bin/SalaryCounter" > "$STATE/args-45672"
run_update "$REPO_DIR"
built_app="$REPO_DIR/build/SalaryCounter.app"
if [ "$UPDATE_CODE" -eq 0 ] \
  && [ "$(git -C "$REPO_DIR" branch --show-current)" = "feature" ] \
  && [ "$(git -C "$REPO_DIR" rev-parse HEAD)" = "$expected" ] \
  && grep -q "当前分支 feature" "$OUT" \
  && grep -q '^build$' "$LOG" \
  && grep -q 'kill -TERM 45671' "$LOG" \
  && ! grep -q 'kill .* 45672' "$LOG" \
  && grep -q "open -n $built_app" "$LOG" \
  && ! grep '^open ' "$LOG" | grep -q '/Applications/SalaryCounter.app' \
  && grep -qx '45672' "$STATE/pids" \
  && grep -qx '4242' "$STATE/pids" \
  && grep -q "$built_app/Contents/MacOS/SalaryCounter" "$STATE/args-4242"; then
  build_line=$(grep -n '^build$' "$LOG" | head -1 | cut -d: -f1)
  kill_line=$(grep -n 'kill -TERM 45671' "$LOG" | head -1 | cut -d: -f1)
  open_line=$(grep -n '^open ' "$LOG" | head -1 | cut -d: -f1)
  if [ "$build_line" -lt "$kill_line" ] && [ "$kill_line" -lt "$open_line" ]; then
    ok "feature branch fast-forwards, ignores build artifacts, then restarts the new app"
  else
    fail "build must happen before quit and relaunch"
    cat "$LOG" >&2
  fi
else
  fail "feature branch fast-forwards, ignores build artifacts, then restarts the new app"
  echo "code=$UPDATE_CODE branch=$(git -C "$REPO_DIR" branch --show-current) head=$(git -C "$REPO_DIR" rev-parse HEAD) expected=$expected" >&2
  cat "$OUT" >&2 || true
  cat "$LOG" >&2 || true
  echo "pids:" >&2
  cat "$STATE/pids" >&2 || true
fi

# 如果 open 实际拉起的是 /Applications 里的旧副本，不能把它当成更新成功。
prepare_case
write_build "$REPO_DIR" 0
git -C "$REPO_DIR" add build.sh
git -C "$REPO_DIR" commit -m build >/dev/null
git -C "$REPO_DIR" push origin main >/dev/null
OPEN_STALE=1
run_update "$REPO_DIR"
if [ "$UPDATE_CODE" -ne 0 ] \
  && grep -q "没有启动刚编译的" "$OUT" \
  && grep -q 'kill -TERM 4242' "$LOG"; then
  ok "stale /Applications launch is rejected"
else
  fail "stale /Applications launch is rejected"
  cat "$OUT" >&2 || true
  cat "$LOG" >&2 || true
fi

if [ "$failures" -eq 0 ]; then
  echo "make update checks passed"
else
  echo "$failures failed" >&2
  exit 1
fi
