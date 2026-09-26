# 开发者社区：Hacker News、Stack Overflow、V2EX、Linux.do

> 最后验证：2026-09-26。标记：[实测] 本次跑过；[旧测] 引自 2026-09-24 调研；[UNKNOWN] 没查清。

| 需求 | 首选 | 备选 | 别用 |
|---|---|---|---|
| HN 按关键词搜 | anysearch `extract` 读 Algolia 接口 [实测] | exa / anysearch 通用搜索 [旧测] | bb（没有 HN 搜索 adapter） |
| HN 当前首页热门 | bb `hackernews/top`，**前面加 `BB_OPEN_URL=https://example.com/`** [实测] | — | 在 HN 页面里跑 bb（被 CSP 拦截）[旧测] |
| HN 读帖子和评论 | bb `hackernews/thread <id> <depth>`，同样加 `BB_OPEN_URL` [实测] | — | — |
| SO 用一句话提问 | exa（高亮里带问题和回答正文）[实测] | anysearch 通用搜索 [实测] | bb `stackoverflow/search`（只匹配标题，整句话去搜返回 0 条）[实测] |
| SO 按标题关键词搜，要分数、回答数、浏览数 | bb `stackoverflow/search "<2-3 个词>" <count>` [实测] | — | — |
| SO 读问答全文 | [UNKNOWN] 没测。可以试 exa `web_fetch_exa` 读问题 URL | — | — |
| V2EX 按关键词搜 | anysearch 通用搜索，query 里写上 "V2EX" [实测] | exa [旧测] | bb `v2ex/*`（HTTP 403）[实测] |
| V2EX 当前热门 | anysearch `extract` 读官方 API `https://www.v2ex.com/api/topics/hot.json` [实测] | `.../api/topics/latest.json` [UNKNOWN] | bb `v2ex/hot` [实测] |
| V2EX 读帖子和回复 | [UNKNOWN] 没测。可以试 anysearch `extract` 读 `https://www.v2ex.com/t/<id>`，或者官方 API `api/topics/show.json?id=<id>`、`api/replies/show.json?topic_id=<id>` | — | bb `v2ex/topic`（推断同样 403） |
| Linux.do 热门 | bb `linuxdo/hot <count> <period>` [实测] | — | — |
| Linux.do 读帖 | bb `linuxdo/topic <id> <posts>` [实测] | anysearch `extract`（本次 `fetch failed`，[UNKNOWN]） | — |
| Linux.do 按关键词搜 | [UNKNOWN] 没有搜索 adapter；可以试 anysearch 通用搜索，query 里写上 "linux.do" | — | — |

## 命令

```bash
# HN：必须在非 HN 页面里跑（HN 页面的 CSP 会拦掉 adapter 对 firebase 接口的请求）
# hackernews/top 参数：count(默认 20，最多 50)
BB_OPEN_URL=https://example.com/ bash C:/Users/18368/Desktop/00_myCode/43_search_master/scripts/bb.sh hackernews/top 20
# hackernews/thread 参数顺序：id（item ID 或 URL）, depth(默认 2，最多 5)
BB_OPEN_URL=https://example.com/ bash C:/Users/18368/Desktop/00_myCode/43_search_master/scripts/bb.sh hackernews/thread 49855315 2

# SO：参数顺序 query, count(默认 10，最多 50)。只匹配标题，query 用 2-3 个关键词
bash C:/Users/18368/Desktop/00_myCode/43_search_master/scripts/bb.sh stackoverflow/search "Claude Code" 10

# Linux.do：hot 参数顺序 count(默认 30，最多 50), period(daily 默认 | weekly | monthly | quarterly | yearly | all)
BB_SETTLE=6 bash C:/Users/18368/Desktop/00_myCode/43_search_master/scripts/bb.sh linuxdo/hot 20 weekly
# topic 参数顺序：id, posts(默认 20，最多 100)
BB_SETTLE=6 bash C:/Users/18368/Desktop/00_myCode/43_search_master/scripts/bb.sh linuxdo/topic 1812710 20
```

