# B站

> 最后验证：2026-09-27。标记：[实测] 本次跑过；[旧测] 引自 2026-09-24 调研；[源码] 只读了源码没跑；[UNKNOWN] 没查清。

| 需求 | 首选 | 备选 | 别用 |
|---|---|---|---|
| 搜视频 | bb `bilibili/search` [实测] | exa 通用搜索（query 里带"B站 / bilibili"）[旧测] | yt-dlp（HTTP 412）[旧测] |
| 元数据（标题、UP 主、播放/点赞/投币、分P cid） | bb `bilibili/video` [实测] | feedgrab（B站 API，只有元数据）[旧测] | yt-dlp（412）；anysearch `extract`（一堆没标签的数字）；exa fetch（对存在的视频也可能返回"视频不见了"错误页，不报错）[旧测] |
| 评论（热评 + 楼中楼前 3 条） | bb `bilibili/comments` [实测] | — | — |
| 字幕 / 文字稿（CC 字幕或 AI 字幕） | `scripts/bili_subtitle.sh` [实测] | 手写 eval，原理同脚本（见"坑"） | yt-dlp、feedgrab、exa、anysearch 都拿不到字幕 [旧测] |
| 没有字幕的视频转文字 | **目前做不到** | — | 见"坑"最后一条 |

## 命令

所有调用都在 Git Bash 里跑（Bash 工具），脚本自己开 tab、跑完关 tab，不用管别人的 tab。

```bash
S=C:/Users/18368/Desktop/00_myCode/43_search_master/scripts

# 搜索。位置参数：keyword page count order
#   count 默认 20、上限 50；order: totalrank(默认) | click | pubdate | dm | stow
bash $S/bb.sh bilibili/search "大模型 原理 讲解" 1 5 totalrank

# 元数据。位置参数：bvid
bash $S/bb.sh bilibili/video BV1nogs6qEZn

# 评论。位置参数：bvid page count sort
#   count 默认 20、上限 30；sort: 2=按点赞(默认) | 0=按时间
bash $S/bb.sh bilibili/comments BV1nogs6qEZn 1 5 2

# 字幕。参数：<BV号或视频URL> [语言偏好] [分P序号]
#   语言偏好逗号分隔，先精确再前缀匹配轨道 lan；默认 zh-CN,zh-Hans,zh,ai-zh,en（人工中文 > AI 中文 > 英文）
bash $S/bili_subtitle.sh BV1nogs6qEZn
bash $S/bili_subtitle.sh https://www.bilibili.com/video/BV1GJ411x7h7 en-US
bash $S/bili_subtitle.sh BV1xxxxxxxxx ai-zh 2          # 第 2 P
bash $S/bili_subtitle.sh BV1nogs6qEZn > "$TEMP/sub.txt" # 长视频先落文件再读
```

**千万别写** `--count 5`、`--sort 0` 这种命名参数：bb-browser 0.14.2 会把 `5` 塞进第 2 个位置（page）。要跳过中间参数就填它的默认值（如 `1 5 2`）。

## 返回什么

- `bilibili/search`：`{keyword, page, total, count, videos[{bvid, title, author, duration, play, danmaku, like, favorites, pub_date, url}]}`。单次最多 50 条，`total` 封顶 1000。adapter 约 1 秒 / 实际 4–5.5 秒。
- `bilibili/video`：`bvid, aid, title, description, cover, duration(秒), duration_text, author, author_mid, category, tags, pub_date, stat{view, like, dislike, coin, favorite, share, reply, danmaku}, pages[{page, cid, title, duration}], related[5], url`。adapter 约 0.5 秒 / 实际 [UNKNOWN]。
- `bilibili/comments`：`{total, count, sort, top_comments[], comments[{rpid, user, user_mid, user_level, content, like, reply_count, time, sub_replies[≤3]}]}`。每页最多 30 条，翻页用 page。adapter 约 0.4 秒 / 实际 [UNKNOWN]。
- `bili_subtitle.sh`：
  - 成功（exit 0）：stdout 每行 `[起始秒] 文本`，如 `[3.1] 到底是如何理解我们的提示词`；stderr 一行 meta：`[bili_subtitle] {bvid, cid, title, duration, lan, lan_doc, tracks[], lines, last_to, ms}`。`tracks` 列出全部可用轨，想换语言就用第 2 个参数重跑。
  - 失败（exit 1）：stdout 一行 JSON。没有字幕轨：`{"error":"no subtitle tracks", bvid, cid, title, player_code, need_login_subtitle, logged_in}` [实测]；网络/HTTP 错误：`{"error":"<原因> @ <接口>"}`；视频不存在：`{"error":"view code -404: ..."}`。
  - 参数错 exit 2。开不了 tab 时 stdout 是 bb.sh 的错误 JSON，exit 1。
  - 实际耗时 3–5 秒（含开关 tab）。25 分钟视频 758 行、32KB。

## 坑

