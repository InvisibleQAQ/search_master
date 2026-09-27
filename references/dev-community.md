# 开发者社区：Hacker News、Stack Overflow、V2EX、Linux.do

> 最后验证：2026-09-26。标记：[实测] 本次跑过；[旧测] 引自 2026-09-24 调研；[UNKNOWN] 没查清。

| 需求 | 首选 | 备选 | 别用 |
|---|---|---|---|
| HN 按关键词搜 | anysearch `extract` 读 Algolia 接口 [实测] | neo 直接打开 Algolia 接口，等 `pre` 出现 [实测]；exa / anysearch 通用搜索 [旧测] | bb（没有 HN 搜索 adapter） |
| HN 当前首页热门 | bb `hackernews/top`，**前面加 `BB_OPEN_URL=https://example.com/`** [实测] | — | 在 HN 页面里跑 bb（被 CSP 拦截）[旧测] |
| HN 读帖子和评论 | bb `hackernews/thread <id> <depth>`，同样加 `BB_OPEN_URL` [实测] | neo 打开 `https://hn.algolia.com/api/v1/items/<id>`，等 `pre` 出现，拿到整棵评论树 [实测] | — |
| SO 用一句话提问 | exa（高亮里带问题和回答正文）[实测] | anysearch 通用搜索 [实测] | bb `stackoverflow/search`（只匹配标题，整句话去搜返回 0 条）[实测] |
| SO 按标题关键词搜，要分数、回答数、浏览数 | bb `stackoverflow/search "<2-3 个词>" <count>` [实测] | — | — |
| SO 读问答全文 | exa `web_fetch_exa` 读问题 URL（问题、每个回答的作者、分数、正文都有；采纳标记、评论没有）[实测] | — | — |
| V2EX 按关键词搜 | anysearch 通用搜索，query 里写上 "V2EX" [实测] | neo 跑 Google `site:v2ex.com <词>`（只在回复里被提到的也能搜到）[实测]；exa [旧测] | bb `v2ex/*`（HTTP 403）[实测]；neo 直接打开 v2ex.com（`ERR_TIMED_OUT`）[实测] |
| V2EX 当前热门 | anysearch `extract` 读官方 API `https://www.v2ex.com/api/topics/hot.json` [实测] | `.../api/topics/latest.json` [UNKNOWN] | bb `v2ex/hot` [实测] |
| V2EX 读帖子和回复 | anysearch `extract` 读 `https://www.v2ex.com/t/<id>`（主楼加全部回复，只有相对时间）[实测] | 官方 API `api/topics/show.json?id=<id>`、`api/replies/show.json?topic_id=<id>`（带 unix 时间；回复多了会 `extract_failed`，见"坑"）[实测] | bb `v2ex/topic`（推断同样 403） |
| Linux.do 热门 | bb `linuxdo/hot <count> <period>` [实测] | — | — |
| Linux.do 读帖 | bb `linuxdo/topic <id> <posts>`（最多 20 楼，够用）[实测] | neo 在 linux.do 页面里同源 fetch `/raw/<id>`（全部楼层纯文本，0.3–0.8 秒）[实测]；anysearch `extract` [UNKNOWN] | WebFetch（域名被拦）[实测] |
| Linux.do 按关键词搜 | neo（已登录）在 linux.do 页面里同源 fetch `/search.json?q=<词>`（命令见下；不稳，本次 1 次成功、2 次失败）[实测] | anysearch 通用搜索，query 里写上 "linux.do"（10 条里 5 条是帖子）[实测] | bb（没登录，403）[实测] |

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
# topic 参数顺序：id, posts(默认 20；传更大也只返回 20 楼，adapter 不翻页)
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

Linux.do 按关键词搜（neo `run`；用户已在 neo 里登录，没登录会 403 或跳 /login）。linux.do 从 neo 打开常常很慢，所以先确认页面到了 linux.do 再 fetch，并且用 finally 保证关 tab（evaluate 报错会中止 run）：

```js
const id = await browser.pages.newPage('https://linux.do/');
try {
  await browser.wait(id, {for: 'selector', value: 'body *', timeout: 15000});
  const here = (await browser.evaluate(id, {code: 'return location.origin'})).value;
  if (here !== 'https://linux.do') return {error: 'linux.do 没打开：' + here};  // about:blank 的 origin 是 "null"
  const r = await browser.evaluate(id, {code: "const r = await fetch('/search.json?q=' + encodeURIComponent('bb-browser'), {credentials: 'include', headers: {accept: 'application/json', 'x-requested-with': 'XMLHttpRequest'}}); const j = await r.json(); return {status: r.status, topics: (j.topics || []).map(t => ({id: t.id, title: t.title, created_at: t.created_at})), posts: (j.posts || []).map(p => ({topic_id: p.topic_id, post_number: p.post_number, username: p.username, blurb: p.blurb}))}"});
  return r.value ?? r;  // 超过约 5,000 字符时结果在 r.path 指向的文件里
} catch (e) {
  return {error: String(e)};
} finally {
  await browser.pages.close(id);
}
```