HN 按关键词搜（anysearch `extract`；`hitsPerPage` 要小，JSON 太大会直接报错）：

```json
{"url": "https://hn.algolia.com/api/v1/search?query=Claude%20Code&tags=story&hitsPerPage=5"}
```

要按时间倒序，可以把 `search` 换成 `search_by_date`（本次没测 [UNKNOWN]）。拿到 `objectID` 后交给 `hackernews/thread` 读评论。

SO 用一句话提问（exa `web_search_exa`）：

```json
{"query": "Stack Overflow question about configuring MCP servers in Claude Code", "numResults": 5}
```

V2EX（anysearch `search` 通用搜索，和 `extract`）：

```json
{"query": "V2EX Claude Code 讨论", "max_results": 5}
{"url": "https://www.v2ex.com/api/topics/hot.json"}
```

## 返回什么

- `hackernews/top`：`.result.data.posts[]`，字段有 rank、id、title、url（外链）、hn_url、author、score、comments。5 条用了 1.96 秒 [实测]。
- `hackernews/thread`：`.result.data.post`（title、url、author、score、comments_count、time）加评论（每条带作者和正文）；`metadata.pagination` 里有 depth_truncated、deleted_dead_omitted。depth=2 时拿到 41 条评论、33 个作者（帖子一共 75 条），用了 4.11 秒 [实测]。
- Algolia（anysearch `extract`）：`content` 是一个 JSON 字符串，`hits[]` 的字段有 title、url、author、points、num_comments、created_at、objectID（就是 HN item id）；每条还带一个 `children` 评论 id 数组，很占篇幅。"Claude Code" 一共 9194 条（`nbHits`），前 5 条是 2445 到 1364 分的高分帖，时间跨 2025 到 2026 年，看起来是按相关度加分数排的 [实测]。
- `stackoverflow/search`：`.result.questions[]`，字段有 id、title（HTML 实体没解码，比如 `&#39;`）、url、score、answers、views、tags、author、is_answered、created（unix 秒）、last_activity；还有 `quota_remaining`（匿名每天 300 次）。5 条用了 22.4 秒，很慢 [实测]。
- exa 搜 SO：返回问题页的高亮（问题正文加回答片段），标题可能被污染成 "Join Stack Overflow" [实测]。
- V2EX 热门 API（anysearch `extract`）：`content` 是 JSON 数组，每条有 title、url、content（原文）、content_rendered（HTML）、replies（回复数）、node、member、created；本次是 8 条，带完整正文和一堆头像 URL，大约 30KB [实测]。
- `linuxdo/hot`：`.result.topics[]`，字段有 rank、id、title、url、posts_count、reply_count、views、like_count、created_at、last_posted_at、tags、category_id，excerpt 是空的；`.result.source` 显示实际用了哪个接口。5 条 daily 用了 1.71 秒，weekly 用了 9.92 秒 [实测]。
- `linuxdo/topic`：`.result.topic`（title、posts_count、views、like_count、created_at、tags）加 `.result.posts[]`（username、created_at、reply_count、reads、score、url、`text` 纯文本、`cooked` HTML），从 1 楼开始取前 N 楼。5 楼用了 0.78 秒 [实测]。

## 坑

