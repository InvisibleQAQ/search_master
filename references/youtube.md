# YouTube

> 最后验证：2026-09-27。标记：[实测] 最后一次验证时跑过；[旧测] 引自 2026-09-24 调研；[源码] 只读了源码没跑；[UNKNOWN] 没查清。时间都是美东（EDT，-04:00）。

| 需求 | 首选 | 备选 | 别用 |
|---|---|---|---|
| 搜视频 | bb `youtube/search`（tab 开在 watch 页）[实测] | exa 通用搜索 [旧测] | — |
| 元数据 | bb `youtube/video`（私有 adapter，见"坑"第一条）[实测] | yt-dlp `--dump-json`（最全，但 78s）[旧测]；exa fetch（只有标题 + 频道）[实测] | anysearch `extract`（有乱码）；feedgrab（缺标题和作者）[旧测] |
| 有没有字幕、有哪些语言 | yt-dlp `--list-subs`（19–53s）[实测] | bb `youtube/video` 的 `captionLanguages` [实测] | — |
| 评论 | bb `youtube/comments` [实测] | — | — |
| 字幕，要时间轴或要保证完整 | yt-dlp 取一种语言的字幕（8–40s）[实测] | feedgrab（内部调 yt-dlp，64s，缺标题）[旧测] | bb `youtube/transcript`（失败）[旧测] |
| 字幕，只要快速读个大意 | exa `web_fetch_exa`（纯文本，无时间轴）[实测] | — | — |
| 中文翻译字幕（zh-Hans 自动翻译轨） | [UNKNOWN]：2026-09-26 yt-dlp 取 zh-Hans 报 HTTP 429 | 先取原文字幕，自己翻译 | — |
| 没有字幕的视频转文字 | **目前做不到**（见"坑"最后一条） | — | — |

## 命令

```bash
S=C:/Users/18368/Desktop/00_myCode/43_search_master/scripts
V="https://www.youtube.com/watch?v=zjkBMFhNj_g"   # 目标视频；搜索时随便填一个能打开的 watch 页

# 关键：BB_OPEN_URL 指向 watch 页 + BB_SETTLE=8。用 bb.sh 默认开的首页，2026-09-26 search 3 次全失败
# 搜索。位置参数：query max（默认 20，上限 50）
BB_OPEN_URL="$V" BB_SETTLE=8 bash $S/bb.sh youtube/search "Karpathy intro to large language models" 5
# 元数据。位置参数：id。私有 adapter 不依赖页面里的数据，tab 开首页也能拿全（实测 1 次），统一起见还是开 watch 页
BB_OPEN_URL="$V" BB_SETTLE=8 bash $S/bb.sh youtube/video zjkBMFhNj_g
# 评论。位置参数：id max（默认 20）
BB_OPEN_URL="$V" BB_SETTLE=8 bash $S/bb.sh youtube/comments zjkBMFhNj_g 5

# yt-dlp：永远加 --ignore-config --skip-download，永远不加 --cookies-from-browser
# 列字幕轨（19–53s；慢是因为读超时 20s 后重试）
yt-dlp --ignore-config --skip-download --list-subs "$V"
# 取字幕：一次只取一种语言，优先原始语言（en / en-orig）
yt-dlp --ignore-config --skip-download --write-subs --write-auto-subs --sub-langs "en" \
  --sub-format vtt -o "$TEMP/yt/%(id)s.%(ext)s" "$V"
# 要时间轴：直接读 VTT 的 cue 行（"00:00:02.280 --> ..."），或改 --sub-format json3 [UNKNOWN 没跑]
# 自动字幕 VTT 每句重复 2-3 次、带逐词时间标签，清洗成纯文本（丢掉时间轴）：
awk '/-->/{next} /^(WEBVTT|Kind:|Language:)/{next} {gsub(/<[^>]*>/,""); gsub(/^[ \t]+|[ \t]+$/,"")} $0!="" && $0!=prev {print; prev=$0}' \
  "$TEMP/yt/zjkBMFhNj_g.en.vtt"
# 用完删掉 $TEMP/yt
# 确认断网、只想快速探测时加 --extractor-retries 0（见"坑"）；网络只是慢时别加
```

