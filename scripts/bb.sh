#!/usr/bin/env bash
# bb-browser 安全调用：开自己的 tab -> 等页面加载 -> 跑 adapter 或 JS -> 关 tab。
# 必须在 Git Bash 里跑（PowerShell 会吞掉空字符串参数）。
#
# 两种用法：
#   bash bb.sh <platform/command> [位置参数...]     跑 site adapter
#   bash bb.sh eval <url> '<js>'                    打开 url，在页面里执行 JS，打印返回值
#
# 环境变量：
#   BB_OPEN_URL   adapter 模式下改用这个地址开 tab（默认 https://<adapter 的 domain>/）
#                 例：BB_OPEN_URL=https://www.xiaohongshu.com/explore
#   BB_SETTLE     页面加载完后再等几秒（默认 2）。小红书、X、Linux.do 这类 SPA 要等前端
#                 hydrate，否则 adapter 会误报 Not logged in 或 execution context 错误；用 6。
#   BB_LOCK_WAIT  排队最多等几秒（默认 180）。
#
# adapter 参数只能按 @meta 里的顺序写成位置参数（0.14.2 的 --name 参数会错位）；
# 要跳过中间某个参数，填它的默认值。
# 输出：stdout 是 adapter 的 JSON（{"result": ...} 或 {"error": ...}）或 eval 的返回值；
#       stderr 是 tab id 和耗时。写操作 adapter（readOnly=false）一律拒绝。
#
# 串行：多个 bb.sh 同时跑时会集中报 "Cannot find default execution context"，每次白等约
# 27 秒（2026-09-26 多个 agent 并发时出现，根因未确认）。所以这里用全局锁，同一时间只跑
# 一个 bb.sh，其余排队。
set -u

lock="${TMPDIR:-/tmp}/bb-sh.lock"
tab=""

cleanup() {
  [ -n "$tab" ] && bb-browser close --tab "$tab" >/dev/null 2>&1
  rmdir "$lock" 2>/dev/null
}

acquire_lock() {
  local waited=0
  until mkdir "$lock" 2>/dev/null; do
    # 持锁进程被强杀时锁会残留：超过 5 分钟没变化就当残留锁清掉
    if [ -n "$(find "$lock" -maxdepth 0 -mmin +5 2>/dev/null)" ]; then
      rmdir "$lock" 2>/dev/null; continue
    fi
    if [ "$waited" -ge "${BB_LOCK_WAIT:-180}" ]; then
      echo "{\"error\":\"bb.sh lock busy for ${waited}s\"}"; exit 5
    fi
    sleep 1; waited=$((waited + 1))
  done
  trap cleanup EXIT
}

open_tab() {  # $1=url；设置全局变量 tab。调用前必须已经拿到锁
  tab=$(bb-browser open "$1" 2>&1 | sed -n 's/^tab: *//p' | head -1)
  [ -n "$tab" ] || { echo "{\"error\":\"could not open tab for $1\"}"; exit 4; }
  for _ in $(seq 1 20); do
    # 新 tab 跳转前是 about:blank，它的 readyState 也是 complete，所以还要确认已经落在 http 页面
    [ "$(bb-browser eval "location.protocol.startsWith('http') && document.readyState==='complete'" --tab "$tab" 2>/dev/null | tail -1)" = "true" ] && break
    sleep 1
  done
  sleep "${BB_SETTLE:-2}"
}

timed() {  # $1=标签，其余参数是要执行的命令
  local label="$1"; shift
  local t0 t1 rc
  t0=$(date +%s%N); "$@"; rc=$?; t1=$(date +%s%N)
  echo "[bb.sh] $label tab=$tab rc=$rc $(awk "BEGIN{printf \"%.2f\", ($t1-$t0)/1e9}")s" >&2
  return $rc
}

mode="${1:?用法: bash bb.sh <platform/command> [args...]  或  bash bb.sh eval <url> '<js>'}"; shift

if [ "$mode" = "eval" ]; then
  url="${1:?缺少 url}"; js="${2:?缺少 js}"
  acquire_lock
  open_tab "$url"
  timed "eval" bb-browser eval "$js" --tab "$tab"
  exit $?
fi

adapter="$mode"
meta_file=""
for dir in "$HOME/.bb-browser/sites" "$HOME/.bb-browser/bb-sites"; do
  [ -f "$dir/$adapter.js" ] && { meta_file="$dir/$adapter.js"; break; }
done
[ -n "$meta_file" ] || { echo "{\"error\":\"adapter not found: $adapter\"}"; exit 2; }

if grep -q '"readOnly": *false' "$meta_file"; then
  echo "{\"error\":\"refused: $adapter is a write adapter (readOnly=false)\"}"; exit 3
fi

domain=$(grep -m1 -o '"domain": *"[^"]*"' "$meta_file" | sed 's/.*"\([^"]*\)"$/\1/')
acquire_lock
open_tab "${BB_OPEN_URL:-https://$domain/}"
timed "$adapter" bb-browser site "$adapter" "$@" --tab "$tab" --json