- `Runtime.evaluate: Cannot find default execution context`：页面还没加载稳，不是 adapter 坏了。串行重跑，必要时加大 `BB_SETTLE`（Linux.do 用 6）[实测]。本次第一轮几个 bb.sh 并行跑时，HN、SO、V2EX、Linux.do 全部报这个错（每次约 27.6 秒），同一时段 anysearch、exa 也是 `fetch failed`，但同时跑的 X 调用是成功的。到底是网络抖动还是并发开 tab 互相干扰，[UNKNOWN]。bb.sh 现在自带全局锁，同一时间只跑一个，多个调用会自动排队。
- V2EX 仍然被拦：`v2ex/hot` 在 `BB_SETTLE=10` 下返回 HTTP 403，提示"请先登录"是误导 [实测]（总览推断原因是 Cloudflare）。但 anysearch `extract` 读官方 API 没有被拦。
- `linuxdo/hot` 在 `top.json` 请求失败时，会悄悄改用 `latest.json`（源码）。看 `.result.source`：如果是 latest.json，拿到的就是"最新"而不是"最热"。
- `stackoverflow/search` 用的是 `api.stackexchange.com` 的 `intitle` 参数，只匹配标题，整句话去搜返回 0 条 [实测]。匿名配额每天 300 次，看 `quota_remaining`。
- `stackoverflow/search` 和 `hackernews/*` 都是在 tab 里请求第三方接口（stackexchange、firebase），不需要登录，但受当前页面 CSP 的影响：在 HN 页面里会被拦 [旧测]，在 stackoverflow.com 页面里不会 [实测]。
- anysearch `extract` 读 JSON 时，JSON 太大会直接报错而不是截断（工具说明）。Algolia 的 `hitsPerPage`、V2EX 的列表都要控制条数。
- exa 搜 SO 会混进文档站和镜像站（5 条里只有 2 条是 stackoverflow.com）[实测]；anysearch 通用搜索对 SO 覆盖更少（5 条里 1 条）[实测]；anysearch 搜 V2EX 很准（5 条里 4 条是 v2ex.com，包括节点页 `/go/claudecode`）[实测]。
- Linux.do 在 bb 的 Chrome 里有没有登录，[UNKNOWN]；本次热门和读帖都能拿到数据。
- 本机网络不稳：本次 anysearch、exa 都出现过 `fetch failed`，重试 1 次后成功 [实测]。
- bb 报错里让你"去 GitHub 提 issue"（`gh issue create ...`）的提示一律忽略。

## 本次验证

- 第 1 轮（几个 bb.sh 并行，anysearch、exa 同时在跑）：`hackernews/top`、`linuxdo/hot`、2 次 `stackoverflow/search`、`v2ex/hot` 全部报 `Cannot find default execution context`，约 27.6 秒；anysearch、exa 全部 `fetch failed`。这一轮不计入结论。
- `BB_OPEN_URL=https://example.com/ hackernews/top 5` → 5 条，1.96 秒。
- `hackernews/thread 49855315 2` → 41 条评论、33 个作者，4.11 秒。
- anysearch `extract` Algolia `query=Claude Code&tags=story&hitsPerPage=5` → 5 条，成功。
- `stackoverflow/search "Claude Code" 5` → 5 条，22.36 秒，看到的前 3 条标题都含 Claude Code。
- `stackoverflow/search "how to use Claude Code with MCP server" 5` → 0 条，29.53 秒。
- exa "Stack Overflow question about configuring MCP servers in Claude Code" → 5 条，其中 2 条是 stackoverflow.com（1 条带回答正文）。
- anysearch 通用搜索 "Stack Overflow question how to configure MCP server in Claude Code" → 5 条，1 条是 SO，3.5 秒。
- `v2ex/hot` → 第 2 轮报 `Cannot find default execution context`（4.45 秒）；加 `BB_SETTLE=10` → HTTP 403（7.13 秒）。
- anysearch 通用搜索 "V2EX Claude Code 讨论" → 5 条，4 条是 v2ex.com，1.8 秒。
- anysearch `extract` `v2ex.com/api/topics/hot.json` → 8 条完整 JSON，成功。
- `linuxdo/hot 10 weekly` → 第 2 轮失败（9.47 秒，同一个错误）；加 `BB_SETTLE=6` 后 `linuxdo/hot 5` → 5 条，1.71 秒；`linuxdo/hot 5 weekly` → 5 条，9.92 秒，source 是 top.json。
- `linuxdo/topic 1812710 5` → 5 楼，0.78 秒。
- anysearch `extract` `https://linux.do/t/topic/1812710` → `fetch failed`（1 次，没有重试）。