exa：先 `ToolSearch select:mcp__exa__web_fetch_exa`，再调
`web_fetch_exa({urls: ["https://www.youtube.com/watch?v=<id>"], maxCharacters: 20000})`。可以一次传多个 URL。

判断有没有字幕：最可靠的是 `yt-dlp --ignore-config --skip-download --list-subs <url>`，输出分两段："Available automatic captions"（自动字幕）和"Available subtitles"（人工字幕；没有时写"<id> has no subtitles"）。快速看一眼可以用 `youtube/video` 的 `captionLanguages`：`name` 带"(自动生成)"的是自动字幕（界面语言是中文时的写法）；结果里没有这个字段，说明 adapter 退到了简版分支（见"返回什么"）。

## 返回什么

- `youtube/search`：`{query, resultCount, videos[{videoId, title, channel, channelId, views, duration, publishedTime, description, url}]}`。`views` 是"4,136,925次观看"这种本地化字符串，`publishedTime` 是"2年前"，`description` 截断。adapter 4.8–6.7s / 实际 52s（2026-09-27 那次）。
- `youtube/video`（私有 adapter，19 个字段）：`videoId, title, channel, channelId, channelUrl, subscriberCount("170万位订阅者"), description(截到 1000 字), duration(秒), durationFormatted, viewCount(数字), viewCountFormatted, likes("10万"), publishDate, category, isLive, keywords(最多 20 个；视频没打标签就是空数组), captionLanguages[{lang, name}], url, _commentContinuationToken`。
  - `publishDate` 是 ISO，带 YouTube 给的太平洋时区偏移（`2026-02-26T18:04:10-08:00`），写进结论前换成美东。
  - 耗时：页面自带这个视频的数据时 adapter 0.3–0.4s；要重拉 watch 页 HTML 时 1.8–6.4s；实际 24–41s。
  - **没有 `duration` 字段 = 退到了 `/youtubei/v1/next` 简版分支**：只有 9 个字段（没有 duration、viewCount、captionLanguages、description、keywords），`publishDate` 是"2026年2月26日"这种显示文字。私有版只在 watch 页 HTML 也解析不出时才走它（反爬页、HTML 改版）。遇到就重跑一次，还不行用 yt-dlp `--dump-json`。
- `youtube/comments`：`{videoId, commentCountText, fetchedCount, comments[{rank, author, authorChannelId, text, publishedTime, likes, replyCount, isPinned}]}`。不含楼中楼内容。5 条 6.3s（adapter）。
- yt-dlp 字幕：59 分钟视频的 en 自动字幕 VTT 603KB / 13,632 行，清洗后 1,704 行 / 64KB。`--list-subs` 列出自动字幕约 157 种语言（含 zh-Hans、en-orig）。
- exa `web_fetch_exa`：标题 + `Author`（频道）+ 转录纯文本；没有时间戳、播放量、发布日期。

## 坑