- 搜索结果混有课程广告项（2026-09-26、09-27 每次 1 条）：`bvid` 为空、`url` 只有 `https://www.bilibili.com/video/`，用之前过滤掉 [实测]。
- 搜索的 `duration` 不补零：`"48:2"` 是 48 分 2 秒 [实测]。
- `bilibili/video` 的 `category` 为空、`tags` 为 null，要分区/标签得自己 eval [实测]。
- `bilibili/*` adapter 都不返回字幕、弹幕、转写；字幕只能走 `bili_subtitle.sh` [实测]。
- 手写 eval 取字幕时：`api.bilibili.com` 要带 cookie（`credentials:'include'`），字幕 CDN（`*.hdslb.com`）**不能带**，带了直接 `Failed to fetch`（CORS）。本次第一版脚本就栽在这里 [实测]。
- `subtitle_url` 以 `//` 开头要补 `https:`；查询参数（`auth_key`）不能截掉 [实测][旧测]。
- 脚本通过 `bb.sh eval` 执行，bb.sh 会等页面真正落在 http 页面后才 eval（`about:blank` 的 readyState 也是 complete，只看它会跨域失败）[实测]。手写 eval 时也要用 `bb.sh eval`，别自己开 tab。
- 字幕轨可能依赖登录：bb 的 Chrome 里 B站看起来已登录，同一视频拿到 12 条轨；feedgrab 不带 cookie 报 `no subtitles available` [旧测]。未登录能否拿到轨 [UNKNOWN]。
- 串台还在：脚本用的是不带签名的 `x/player/wbi/v2`。用 bb eval 诊断 BV1BFouBYERu：`x/player/wbi/v2` 7/7 次 0 条轨；不带 wbi 的 `x/player/v2` 7 次里 2 次返回 ai-zh 轨，内容却是别的视频（讲 iPhone 16，字幕结束于 1686 秒，视频只有 600 秒）[实测]。**不要给脚本加 v2 兜底**，否则"没有字幕"会变成"错误的字幕"。脚本在字幕结束时间比视频时长多 10 秒以上时在 meta 里加 `warning`，正好抓这种情况。带 wbi 签名（`w_rid` / `wts`）能不能拿到字幕轨 [UNKNOWN]。
- 多 P 视频默认只取第 1 P，其他 P 用第 3 个参数 [源码]。
- "没有字幕轨"分支会触发：BV1BFouBYERu、BV1T9DXBRECC 返回 `{"error":"no subtitle tracks"}`，`logged_in: true`、`need_login_subtitle: false`，BV1BFouBYERu 重跑 3 次一样 [实测]。但这不等于视频真没字幕：上一条说了，带签名的请求能不能拿到 [UNKNOWN]。
- AI 字幕会把英文专有名词识别成同音词：视频里的 "Claude" 全写成了 "cloud" [实测]。按专有名词 grep 字幕会漏，要连同音误识别词一起搜。
- eval 返回值有没有大小上限 [UNKNOWN]；32KB 正常。几小时的长视频建议先落文件。
- exa fetch 对 BV1GJ411x7h7 返回过"视频不见了"错误页，不报错 [旧测]；而本次 bb 和字幕脚本都能正常拿到这个视频，说明那是 exa 的问题（缓存？[UNKNOWN]），不是视频下架。拿到结果先看内容。
- 没有 CC/AI 字幕的视频只能从音频转写：本机没有 Whisper（openai-whisper / faster-whisper 都没装），也没有 `GROQ_API_KEY`，现在转不了。要转需要二选一：装本地 Whisper，或设 `GROQ_API_KEY`（Groq 云端 whisper-large-v3-turbo，feedgrab 会用）[旧测]。另外按 skill 规则不下载音视频文件。

## 本次验证

- 2026-09-26：
  - `bb.sh bilibili/search "大模型 原理 讲解" 1 5 totalrank` → 5 条（其中 1 条广告项 bvid 为空），adapter 0.99 秒 / 实际 4.0 秒；确认 count 在第 3 位。
  - `bb.sh bilibili/video BV1nogs6qEZn` → 完整元数据 + 1 个 cid + 5 条相关视频，adapter 0.50 秒。
  - `bb.sh bilibili/comments BV1nogs6qEZn 1 5 2` → count=5、total=223，1 条置顶 + 热评带楼中楼，adapter 0.43 秒。
  - `bili_subtitle.sh BV1GJ411x7h7`（第一版）→ `Failed to fetch`；定位为字幕 CDN 带 cookie 的 CORS 失败，改成不带 cookie 后重跑 → 12 条轨，选中 zh-CN，47 行，实际 2.8 秒。
  - `bili_subtitle.sh BV1nogs6qEZn` → 只有 ai-zh 一条轨，758 行、32KB、last_to 1514s（时长 1515s），实际 2.9 秒。
  - `bili_subtitle.sh BV17Xhq6nEya`（110 播放的新视频）→ ai-zh，214 行。
  - `bili_subtitle.sh not-a-bv` → 用法 JSON，exit 2。
- 2026-09-27（冒烟测试）：
  - `bilibili/search` 两次 → 每次混 1 条广告项；adapter 0.94 秒 / 实际 5.5 秒，另一次 adapter 0.91 秒 / 实际 [UNKNOWN]。
  - `bili_subtitle.sh` 每次实际约 5 秒：BV1NvRyBzEhq 6 条轨选中 ai-zh，1341 行；BV1wqeb6gEDY 508 行；回归 BV1nogs6qEZn 758 行、BV1GJ411x7h7 12 条轨，照样成功。
  - BV1BFouBYERu、BV1T9DXBRECC → `no subtitle tracks`（`logged_in: true`，`need_login_subtitle: false`），BV1BFouBYERu 重跑 3 次一样；bb eval 诊断结果见"坑"的串台一条。
