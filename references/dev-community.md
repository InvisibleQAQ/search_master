# 开发者社区：Hacker News、Stack Overflow、V2EX、Linux.do

> 最后验证：2026-09-27。标记：[实测] 本次跑过；[旧测] 2026-09-24 或 09-26 跑过；[源码] 只读了代码；[推断] 有旁证没直接验证；[UNKNOWN] 没查清。时间都是本机时区（EDT，-04:00）。
> V2EX、Linux.do 只用 neo（用户决定，2026-09-27；neo 里已登录 Linux.do）。neo 怎么调（`name_session`、`run` 的参数、结果写成文件时怎么读）见 `read-url.md`。

| 需求 | 首选 | 备选 | 别用 |
|---|---|---|---|
| HN 按关键词搜 | anysearch `extract` 读 Algolia 接口 [实测] | neo 直接打开 Algolia 接口，等 `pre` 出现 [旧测]；exa / anysearch 通用搜索 [旧测] | bb（没有 HN 搜索 adapter） |
| HN 当前首页热门 | bb `hackernews/top`，**前面加 `BB_OPEN_URL=https://example.com/`** [旧测] | — | 在 HN 页面里跑 bb（被 CSP 拦截）[旧测] |
| HN 读帖子和评论 | bb `hackernews/thread <id> <depth>`，同样加 `BB_OPEN_URL` [实测] | neo 打开 `https://hn.algolia.com/api/v1/items/<id>`，等 `pre` 出现，拿到整棵评论树 [旧测] | — |
| SO 用一句话提问 | exa（高亮里带问题和回答正文）[实测] | anysearch 通用搜索 [旧测] | bb `stackoverflow/search`（只匹配标题）[实测]；WebSearch 加 `allowed_domains: ["stackoverflow.com"]`（报 400）[实测] |
| SO 按标题关键词搜，要分数、回答数、浏览数 | bb `stackoverflow/search "<2-3 个词>" <count>`（词要是标题里连着出现的短语）[实测] | — | — |
| SO 读问答全文 | exa `web_fetch_exa` 读问题 URL（问题、每个回答的作者、分数、正文都有；采纳标记、评论没有）[旧测] | — | — |
| V2EX 按关键词搜 | neo 打开 Google `site:v2ex.com <词>`（V2EX 站内搜索框跳的就是它 [源码]；只在回复里提到的也能搜到）[实测] | neo 读 SoV2EX 接口（要按发帖时间排、按时间段或节点筛时用；新帖的回复没进索引）[实测]；neo 跑 DuckDuckGo `site:v2ex.com <词>` [实测] | Bing（无视 `site:`，10 条全是站外）[实测]；anysearch（只在回复里出现的词搜不到）[旧测]；exa [旧测]；bb `v2ex/*`（HTTP 403）[旧测] |
| V2EX 当前热门 | neo 打开官方 API `https://www.v2ex.com/api/topics/hot.json` [实测] | 最新帖：`.../api/topics/latest.json`（最近约 7 小时的 37 帖，298KB，要挑字段）[实测] | bb `v2ex/hot`（HTTP 403）[旧测]；anysearch `extract`（能读，但 V2EX 只用 neo） |
| V2EX 读帖子和回复 | neo `read` 读 `/t/<id>`，加 `selector: '#Main'`（主楼加回复，一页 100 楼）[实测] | neo 打开 `api/replies/show.json?topic_id=<id>`（全部回复，带 unix 时间，158KB 也一次拿到）[实测] | anysearch `extract`（73.5KB 以上 `extract_failed`）[旧测]；bb `v2ex/topic`（推断同样 403） |
| Linux.do 按关键词搜 | neo 在 linux.do 页面里同源 fetch `/search.json?q=<词>`（一页 50 帖 + 50 条楼层摘要，翻页 [UNKNOWN]）[实测] | — | bb（没登录，403）[旧测]；anysearch 通用搜索（10 条里只有 5 条是帖子）[旧测] |
| Linux.do 读帖 | neo 同源 fetch `/raw/<id>`（纯文本，一页 100 楼，`?page=2` 接着取）[实测] | `/t/<id>.json`（带发帖时间和 HTML，但只有前 20 楼）[实测] | bb `linuxdo/topic`（没登录：要登录的分类里的帖子报 404，提示却是"确认帖子 id 存在"；最多 20 楼）[实测]；WebFetch（见"坑"）|
| Linux.do 热门 | neo 同源 fetch `/top.json?period=weekly`（50 帖，含要登录的分类）[实测] | `/hot.json`（30 帖，混着 2025 年的长期热帖）[实测] | bb `linuxdo/hot`（没登录，要登录的分类不在里面 [推断]） |