- **打开 watch 页，拿到的有时是 YouTube 的 app shell**：YouTube 的 service worker（`sw.js` → `serviceworker-kevlar-appshell.js`）会用 Cache Storage `yt-appshell-assets` 里缓存的 `/app_shell_home`（首页骨架）应答 watch 页的导航请求。这时页面里没有 `ytInitialPlayerResponse`，`ytInitialData` 只有 `responseContext`，`ytPageType` 是 "browse"。社区版 `youtube/video` 要求这两个变量都在，不在就悄悄退到 `/next` 分支，只给 9 个字段 [实测]。私有 adapter `adapters/youtube/video.js` 的修法：页面变量不是这个视频的（缺失、SPA 跳转后是旧视频、tab 开的是别的页），就在页面里 `fetch('/watch?v=<id>')` 重拉 HTML，解析出这两个变量；fetch 不是导航请求，SW 不会换成 shell [实测]。SW 源码里，实验开关 `kevlar_sw_app_wide_fallback` 打开时，`/watch` 的导航先走网络，网络出错或返回 4xx（429 除外）/ 5xx 才给 shell [源码]；为什么 2026-09-27 07:00–07:10 连续 3 次都拿到 shell、07:12 以后又都是完整页 [UNKNOWN]。
- 私有版 6 次里 1 次报 `Daemon request timed out`（adapter 30.30s，bb daemon 的 30s 上限），重跑就好 [实测]。卡在重拉 HTML（2.5MB，网络慢时要 10s）还是别处 [UNKNOWN]。
- bb.sh 默认开 `youtube.com` 首页：2026-09-26 search 3 次全失败（2 次 `YouTube config not found`，1 次等 26s 后 `Failed to fetch`）。改成 `BB_OPEN_URL=<watch 页> BB_SETTLE=8` 后 search / video / comments 都成功 [实测]。2026-09-27 05:28–05:43 断网时开 watch 页也不行：`youtube/search` 两次约 27s 报 `TypeError: Failed to fetch`，同时 curl youtube 超时，所以 `Failed to fetch` 更像网络问题，不是首页加载慢 [实测]。`YouTube config not found` 的根因 [UNKNOWN]：缓存的 app shell 不满 7 天时，首页 `/` 的导航由 SW 直接用它应答 [源码]，可能有关，没验证。
- 本机访问 YouTube 慢：curl 首页 11s；yt-dlp 每次请求读超时 20s 后自动重试；页面里 fetch 一个 watch 页 HTML 1.2–10s [实测]。
- yt-dlp 的 `--retries` 限不住网页和 API 请求的重试：那归 `--extractor-retries` 管（默认 3，日志 "Retrying (1/3)" 到 "(3/3)"），每个请求读超时 20s，断网时白等好几分钟。用 `--proxy http://127.0.0.1:9` 模拟断网：只加 `--retries 1` 17.9s 才失败，再加 `--extractor-retries 0` 5.6s [实测]。但网络只是慢时正是这个重试在救场（2026-09-27 `--list-subs` 两次读超时后第 3 次成功，53s），所以只在确认断网时加。
- yt-dlp 一次取多种语言：`--sub-langs "zh-Hans,en"` 时 zh-Hans（自动翻译轨）返回 HTTP 429，yt-dlp 直接退出（rc=1），en 也没写出来，白等 63s。只取一种语言，改成 `en` 后 39s 成功 [实测 2026-09-26]。
- yt-dlp 2025.12.08 已超过 90 天，每次有两条警告："older than 90 days"和 SABR（"YouTube is forcing SABR streaming for this client"），不影响列字幕、取字幕 [实测]。
- 一律加 `--ignore-config`，防止配置文件里藏着 `--cookies-from-browser`。feedgrab 默认会让 yt-dlp 读日常 Chrome 的 cookie（`YTDLP_COOKIES_BROWSER` 默认 chrome），用 feedgrab 抓 YouTube 必须设 `YTDLP_COOKIES_BROWSER=' '` [旧测]。
- bb 返回的数字多是中文本地化字符串（"10万"、"2年前"）；要数值用 `youtube/video` 的 `viewCount` 或 yt-dlp [实测]。
- `youtube/transcript` 失败：它靠 DOM 里的字幕面板，而 bb 的 Chrome 里 tab 都是 hidden，面板渲染不出；timedtext 接口 200 但 0 字节（疑似要 PO token）[旧测]。没重测，别用。
- exa fetch 对长视频的转录是否完整 [UNKNOWN]（2026-09-26 只要了 4000 字符）。要全文或时间轴用 yt-dlp。
- 2026-09-26 后段 exa / anysearch 的搜索请求都报 `fetch failed`（本机网络），exa fetch 在前段成功过。遇到就换工具，别死等。
- 没有字幕的视频只能从音频转写：本机没有 Whisper，也没有 `GROQ_API_KEY`，现在转不了。要转需要装本地 Whisper，或设 `GROQ_API_KEY`（Groq 云端 Whisper，feedgrab 支持）[旧测]。不要为此下载音视频文件。

## 本次验证

### 2026-09-27

