#!/usr/bin/env bash
# B站字幕 -> 纯文本。走 bb-browser 自己的 Chrome（B站看起来已登录；未登录能否拿到字幕轨 [UNKNOWN]），开自己的 tab，跑完关掉。
# 用法（Git Bash）：
#   bash bili_subtitle.sh <BV号或视频URL> [语言偏好] [分P序号]
#   bash bili_subtitle.sh BV1GJ411x7h7
#   bash bili_subtitle.sh https://www.bilibili.com/video/BV1GJ411x7h7 en
#   bash bili_subtitle.sh BV1xxxxxxxxx ai-zh,zh 2
# 语言偏好：逗号分隔，按顺序匹配轨道 lan（先精确匹配，再前缀匹配），都不中就取第一条轨。
#   默认 zh-CN,zh-Hans,zh,ai-zh,en（人工中文 > AI 中文 > 英文）。
# 输出：
#   成功：stdout 每行 "[起始秒] 文本"；stderr 一行 meta（标题、cid、选中轨、全部轨、行数、耗时）。exit 0
#   失败：stdout 一行 JSON {"error": ...}，exit 1。没有字幕轨时 error="no subtitle tracks"。
#   参数错 exit 2；开 tab 失败也走 exit 1（bb.sh 的错误 JSON 原样输出）。
# 原理：在 B站 tab 里 fetch（同站，带 cookie）x/web-interface/view 拿 cid -> x/player/wbi/v2 拿 subtitle.subtitles[] -> 取完整 subtitle_url。
# 注意：视频没有 CC/AI 字幕就没有文字；本机没有 Whisper / GROQ_API_KEY，无法从音频转写。
set -u

bvid=$(printf '%s' "${1:-}" | grep -o -m1 'BV[0-9A-Za-z]\{10\}' | head -1)
prefs="${2:-zh-CN,zh-Hans,zh,ai-zh,en}"
page="${3:-1}"
[ -n "$bvid" ] || { echo '{"error":"usage: bili_subtitle.sh <BV号或URL> [语言偏好] [分P]"}'; exit 2; }
printf '%s' "$prefs" | grep -q '^[A-Za-z0-9,_-]*$' || { echo '{"error":"bad lang pref"}'; exit 2; }
printf '%s' "$page" | grep -q '^[1-9][0-9]*$' || { echo '{"error":"bad page number"}'; exit 2; }

read -r -d '' JS <<'EOF'
(async () => {
  const bvid = '__BVID__', prefs = '__PREFS__'.split(',').filter(Boolean), p = __PAGE__;
  const t0 = Date.now();
  // api.bilibili.com 要带 cookie；字幕 CDN（hdslb）不能带：实测带了就 Failed to fetch（CORS），不带就成功
  const get = async (u, cred) => {
    let r;
    try { r = await fetch(u, {credentials: cred}); }
    catch (e) { throw new Error(e.message + ' @ ' + u.split('?')[0]); }
    if (!r.ok) throw new Error('HTTP ' + r.status + ' @ ' + u.split('?')[0]);
    return r.json();
  };
  try {
    const view = await get('https://api.bilibili.com/x/web-interface/view?bvid=' + bvid, 'include');
    if (view.code !== 0) return JSON.stringify({error: 'view code ' + view.code + ': ' + view.message, bvid});
    const pg = (view.data.pages || [])[p - 1];
    if (!pg) return JSON.stringify({error: 'page ' + p + ' not found', bvid, pages: (view.data.pages || []).length});
    const pl = await get('https://api.bilibili.com/x/player/wbi/v2?bvid=' + bvid + '&cid=' + pg.cid, 'include');
    const d = pl.data || {};
    const subs = (d.subtitle && d.subtitle.subtitles) || [];
    if (!subs.length) return JSON.stringify({error: 'no subtitle tracks', bvid, cid: pg.cid, title: view.data.title,
      player_code: pl.code, need_login_subtitle: !!d.need_login_subtitle, logged_in: !!d.login_mid});
    let pick = null;
    for (const pr of prefs) {
      pick = subs.find(s => s.lan === pr) || subs.find(s => s.lan.startsWith(pr));
      if (pick) break;
    }
    pick = pick || subs[0];
    let url = pick.subtitle_url || '';
    if (url.startsWith('//')) url = 'https:' + url;
    if (!url) return JSON.stringify({error: 'empty subtitle_url', bvid, lan: pick.lan});
    const body = (await get(url, 'omit')).body || [];
    const lastTo = body.length ? body[body.length - 1].to : 0;
    const meta = {bvid, cid: pg.cid, title: view.data.title, duration: pg.duration, lan: pick.lan, lan_doc: pick.lan_doc,
      tracks: subs.map(s => s.lan), lines: body.length, last_to: lastTo, ms: Date.now() - t0};
    if (lastTo > pg.duration + 10) meta.warning = 'subtitle ends after video end: may belong to another video';
    return '#META ' + JSON.stringify(meta) + '\n' + body.map(x => '[' + x.from.toFixed(1) + '] ' + x.content).join('\n');
  } catch (e) {
    return JSON.stringify({error: String((e && e.message) || e), bvid});
  }
})()
EOF
JS=${JS//__BVID__/$bvid}
JS=${JS//__PREFS__/$prefs}
JS=${JS//__PAGE__/$page}

# 开 tab、等页面落在 bilibili.com、排队锁、关 tab 都交给 bb.sh
here=$(cd "$(dirname "$0")" && pwd)
out=$(bash "$here/bb.sh" eval "https://www.bilibili.com/video/$bvid" "$JS")
case "$out" in
  '#META '*)
    printf '%s\n' "$out" | head -1 | sed 's/^#META /[bili_subtitle] /' >&2
    printf '%s\n' "$out" | tail -n +2
    ;;
  '{'*)
    printf '%s\n' "$out"
    exit 1
    ;;
  *)
    printf '%s\n' "$out" >&2
    echo '{"error":"bb-browser eval failed, see stderr"}'
    exit 1
    ;;
esac