## 命令

```bash
# HN：必须在非 HN 页面里跑（HN 页面的 CSP 会拦掉 adapter 对 firebase 接口的请求）
# hackernews/top 参数：count(默认 20，最多 50)
BB_OPEN_URL=https://example.com/ bash C:/Users/18368/Desktop/00_myCode/43_search_master/scripts/bb.sh hackernews/top 20
# hackernews/thread 参数顺序：id（item ID 或 URL）, depth(默认 2，最多 5)
BB_OPEN_URL=https://example.com/ bash C:/Users/18368/Desktop/00_myCode/43_search_master/scripts/bb.sh hackernews/thread 49855315 2

# SO：参数顺序 query, count(默认 10，最多 50)。只匹配标题，query 用 2-3 个关键词
bash C:/Users/18368/Desktop/00_myCode/43_search_master/scripts/bb.sh stackoverflow/search "Claude Code" 10
```

HN 按关键词搜（anysearch `extract`；`hitsPerPage` 要小，JSON 太大会直接报错）：

```json
{"url": "https://hn.algolia.com/api/v1/search?query=Claude%20Code&tags=story&hitsPerPage=5"}
```

要按时间倒序，把 `search` 换成 `search_by_date`（没测 [UNKNOWN]）。拿到 `objectID` 后交给 `hackernews/thread` 读评论。

SO 用一句话提问（exa `web_search_exa`）：`{"query": "Stack Overflow question about configuring MCP servers in Claude Code", "numResults": 5}`

V2EX 按关键词搜（neo `run`）。`page` 里有 `/sorry/` 是 Google 验证码：把 `engines.google` 换成 `engines.ddg`。`page` 是 `about:blank` 是页面没打开（今天 3 次都是断网，换引擎没用）：先 `curl -m 15 https://example.com/`，通了再重跑：

```js
const word = 'bb-browser';
const engines = {
  google: ['https://www.google.com/search?hl=zh-CN&q=', '#search a:has(h3)'],
  ddg: ['https://duckduckgo.com/?kl=cn-zh&q=', 'a[data-testid="result-title-a"]'],
};
const [base, sel] = engines.google;
const id = await browser.pages.newPage(base + encodeURIComponent('site:v2ex.com ' + word));
try {
  const w = await browser.wait(id, {for: 'selector', value: sel, timeout: 20000});
  const r = await browser.evaluate(id, {code: `return {page: location.href, items: [...document.querySelectorAll('${sel}')].map(a => ({title: a.innerText.split('\\n')[0], url: a.href}))}`});
  const seen = new Set(), items = [];
  for (const x of r.value.items) {  // 镜像域名（hk. global. fast. cn. s. edge.）按帖子 id 去重
    const m = x.url.match(/v2ex\.com\/t\/(\d+)/);
    if (seen.has(m ? m[1] : x.url)) continue;
    seen.add(m ? m[1] : x.url);
    items.push({title: x.title, url: m ? 'https://www.v2ex.com/t/' + m[1] : x.url});
  }
  return {matched: w.matched, page: r.value.page, items};
} finally {
  await browser.pages.close(id);
}
```

V2EX 的 JSON 接口（热门、SoV2EX、回复）都用同一段：打开接口 URL，等 `body *`，在页面里 `JSON.parse(document.body.innerText)`，只挑要的字段返回（整份返回超过约 5,000 字符会写成文件，见 `read-url.md`）：

