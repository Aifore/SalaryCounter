#!/usr/bin/env bash
# 快进当前分支、编译，再重启本地 build 出来的 SalaryCounter。
# 不切换分支，不合并，不变基，不暂存，不提交，不推送。
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=${SALARYCOUNTER_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}

die() {
  echo "make update: $*" >&2
  exit 1
}

cd "$ROOT"
export GIT_TERMINAL_PROMPT=0

branch=$(git rev-parse --abbrev-ref HEAD)
if [ "$branch" = "HEAD" ]; then
  die "当前是游离 HEAD，没有可快进的分支。请先切回 main，或切回你正在测试的功能分支。"
fi

changes=$(git status --porcelain)
if [ -n "$changes" ]; then
  echo "make update: 分支 ${branch} 有未提交的本地改动，已停止。" >&2
  echo "不会覆盖、暂存、提交或切换分支。被 git 忽略的生成文件（例如 build/）不算改动。" >&2
  echo "请先处理这些文件后再运行 make update：" >&2
  printf '%s\n' "$changes" >&2
  exit 1
fi

if ! upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null); then
  die "分支 ${branch} 没有上游。可以先执行：git branch -u origin/${branch}"
fi

# macOS 自带 Bash 3.2 在 UTF-8 下会把 $name 后面的中文或全角标点首字节算进变量名。
# 紧挨这些字符时必须写成 ${name}，否则 set -u 会报 branch<0xEF>: unbound variable。
echo "make update: 快进当前分支 ${branch}（上游 ${upstream}）"
if ! git pull --no-rebase --ff-only; then
  die "拉取失败。分支可能已经和上游分叉，或上游暂时不可达。没有合并或变基，也没有重启应用。"
fi

now=$(git rev-parse --abbrev-ref HEAD)
if [ "$now" != "$branch" ]; then
  die "拉取之后当前分支从 ${branch} 变成了 ${now}。已停止，没有重启应用。"
fi

echo "make update: 编译 ${branch}"
if ! bash "$ROOT/build.sh"; then
  die "编译失败。正在运行的 SalaryCounter 没有退出。"
fi

app="$ROOT/build/SalaryCounter.app"
if [ ! -d "$app" ]; then
  die "编译结束了，但没有找到 ${app}。正在运行的程序没有退出。"
fi

echo "make update: 重启 $app"
bash "$SCRIPT_DIR/restart-app.sh" "$app"
