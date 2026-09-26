# 播客（小宇宙）

> 最后验证：2026-09-26。标记：[实测] 本次跑过；[旧测] 引自 2026-09-24 调研；[源码] 只读了源码没跑；[UNKNOWN] 没查清。

| 需求 | 首选 | 备选 | 别用 |
|---|---|---|---|
| 找节目 / 单集 | exa 或 anysearch 通用搜索"小宇宙 <节目名或话题>"，从结果 URL 里取 pid / eid [UNKNOWN：本次两者都 `fetch failed`，没验证] | WebSearch（服务端执行，不受本机网络影响）[UNKNOWN]；bb `duckduckgo/search "site:xiaoyuzhoufm.com <关键词>"`（走 bb 的 Chrome，和 MCP 网络路径不同）[UNKNOWN] | bb 没有小宇宙搜索 adapter |
| 节目信息 + 最近单集列表 | bb `xiaoyuzhoufm/podcast` [实测] | — | — |
| 单集元数据 + shownotes | bb `xiaoyuzhoufm/episode` [实测] | feedgrab（shownotes 转 Markdown + 音频 URL）[源码] | — |
| 单集评论 | eval 读 `_next/data` 的 `pageProps.comments`（见命令）[实测] | — | adapter 只给评论数，不给评论正文 |
| 文字稿 | **没有能用的路**（见"坑"） | — | — |
| 没有文字稿的音频转文字 | **目前做不到** | — | — |

## 命令

```bash
S=C:/Users/18368/Desktop/00_myCode/43_search_master/scripts

# 节目。位置参数：pid（URL https://www.xiaoyuzhoufm.com/podcast/<pid> 里的 24 位 ID）
bash $S/bb.sh xiaoyuzhoufm/podcast 626b46ea9cbbf0451cf5a962

# 单集。位置参数：eid（URL https://www.xiaoyuzhoufm.com/episode/<eid> 里的 24 位 ID）
bash $S/bb.sh xiaoyuzhoufm/episode 6a97f287f03e74ee6b03ea5b
```

单集评论（adapter 不返回，用 `bb.sh eval`；只输出评论文本和计数，不输出用户信息）：

```bash
eid=6a97f287f03e74ee6b03ea5b
BB_SETTLE=3 bash $S/bb.sh eval "https://www.xiaoyuzhoufm.com/episode/$eid" \
  "(async()=>{const h=await (await fetch('/')).text();const b=h.match(/\"buildId\":\"([^\"]+)\"/)[1];const d=await (await fetch('/_next/data/'+b+'/episode/$eid.json?id=$eid')).json();return JSON.stringify(d.pageProps.comments.map(c=>({text:c.text,like:c.likeCount,replies:c.replyCount,at:c.createdAt})))})()"
```

同一个 `_next/data` JSON 里还有：`episode.shownotes`（HTML 原文，不截断）、`episode.media.source.url`（音频 m4a 地址，只在将来能转写时有用，**不要下载**）。

## 返回什么

- `xiaoyuzhoufm/podcast`：`{pid, title, author, description, subscriptionCount, episodeCount, latestEpisodePubDate, url, episodes[{eid, title, date, description(截 200 字), playCount, commentCount, favoriteCount, shownotes, links}]}`。`episodes` 只有页面上的最近 15 集（该节目 `episodeCount`=156）。约 1s，输出约 60KB（每集都带 shownotes），建议落文件再读。
- `xiaoyuzhoufm/episode`：`{eid, title, podcastTitle, podcastPid, playCount, commentCount, favoriteCount, duration(秒), durationMin, pubDate, guests[], links[{text, url}], shownotes(纯文本，截 3000 字), url}`。约 0.9s。
- 评论 eval：20 条热评，每条 `{text, like, replies, at}`；原始数据里还有 `replies`（楼中楼）、`ipLoc` 等。

## 坑

- 没有搜索 adapter：必须先拿到 pid / eid。用户给的是分享链接就直接从 URL 里取。
- `podcast` 的单集列表只覆盖页面服务端渲染的最近 15 集，更早的单集拿不到；翻页接口 [UNKNOWN] [实测]。
- `episode` 的 shownotes 截到 3000 字 [源码]；要全文用上面的 eval 取 `episode.shownotes`（HTML）。
- `guests` 是用正则从 shownotes 里猜"嘉宾："，经常为空（本次为空）[实测]。
- 文字稿：网页数据里确实有 `episode.transcript` 和 `transcriptMediaId` 字段，但 `transcript` 只是 `{mediaId: "<pid>/<文件名>.m4a"}` 这样的指针，没有文本；网页正文里也没有"文字稿"。App 里的文字稿怎么取 [UNKNOWN]（估计要 App 登录态接口，没查）[实测]。
- 转写：音频地址拿得到（`media.xyzcdn.net` 的 m4a），但本机没有 Whisper，也没有 `GROQ_API_KEY`，现在转不了。要转需要装本地 Whisper，或设 `GROQ_API_KEY`。feedgrab 的小宇宙 fetcher 在有 key 时会自动走 Groq Whisper 转写（开关 `xiaoyuzhou_whisper()` 默认开）[源码]。
- 播放数等是实时的：同一集两次调用 113,522 → 113,525。
- feedgrab 依赖当前工作目录，不设 `OUTPUT_DIR` 不写文件，stdout 只有约 150 字预览 [旧测]。本次没跑它抓小宇宙。
- 其他播客平台：feedgrab 有喜马拉雅 fetcher [源码]；Apple Podcasts、Spotify 等 [UNKNOWN]。

## 本次验证

- `bb.sh xiaoyuzhoufm/podcast 626b46ea9cbbf0451cf5a962`（张小珺商业访谈录）→ 订阅 313,859、共 156 集，返回 15 集（带播放/评论/收藏数和 shownotes），0.98s，60KB。
- `bb.sh xiaoyuzhoufm/episode 6a97f287f03e74ee6b03ea5b` → 标题、播放 113,525、时长 9,258s、5 个链接、shownotes 1,512 字、guests 为空，0.93s。
- eval 读同一集 `_next/data` → `pageProps` 有 `episode / comments / vote`；`episode` 有 `transcript`、`transcriptMediaId`，但 transcript 只是 mediaId 指针；音频是 m4a。
- eval 取评论（上面的命令原样）→ 20 条热评，文本、点赞、回复数、时间都有。
- exa `web_search_exa` 搜小宇宙单集 → `fetch failed`，重试 1 次仍失败；anysearch `search` → `fetch failed`。找节目这一格没验证。
