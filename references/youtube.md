# YouTube

> 最后验证：2026-09-26。标记：[实测] 本次跑过；[旧测] 引自 2026-09-24 调研；[源码] 只读了源码没跑；[UNKNOWN] 没查清。

| 需求 | 首选 | 备选 | 别用 |
|---|---|---|---|
| 搜视频 | bb `youtube/search`（tab 开在 watch 页）[实测] | exa 通用搜索 [旧测] | — |
| 元数据 | bb `youtube/video` [实测] | yt-dlp `--dump-json`（最全，但 78s）[旧测]；exa fetch（只有标题 + 频道）[实测] | anysearch `extract`（有乱码）；feedgrab（缺标题和作者）[旧测] |
| 评论 | bb `youtube/comments` [实测] | — | — |
| 字幕，要时间轴或要保证完整 | yt-dlp 取一种语言的字幕（约 40s）[实测] | feedgrab（内部调 yt-dlp，64s，缺标题）[旧测] | bb `youtube/transcript`（失败）[旧测] |
| 字幕，只要快速读个大意 | exa `web_fetch_exa`（纯文本，无时间轴）[实测] | — | — |
| 中文翻译字幕（zh-Hans 自动翻译轨） | [UNKNOWN]：本次 yt-dlp 取 zh-Hans 报 HTTP 429 | 先取原文字幕，自己翻译 | — |
| 没有字幕的视频转文字 | **目前做不到**（见"坑"最后一条） | — | — |

## 命令

```bash
S=C:/Users/18368/Desktop/00_myCode/43_search_master/scripts
V="https://www.youtube.com/watch?v=zjkBMFhNj_g"   # 目标视频；搜索时随便填一个能打开的 watch 页

# 关键：BB_OPEN_URL 指向 watch 页 + BB_SETTLE=8。用 bb.sh 默认开的首页，本次 3 次全失败
# 搜索。位置参数：query max（默认 20，上限 50）
BB_OPEN_URL="$V" BB_SETTLE=8 bash $S/bb.sh youtube/search "Karpathy intro to large language models" 5
# 元数据。位置参数：id
BB_OPEN_URL="$V" BB_SETTLE=8 bash $S/bb.sh youtube/video zjkBMFhNj_g
# 评论。位置参数：id max（默认 20）
BB_OPEN_URL="$V" BB_SETTLE=8 bash $S/bb.sh youtube/comments zjkBMFhNj_g 5

# yt-dlp：永远加 --ignore-config --skip-download，永远不加 --cookies-from-browser
# 列字幕轨（约 4s）
yt-dlp --ignore-config --skip-download --list-subs "$V"
# 取字幕：一次只取一种语言，优先原始语言（en / en-orig）
yt-dlp --ignore-config --skip-download --write-subs --write-auto-subs --sub-langs "en" \
  --sub-format vtt -o "$TEMP/yt/%(id)s.%(ext)s" "$V"
# 要时间轴：直接读 VTT 的 cue 行（"00:00:02.280 --> ..."），或改 --sub-format json3 [UNKNOWN 没跑]
# 自动字幕 VTT 每句重复 2-3 次、带逐词时间标签，清洗成纯文本（丢掉时间轴）：
awk '/-->/{next} /^(WEBVTT|Kind:|Language:)/{next} {gsub(/<[^>]*>/,""); gsub(/^[ \t]+|[ \t]+$/,"")} $0!="" && $0!=prev {print; prev=$0}' \
  "$TEMP/yt/zjkBMFhNj_g.en.vtt"
# 用完删掉 $TEMP/yt
```

exa：先 `ToolSearch select:mcp__exa__web_fetch_exa`，再调
`web_fetch_exa({urls: ["https://www.youtube.com/watch?v=<id>"], maxCharacters: 20000})`。可以一次传多个 URL。

判断有没有字幕：先跑 `youtube/video`，看 `captionLanguages`；名字带"(自动生成)"的是自动字幕。

## 返回什么