```js
const id = await browser.pages.newPage('https://www.sov2ex.com/api/search?q=' + encodeURIComponent('Claude Code') + '&operator=and&sort=created&size=20');
try {
  await browser.wait(id, {for: 'selector', value: 'body *', timeout: 15000});
  const r = await browser.evaluate(id, {code: "const j = JSON.parse(document.body.innerText); return {total: j.total, hits: j.hits.map(h => ({id: h._source.id, title: h._source.title, member: h._source.member, created_utc: h._source.created, hl: Object.values(h.highlight || {}).flat()[0]}))}"});
  return r.value ?? r;
} finally {
  await browser.pages.close(id);
}
```

- SoV2EX 参数（来自它的 API.md）：`q`；`from`（偏移）；`size`（最多 50）；`sort`（`sumup` 按相关度，默认 | `created` 按发帖时间）；`order`（0 降序 | 1 升序）；`gte` / `lte`（unix 秒）；`node`（节点名）；`operator`（`or` 默认 | `and`）。按相关度搜多个词一定加 `operator=and`："Claude Code" 默认 37,303 条（只含 "Code" 的也算），加上后 4,370 条；`sort=created` 时 `operator` 不起作用，加不加都是 4,245 条 [实测]。
- 热门：URL 换成 `https://www.v2ex.com/api/topics/hot.json`，挑 `id, title, replies, node.name, member.username, created`；最新帖换成 `latest.json`，同样挑字段。
- 回复：`https://www.v2ex.com/api/replies/show.json?topic_id=<id>`，挑 `member.username, created, content`；主楼用 `api/topics/show.json?id=<id>`。

V2EX 读帖（neo `run`；超过 100 楼时第 2 页是 `/t/<id>?p=2`）：

```js
const id = await browser.pages.newPage('https://www.v2ex.com/t/1244937');
try {
  await browser.wait(id, {for: 'selector', value: '#Main div.cell[id^=r_], #Main .topic_content', timeout: 15000});
  const meta = await browser.evaluate(id, {code: "return {title: document.title, header: document.querySelector('#Main .box .cell .gray')?.innerText, floors: document.querySelectorAll('#Main div.cell[id^=r_]').length, pages: document.querySelector('#Main input.page_input')?.max || 1, times: [...document.querySelectorAll('#Main div.cell[id^=r_] .ago')].map(s => s.title)}"});
  const md = await browser.read(id, {format: 'markdown', selector: '#Main'});
  return {...meta.value, md};
} finally {
  await browser.pages.close(id);
}
```

Linux.do（neo `run`）。linux.do 从 neo 打开常要 10–25 秒，所以分几次 run：第 1 次开 tab 不关，之后每个接口一次 run（每次 0.4–2 秒），最后一次关 tab。两次调用之间隔几秒（用户的真实账号）。

```js
// 第 1 次：开 tab，等 #main-outlet（等 body * 太早）。matched 为 false 但 url 已是 linux.do：页面还在加载，直接跑第 2 段；
// url 还是 about:blank：browser.nav(id).goto('https://linux.do/') 再等一次
const id = await browser.pages.newPage('https://linux.do/');
const w = await browser.wait(id, {for: 'selector', value: '#main-outlet', timeout: 20000});
return {id, matched: w.matched, url: (await browser.evaluate(id, {code: 'return location.href'})).value};
```

```js
// 之后每次：找回自己的 linux.do tab，同源 fetch 一个接口。登录状态只看 status：200 就是好的
const tab = (await browser.pages.list()).find(p => p.ownership === 'mine' && p.url.startsWith('https://linux.do'));
if (!tab) return {error: '没有自己的 linux.do tab，先跑第 1 段'};
const path = '/search.json?q=' + encodeURIComponent('Claude Code');
const r = await browser.evaluate(tab.pageId, {code: `const r = await fetch(${JSON.stringify(path)}, {credentials: 'include', headers: {accept: 'application/json', 'x-requested-with': 'XMLHttpRequest'}});
if (r.status !== 200) return {status: r.status, body: (await r.text()).slice(0, 200)};
const j = await r.json();
return {status: 200, topics: (j.topics || []).map(t => ({id: t.id, title: t.title, created_at: t.created_at, posts_count: t.posts_count})), posts: (j.posts || []).map(p => ({topic_id: p.topic_id, post_number: p.post_number, username: p.username, created_at: p.created_at, blurb: p.blurb}))}`});
return r.value ?? r;  // 超过约 5,000 字符时结果在 r.path 指向的文件里
```