- 冒烟测试 05:28–05:43 断网：`BB_OPEN_URL=<watch 页> BB_SETTLE=8 bb.sh youtube/search ...` 两次约 27s 报 `TypeError: Failed to fetch`；同时 curl youtube 超时。
- 冒烟测试 05:44，网络恢复后同一命令 → 成功，adapter 6.74s / 实际 52s。
- 冒烟测试 05:45，`youtube/video zKBPwDpBfhs`（社区版）→ rc=0，但只有 9 个字段，`publishDate` "2026年2月26日"，adapter 7.45s / 实际 43s。
- 冒烟测试：`yt-dlp --list-subs` 19s；取 en 自动字幕 7.9s。
- 诊断 07:00–07:10，`bb.sh eval <zKBPwDpBfhs 的 watch 页>` 3 次都拿到 app shell：URL 没被重定向，`typeof ytInitialPlayerResponse` 是 undefined，`ytInitialData` 只有 `responseContext`（678 字符），`ytPageType` "browse"、`ytUrl` "/"。两次导航的 `clickTrackingParams` 完全相同，和 Cache Storage 里 `/app_shell_home`（缓存于 2026-09-26 13:37）一致。同一页面里 `fetch(location.href)` 拿到完整 watch 页（`ytPageType` "watch"，有 `ytInitialPlayerResponse` 和 `captionTracks`）。07:12–07:35 的 5 次 eval 和 3 次 adapter（0.3s，走的页面数据）都是完整页。
- 私有 adapter，全部 `BB_SETTLE=8`，字段都是 19 个，`publishDate` 都是 ISO：
  - zKBPwDpBfhs，开自己的 watch 页：captionLanguages 只有 en 自动字幕，keywords 空（视频本身没标签，播放器数据里也是空）；adapter 0.31s / 实际 36s，再跑 0.32s / 24s。第 1 次 `Daemon request timed out`，adapter 30.30s / 实际 65s。
  - dQw4w9WgXcQ，开自己的 watch 页：keywords 20 个，captionLanguages 6 条（5 条人工 + en 自动）；adapter 0.39s / 实际 35s。
  - dQw4w9WgXcQ，tab 开 zKBPwDpBfhs 的 watch 页（强制走重拉 HTML）：adapter 1.80s / 实际 38s。
  - zjkBMFhNj_g，不设 `BB_OPEN_URL`（首页，app shell）：adapter 6.36s / 实际 41s。
  - `bb-browser site list --json`：`youtube/video` 的 `source` 是 `local`。
- `yt-dlp --list-subs zKBPwDpBfhs` → rc=0，53s（两次读超时后第 3 次成功）；自动字幕有 en、en-orig 等，"has no subtitles"（没有人工字幕）。
- `--proxy http://127.0.0.1:9` 模拟断网：`--retries 1` → 17.9s 失败（网页、API 各重试 3 次）；`--retries 1 --extractor-retries 0` → 5.6s 失败，不重试。

### 2026-09-26

- `bb.sh youtube/search "Karpathy intro to large language models" 5`（默认首页）→ `YouTube config not found`；重试 BB_SETTLE=6 → 26s 后 `Failed to fetch`；再试 BB_SETTLE=4 → `YouTube config not found`。
- 同上，改 `BB_OPEN_URL=<watch 页> BB_SETTLE=8` → 5 条，4.79s（adapter），第一条就是目标视频。
- `youtube/video zjkBMFhNj_g`（watch 页，社区版）→ 完整元数据，`captionLanguages` 只有 en 自动字幕，0.34s（adapter）。
- `youtube/comments zjkBMFhNj_g 5`（watch 页）→ 5 条，总数"5,067 条评论"，6.29s（adapter）。
- `yt-dlp --list-subs` → rc=0，4s，自动字幕约 157 种。
- `yt-dlp --sub-langs "zh-Hans,en" ...` → rc=1，63s，zh-Hans HTTP 429，无文件。
- `yt-dlp --sub-langs "en" ...` → rc=0，39s（1 次读超时重试），603KB VTT。
- exa `web_fetch_exa` 同一视频 → 标题 + 频道 + 转录纯文本（和 yt-dlp 内容一致），无时间戳。