- `youtube/search`：`{query, resultCount, videos[{videoId, title, channel, channelId, views, duration, publishedTime, description, url}]}`。`views` 是"4,136,925次观看"这种本地化字符串，`publishedTime` 是"2年前"，`description` 截断。约 4.8s（adapter）。
- `youtube/video`：`videoId, title, channel, channelId, channelUrl, subscriberCount("170万位订阅者"), description(截到 1000 字), duration(秒), durationFormatted, viewCount(数字), viewCountFormatted, likes("10万"), publishDate(ISO), category, isLive, keywords, captionLanguages[{lang, name}], url, _commentContinuationToken`。约 0.3s。
- `youtube/comments`：`{videoId, commentCountText, fetchedCount, comments[{rank, author, authorChannelId, text, publishedTime, likes, replyCount, isPinned}]}`。不含楼中楼内容。5 条 6.3s。
- yt-dlp 字幕：59 分钟视频的 en 自动字幕 VTT 603KB / 13,632 行，清洗后 1,704 行 / 64KB。`--list-subs` 列出自动字幕约 157 种语言（含 zh-Hans、en-orig）。
- exa `web_fetch_exa`：标题 + `Author`（频道）+ 转录纯文本；没有时间戳、播放量、发布日期。

## 坑

- bb.sh 默认开 `youtube.com` 首页：本次 3 次全失败（2 次 `YouTube config not found`，1 次等 26s 后 `Failed to fetch`）。改成 `BB_OPEN_URL=<watch 页> BB_SETTLE=8` 后 search / video / comments 都成功。根因是首页加载慢还是网络抖动 [UNKNOWN] [实测]。
- 本机访问 YouTube 慢：curl 首页 11s；yt-dlp 每次请求读超时 20s 后自动重试 [实测]。
- yt-dlp 一次取多种语言：`--sub-langs "zh-Hans,en"` 时 zh-Hans（自动翻译轨）返回 HTTP 429，yt-dlp 直接退出（rc=1），en 也没写出来，白等 63s。只取一种语言，改成 `en` 后 39s 成功 [实测]。
- yt-dlp 2025.12.08 已超过 90 天，每次有 SABR 警告，不影响取字幕 [实测]。
- 一律加 `--ignore-config`，防止配置文件里藏着 `--cookies-from-browser`。feedgrab 默认会让 yt-dlp 读日常 Chrome 的 cookie（`YTDLP_COOKIES_BROWSER` 默认 chrome），用 feedgrab 抓 YouTube 必须设 `YTDLP_COOKIES_BROWSER=' '` [旧测]。
- bb 返回的数字多是中文本地化字符串（"10万"、"2年前"）；要数值用 `youtube/video` 的 `viewCount` 或 yt-dlp [实测]。
- `youtube/transcript` 失败：它靠 DOM 里的字幕面板，而 bb 的 Chrome 里 tab 都是 hidden，面板渲染不出；timedtext 接口 200 但 0 字节（疑似要 PO token）[旧测]。本次没重测，别用。
- exa fetch 对长视频的转录是否完整 [UNKNOWN]（本次只要了 4000 字符）。要全文或时间轴用 yt-dlp。
- 本次后段 exa / anysearch 的搜索请求都报 `fetch failed`（本机网络），exa fetch 在前段成功过。遇到就换工具，别死等。
- 没有字幕的视频只能从音频转写：本机没有 Whisper，也没有 `GROQ_API_KEY`，现在转不了。要转需要装本地 Whisper，或设 `GROQ_API_KEY`（Groq 云端 Whisper，feedgrab 支持）[旧测]。不要为此下载音视频文件。

## 本次验证

- `bb.sh youtube/search "Karpathy intro to large language models" 5`（默认首页）→ `YouTube config not found`；重试 BB_SETTLE=6 → 26s 后 `Failed to fetch`；再试 BB_SETTLE=4 → `YouTube config not found`。
- 同上，改 `BB_OPEN_URL=<watch 页> BB_SETTLE=8` → 5 条，4.79s，第一条就是目标视频。
- `youtube/video zjkBMFhNj_g`（watch 页）→ 完整元数据，`captionLanguages` 只有 en 自动字幕，0.34s。
- `youtube/comments zjkBMFhNj_g 5`（watch 页）→ 5 条，总数"5,067 条评论"，6.29s。
- `yt-dlp --list-subs` → rc=0，4s，自动字幕约 157 种。
- `yt-dlp --sub-langs "zh-Hans,en" ...` → rc=1，63s，zh-Hans HTTP 429，无文件。
- `yt-dlp --sub-langs "en" ...` → rc=0，39s（1 次读超时重试），603KB VTT。
- exa `web_fetch_exa` 同一视频 → 标题 + 频道 + 转录纯文本（和 yt-dlp 内容一致），无时间戳。