- 读帖：`path` 换成 `/raw/<id>`（超过 100 楼再取 `/raw/<id>?page=2`），返回 `{status, text: await r.text()}`，超过约 5,000 字符就写成文件。要发帖时间就 fetch `/t/<id>.json`，取 `post_stream.posts[]` 的 `post_number, username, created_at`（只有前 20 楼）。
- 热门：`path` 换成 `/top.json?period=weekly`（daily | weekly | monthly | quarterly | yearly | all），挑 `j.topic_list.topics` 的 `id, title, posts_count, views, like_count, created_at, category_id`。
- 最后一次：`await browser.pages.close(tab.pageId)`。fetch 卡住时 run 会在 30 秒被中止（tab 本来就留着），先按"坑"里的办法看是不是断网。

## 返回什么

- `hackernews/top`：`.result.data.posts[]`，字段有 rank、id、title、url（外链）、hn_url、author、score、comments。5 条 adapter 1.96 秒 / 实际 [UNKNOWN] [旧测]。
- `hackernews/thread`：`.result.data.post`（title、url、author、score、comments_count、time）加评论（每条带作者和正文）；`metadata.pagination` 里有 depth_truncated、deleted_dead_omitted。depth=2 时 110 条评论，`completeness: partial`，adapter 10.49 秒 / 实际 [UNKNOWN] [实测]。
- Algolia（anysearch `extract`）：`content` 是一个 JSON 字符串，`hits[]` 的字段有 title、url、author、points、num_comments、created_at、objectID（就是 HN item id）；每条还带一个 `children` 评论 id 数组，很占篇幅。总条数在 `nbHits`；前几条看起来是按相关度加分数排的 [旧测]。
- `stackoverflow/search`：`.result.questions[]`，字段有 id、title（HTML 实体没解码，比如 `&#39;`）、url、score、answers、views、tags、author、is_answered、created（unix 秒）、last_activity；还有 `quota_remaining`（匿名每天 300 次）。adapter 0.5–0.8 秒 / 实际 [UNKNOWN] [实测]；09-26 记的 22.4 秒口径不明，可能是实际等待。
- exa 搜 SO：返回问题页的高亮（问题正文加回答片段），标题可能被污染成 "Join Stack Overflow" [旧测]。
- Google `site:v2ex.com`：每页 10 条（`num=20` 无效），只有标题和 URL，没有日期；URL 混着 `hk.` `global.` `fast.` `cn.` `s.` 等镜像域名，同一帖子可能出现两三次，脚本按 `/t/<id>` 去重 [实测]。结果里也会有节点页 `/go/<节点>` 和标签页 `/tag/<词>`。
- SoV2EX：`{took, total, hits[]}`，每条 `_source` 有 id、title、content（主楼原文）、member、node（数字 id）、replies、created（**UTC**，没有时区后缀，换本机时间减 4 小时）；`highlight` 按命中位置分 title、content、`reply_list.content`、`postscript_list.content`。`replies` 不会更新：1198379 在这里是 0，V2EX API 是 1 [实测]。
- V2EX 热门 API：JSON 数组，每条有 id、title、url、content（原文）、content_rendered（HTML）、replies、node、member、created（unix 秒）；本次 7 条，约 30KB，1.08 秒 [实测]。
- V2EX 读帖：`read` 的 md 里有标题、节点、浏览数、主楼、每条回复（楼号、用户名、正文）。md 里的时间是相对的（"21h 1m ago"），绝对时间只在每条回复 `.ago` 的 `title` 属性里（`2026-09-26 22:14:31 +08:00`），脚本的 `times` 就是取这个。82 楼的帖子 md 40.5KB，写成文件 [实测]。
- V2EX 回复 API：数组，每条有 member、content、content_rendered、created（unix 秒）；82 条 158KB [实测]。
- Linux.do `/search.json`：`topics[]`（id、title、created_at、posts_count 等）和 `posts[]`（topic_id、post_number、username、created_at、blurb 摘要），时间都是 UTC（带 `Z`）。"Claude Code" 50 帖 + 50 条楼层，34KB；"bb-browser" 14 + 14 [实测]。翻页 `&page=2` 没测 [UNKNOWN]。
- Linux.do `/raw/<id>`：纯文本，每楼一段 `用户名 | 2025-12-31 04:39:57 UTC | #楼号`，楼之间是一行 `-------------------------`。**这个时间是最后编辑时间（updated_at），不是发帖时间**：1010145 的 1 楼在这里是 2025-12-31，`/t/1010145.json` 里 created_at 是 2025-10-05、updated_at 是 2025-12-31 [实测]。楼号会跳（删掉的楼不出现），第 1 页到 #102 共 100 楼。
- Linux.do `/t/<id>.json`：title、posts_count、category_id、created_at，`post_stream.stream` 是全部楼的 id，`post_stream.posts[]` 只有前 20 楼（带 created_at、updated_at、cooked HTML）[实测]。
- Linux.do `/top.json`：`topic_list.topics[]`（id、title、posts_count、views、like_count、created_at、category_id），weekly 50 帖；`/hot.json` 30 帖 [实测]。