读帖备选：同一个页面里 `fetch('/raw/<id>', {credentials: 'include'})`，返回全部楼层的纯文本（每楼一段，带用户名、UTC 时间、楼号）。

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
- Linux.do：bb 的 Chrome 没登录（页面没有 `.current-user`），热门和读帖不受影响 [实测]。`linuxdo/topic` 的 posts 传多少都只返回 20 楼，不报错（Discourse 一页 20 楼，adapter 不翻页）[实测]。
- `hackernews/thread` 会报 `Daemon request timed out`（本次 2/2，各约 30 秒）[实测]：当时 anysearch、exa 也在 `fetch failed`，是网络慢撞上 bb daemon 的 30 秒上限，加 `BB_SETTLE` 没用。这时用 neo 读 Algolia 的 items 接口。
- anysearch `extract` 读 JSON 太大时报的是 `extract_failed / Unable to extract content from the URL`，和网址被拦一模一样。V2EX 实测：20KB、40KB 能读，73.5KB（44 条回复）读不了；v1 接口不认 `page_size`，没法分页绕过 [实测]。
- V2EX 接口有缓存：`replies/show.json` 可能返回空数组（帖子其实有回复），`hot.json` 的回复数也会比 `show.json` 少几条 [实测]。
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
- 维护测试（同日晚些时候）：
  - SO 读问答全文：exa 搜 "Stack Overflow question about Playwright page.route mock response" → 5 条里 3 条是 SO；exa fetch 问题 78112394（第 4 次才成功，前 3 次 `fetch failed`）→ Tags、Score、Views、提问正文、每个回答的作者、分数、正文。有多个回答时能不能全部返回 [UNKNOWN]（批量 fetch 连续失败）。[实测]
  - V2EX 读帖：anysearch `extract` `/t/1244814` → 约 10KB markdown，标题、节点、浏览数、主楼、全部 44 条回复，时间只有 "1 day ago"；`topics/show.json?id=1244814` → 正文完整、回复数 44、unix 时间；`replies/show.json` 44 条（73.5KB）`extract_failed`，16 条（20KB）成功。[实测]
  - V2EX 按关键词搜 "bb-browser"：anysearch 两次、WebSearch 限定 v2ex.com 都没找到（讨论都在回复里）；neo 跑 Google `site:v2ex.com bb-browser` 找到 6 处。neo 打开 v2ex.com 4 个页面全部 `ERR_TIMED_OUT`。[实测]
  - Linux.do 按关键词搜：anysearch `search` "linux.do Claude Code 使用体验" → 第 1 次 `Service temporarily unavailable`，重试 10 条，5 条是 `linux.do/t/topic/*`，1.8 秒。[实测]
  - `linuxdo/topic 1758760 60` → 只返回 20 楼，19 秒，不报错。[实测]
  - `hackernews/thread 47396414 3` → 两次 `Daemon request timed out`（33 秒、35 秒，第二次加了 `BB_SETTLE=4`）；neo 打开 `hn.algolia.com/api/v1/items/47396414`、等 `pre` → 整棵评论树。[实测]
  - Linux.do 按关键词搜（用户在 neo 里登录后）：neo 同源 fetch `/search.json?q=bb-browser`（带 `accept`、`x-requested-with`）→ 200，14 个帖子、15 条带摘要的楼层，只有 1 页，6.07 秒。没登录时 bb eval 403、neo 跳 /login。[实测]
  - Linux.do 读帖：同一时段 bb `linuxdo/topic` 2 次 `Daemon request timed out`（30.3 秒）；neo fetch `/t/topic/<id>.json` 20–26 秒被中止（当时 linux.do 很慢）；neo fetch `/raw/<id>` 0.28–0.82 秒，31 楼、16 楼都一次取全。WebFetch 报 `Unable to verify if domain linux.do is safe to fetch`。[实测]
  - 同一条路由稍后由主 agent 复测：15 秒内新 tab 还停在 about:blank（`wait` 返回 `{matched: false}`）；分两次 run，先开 tab、再 fetch，tab 已经在 linux.do 上，但 `/search.json` 连续 2 次 `TypeError: Failed to fetch`。当时 linux.do 从 neo 访问不稳，没有继续重试。[实测]