## 坑

- V2EX 搜索：
  - V2EX 自己的搜索框没有站内搜索，回车打开 Google `site:v2ex.com/t <词>`，下拉里还有一项 SoV2EX（第三方站内搜索）[源码，`combo.js`]。
  - Google 覆盖回复，SoV2EX 不一定：搜 "bb-browser"，Google 9 条（7 个帖子，多数只在回复里提到），SoV2EX 只有 1 条（标题里带这个词的）[实测]。SoV2EX 对老帖能命中回复（"hadoop 集群" 50 条里 28 条是回复命中）[实测]，新帖的回复大概还没进索引 [推断]。
  - Bing 不认 `site:`：`site:v2ex.com Claude Code` 10 条全是 claude.com、CSDN、菜鸟教程等站外结果，不报错 [实测]。
- V2EX 读帖：一页最多 100 楼（160 楼的 511593，第 1 页是 1–100 楼，`input.page_input` 的 max 是 2）[实测]。neo 没登录 V2EX，读帖、接口都不受影响 [实测]。
- V2EX 接口有缓存：`replies/show.json` 可能返回空数组（帖子其实有回复），`hot.json` 的回复数也会比 `show.json` 少几条 [旧测]。V2EX API 限流 [UNKNOWN]。
- bb `linuxdo/topic` 读要登录的分类（如 category_id 20）里的帖子，返回 HTTP 404，提示"确认帖子 id 存在"，会让人以为帖子被删了；实际是 bb 的 Chrome 没登录 Linux.do [实测]。另外它传多少楼都只给 20 楼（Discourse 一页 20 楼，adapter 不翻页）[旧测]。
- Linux.do 登录状态不要看页面上的 `.current-user`：等到 `body *` 时它还是 false，等到 `#main-outlet` 后才是 true [实测]。直接看接口 status：200 就是登录好了，403 或跳 /login 才是没登录。neo 已登录时，bb 读不了的 2777118（category_id 20）`/raw` 62/62 楼、`/t/2777118.json` 200 [实测]。
- Linux.do `/hot.json` 按 Discourse 的热度算法排，前几条里有 2025-03、2025-08 的长期帖；要"这周最热"用 `/top.json?period=weekly` [实测]。
- 本机代理上游断网时：neo 打开 linux.do 落到 `chrome-error://chromewebdata/`（ERR_TIMED_OUT）或一直停在 about:blank；bb `linuxdo/topic` 报 `Daemon request timed out`（30.27 秒）或 `TypeError: Failed to fetch`；anysearch `extract` 读 Algolia 连续 3 次 `fetch failed`；WebFetch 连 example.com 都报 `Unable to verify if domain ... is safe to fetch` [实测]。所以 09-26 记的"WebFetch 读 linux.do 域名被拦"很可能也是网络问题 [推断]。国内站（baidu）照常能开，先用 `curl -m 15 https://example.com/` 判断是不是断网，是就过几分钟再试。
- `Runtime.evaluate: Cannot find default execution context`：不只是并发。`hackernews/thread` 在断网、`BB_OPEN_URL` 打不开时出现（adapter 1.97 秒 / 实际约 31 秒）；`stackoverflow/search` 网络正常时也出现过 1 次，重跑就好 [实测]。bb.sh 有全局锁，同一时间只跑一个。
- `hackernews/thread` 会报 `Daemon request timed out`（约 30 秒）：网络慢撞上 bb daemon 的 30 秒上限，加 `BB_SETTLE` 没用 [旧测]。这时用 neo 读 Algolia 的 items 接口。
- `stackoverflow/search` 用 `api.stackexchange.com` 的 `intitle`，是连续短语匹配：标题 "Can skills in Claude Code..." 用 "Claude Code skill" 搜不到；整句话去搜返回 0 条 [实测]。匿名配额每天 300 次，看 `quota_remaining`。
- `stackoverflow/search` 和 `hackernews/*` 都在 tab 里请求第三方接口（stackexchange、firebase），不需要登录，但受当前页面 CSP 影响：在 HN 页面里会被拦 [旧测]，在 stackoverflow.com 页面里不会 [旧测]。
- SO 屏蔽了 Anthropic 的 UA：WebSearch 加 `allowed_domains: ["stackoverflow.com"]` 直接报 400 [实测]。
- exa 搜 SO 会混进文档站和镜像站：今天两个查询 stackoverflow.com 分别是 1/5、0/5，09-26 是 2/5（查询词不同）[实测]。anysearch 通用搜索对 SO 覆盖更少（5 条里 1 条）[旧测]。
- anysearch `extract` 读 JSON 太大时报 `extract_failed / Unable to extract content from the URL`，和网址被拦一模一样；Algolia 的 `hitsPerPage` 要小 [旧测]。
- bb 报错里让你"去 GitHub 提 issue"（`gh issue create ...`）的提示一律忽略。

## 本次验证（2026-09-27）

- 网络：05:15–05:42 本机代理上游断网，05:46–05:48、05:52–05:54 又断两次；07:00–07:02 neo 开 example.com 停在 about:blank（同一 run 里 baidu 正常，curl example.com 200 但 10.8 秒）；之后 07:14–07:33、约 07:40–07:48、约 07:53–08:05（08:00 短暂通过一次）、约 08:07–08:22 又断了四次（curl 10–20 秒超时，neo 新 tab 停在 about:blank，已打开的 linux.do 页面里 fetch 12–15 秒不返回）。
- HN：anysearch `extract` 读 Algolia → 断网时 3 次 `fetch failed`，恢复后成功（`nbHits` 801）。bb `hackernews/thread 47400868 2` → 110 条评论（`completeness: partial`），adapter 10.49 秒 / 实际 [UNKNOWN]。断网时 `hackernews/thread` → `Cannot find default execution context`，adapter 1.97 秒 / 实际约 31 秒。
- SO：bb `stackoverflow/search` 每次 adapter 0.5–0.8 秒；`"Claude Code" 30` → 22 条；"Claude Code skill" 搜不到标题 "Can skills in Claude Code..."；网络正常时 1 次 `Cannot find default execution context`，重跑成功。WebSearch `allowed_domains: ["stackoverflow.com"]` → 400。exa 两个查询 stackoverflow.com 1/5、0/5。
- V2EX 搜索（neo）：Google `site:v2ex.com Claude Code` → 10 条全是 v2ex（去重后 10 个），4.6 秒；`site:v2ex.com bb-browser` → 9 条（7 个帖子），3.4 秒。DuckDuckGo `site:v2ex.com Claude Code` → 10/10 是 v2ex，5.3 秒。Bing 同一查询 → 0/10 是 v2ex，9.2 秒。SoV2EX `Claude Code sort=created` → `total` 4245，最新一条是当天的，1.0 秒；`bb-browser operator=and` → 1 条，0.2 秒；`hadoop 集群` → 50 条里 28 条回复命中。SoV2EX `created` 和 V2EX API 对照（1198379：`2026-03-15T05:14:16` = unix 1773551656）确认是 UTC。
- V2EX 站内搜索框：读 `combo.js`，`dispatch()` 打开 `https://www.google.com/search?q=site:v2ex.com/t%20<词>`，下拉候选里还有 SoV2EX。[源码]
- V2EX 热门（neo）：`api/topics/hot.json` → 7 条，30KB，1.08 秒。
- V2EX 读帖（neo `read` + `#Main`）：今天早些时候 `/t/<id>` 61/61 条回复，29KB，3.4 秒；`/t/1244937` 82/82，40.5KB 写成文件，11.8 秒；`/t/511593`（160 楼）第 1 页 1–100 楼，6.6 秒。`api/replies/show.json?topic_id=1244937` → 82 条，158KB，unix 时间。
- Linux.do（bb，今天早些时候）：`linuxdo/topic 2777118` → HTTP 404（帖子在要登录的 category_id 20）。
- Linux.do（neo，按上面的分段脚本，07:34–07:52）：开 tab 23.3 秒时 `#main-outlet` 还没出现（url 已是 linux.do），下一次 run 时已加载完、`.current-user` 为 true。`/search.json?q=Claude Code` → 200，50 + 50，0.52 秒；`/search.json?q=bb-browser` → 200，14 + 14，0.39 秒。`/raw/1010145`（193 楼）→ 100 楼 #1–#102，`?page=2` → 93 楼 #103–#198，两次共 0.68 秒。`/t/1010145.json` → 200，posts 20 条、stream 193，1.6 秒。`/top.json?period=weekly` → 200，50 帖，2.0 秒。`/hot.json` → 断网时 2 次超时，恢复后 200，30 帖，0.39 秒。`/raw/2777118` → 62/62 楼，`/t/2777118.json` → 200，category_id 20，共 4.9 秒。
- V2EX 脚本原样复跑（08:05–08:24，网络恢复后）：搜索脚本 Google `site:v2ex.com MCP` → 9 个帖子，3.3 秒（断网时 2 次停在 about:blank，不计）；读帖脚本 `/t/511593` → 100 楼、`pages` 2、100 个绝对时间，3.8 秒；SoV2EX 脚本 → 20 条，0.45 秒；`latest.json` → 37 帖，298KB，0.54 秒。DDG 的脚本形式只在断网时跑过 1 次（about:blank），选择器和上面单独跑成功的那次相同。
- 09-26 的旧路线已弃用：anysearch 搜 V2EX（5 条里 4 条是 v2ex.com，但 "bb-browser" 这种只在回复里出现的词两次都没找到）、anysearch `extract` 读 V2EX 帖子和接口、bb `v2ex/*`（403）、bb `linuxdo/hot` 和 `linuxdo/topic`（没登录）。按用户 09-27 的决定改为只用 neo，原因见"别用"和"坑"。09-26 neo 打开 v2ex.com 4 个页面全部 `ERR_TIMED_OUT`，今天都正常，当时是网络问题 [推断]。
- 09-26 保留的证据（路由没变，今天没重跑）：`BB_OPEN_URL=https://example.com/ hackernews/top 5` → 5 条，adapter 1.96 秒；`hackernews/thread 49855315 2` → 41 条评论，adapter 4.11 秒；neo 打开 `hn.algolia.com/api/v1/items/47396414` 等 `pre` → 整棵评论树；exa fetch SO 问题 78112394（第 4 次才成功）→ 标签、分数、提问正文、每个回答的作者、分数、正文。
