# 通用网页搜索、新闻、网络兜底

> 最后验证：2026-09-27。标记：[实测] 本次跑过；[旧测] 引自 2026-09-24 调研（`42_expert/搜索工具总览.md` 及其原始报告）；[UNKNOWN] 没查清。钟点时间都是本机时间（美东，EDT -04:00）。
> anysearch 和 exa 走本机网络，经常 `fetch failed`。先看文末"网络坏了"一节，分清是网络故障还是工具故障。
> 给一个 URL 拿正文、别的工具读不到的网页交给 neo：见 `read-url.md`。

## 中文网页搜索

| 需求 | 首选 | 备选 | 别用 |
|---|---|---|---|
| 中文综合、行业话题 | anysearch `search`（不带 domain） | neo 跑 Google + Bing 或 DDG（中文 query 9 / 10 / 10 条，都相关）[实测]；exa；WebSearch | 百度（用户 2026-09-27 定为不用）；bb 的搜索引擎 adapter（见"搜索引擎结果页"）；在 query 里写 `site:` 或域名（anysearch 结果会变成垃圾）[旧测] |

### 命令
- anysearch：`{"query": "大模型 风控 实践", "max_results": 10}`。多个角度一起搜用 `batch_search`：`{"queries": [{"query": "..."}, {"query": "..."}]}`，最多 5 条。
- exa：`{"query": "大模型 风控 实践", "numResults": 5}`
- neo 跑 Google / Bing / DDG：脚本见下文"搜索引擎结果页"。

### 返回什么
- anysearch：Markdown 格式，每条是 `### 标题` + `**URL**` + 1–3 句摘要，部分带 `date:`。单次最多 10 条，服务端耗时 2–3.5s。
- exa：每条包含 Title、URL、Published、Author、Highlights。Highlights 很长，5 条常见 1–2.5 万字。

### 坑
- exa 的中文结果容易集中在同一个站：09-26 的 5 条里有 4 条来自腾讯云开发者社区（同一场演讲的多篇转载）。
- anysearch 的摘要可能混进页面里的无关文字，不能直接当事实用 [旧测]。
- 两个工具的默认搜索都没有日期、域名、语言过滤参数 [旧测]。

### 本次验证
- 09-26 anysearch `大模型 风控 实践` → 10 条全部相关，来源分散（安全内参、InfoQ、知乎、阿里云、极客时间、腾讯云、CSDN、百度百科），3.5s。[实测]
- 09-26 exa 同一 query → 第 1 次 fetch failed，重试后成功，5 条相关，但 4 条来自同一个站。WebSearch → 9 条相关链接，附模型摘要。[实测]
- 09-27 neo 同一 query：Google 9 条、Bing 10 条、DDG 10 条，都是相关的技术文章（知乎、InfoQ、腾讯云、安全内参、CSDN 等），没有验证页。[实测]

## 英文网页 / 描述式检索

| 需求 | 首选 | 备选 | 别用 |
|---|---|---|---|
| 英文技术资料；"找一篇讲 X 的文章" | exa `web_search_exa`（把 query 写成对理想页面的描述） | anysearch `search`；neo Google / Bing / DDG；WebSearch | — |

### 命令
- exa：`{"query": "blog post comparing LLM agent evaluation benchmarks", "numResults": 5}`
- 分类写在 query 里：`category:company` / `people` / `news` / `publication` / `personal site`。写 `github`、`pdf`、`research paper`、`tweet` 无效，只会被当成普通关键词 [旧测，源码]。

### 返回什么
- exa 默认返回 10 条，每条带正文片段。`numResults: 30` 会超出 Claude Code 的单次输出上限，结果被存到文件 [旧测]。

### 坑
- exa 的 `Published` 不是发布日期：会被转载站污染 [旧测]，也可能是抓取时间（见"当天新闻"）；GitHub 结果里 fork 常排在原仓库前面 [旧测]。
- exa 遇到网络错误不会自动重试 [旧测，源码]。

### 本次验证
- 09-26 exa → 5 条都是"对比 agent 评测基准"的文章或综述（gravity.fast、maratyv.com、arXiv 综述、个人博客、symflower），正中需求。[实测]
- 09-26 anysearch 同一 query → 10 条，多数是泛泛介绍 LLM benchmark 的文章，还混进了 LinkedIn 帖子和排行榜页，偏题。[实测]
- 09-27 neo `LLM agent evaluation benchmark`：Google 9 条、Bing 10 条、DDG 10 条，都是 benchmark 综述、arXiv 综述、GitHub 列表，和 exa 的结果重合很多。[实测]

## 当天新闻

| 需求 | 首选 | 备选 | 别用 |
|---|---|---|---|
| 英文 / 国际当天新闻 | exa，query 里写 `category:news` 和日期 | anysearch `search` | — |
| 中文当天新闻 | anysearch `search`，query 里写日期 | exa `category:news`（中文没跑通过，效果 [UNKNOWN]）；WebSearch | — |

### 命令
- exa：`{"query": "category:news AI news September 26 2026", "numResults": 5}`
- anysearch：`{"query": "2026年9月26日 AI 新闻", "max_results": 10}`

### 返回什么
- exa：`Published` 是精确到毫秒的 UTC 时间戳，但**不一定是发布日期**：09-27 读 anthropic.com 和 news.un.org 两页，Published 是同一个时间戳，两页自己写的是 9 月 23 日 [实测]。日期以正文为准。正文片段带导语。
- anysearch：只有 `date: 13 hours ago` 这类相对时间，而且不是每条都有。

### 坑
- anysearch 的 `date:` 不等于发布日期：斯坦福 AI Index、NVIDIA GTC 这类常年更新的页面也会标"几小时前"。
- anysearch 的新闻结果会混进完全无关的页面（09-26 有一条是 Plano 市公共图书馆）。
- 两个工具都没有日期过滤参数，只能把日期写进 query。exa 要按日期过滤得先开启 `web_search_advanced_exa` [旧测]。
- 关键事实和日期都要回原文核对。

### 本次验证
- 09-26 exa `category:news` 英文 → 5/5 是当天的新闻（ABC、DW、the-decoder、France 24 等），主题一致；第 1 次 fetch failed，重试后成功。[实测]
- 09-26 anysearch 中文 → 10 条里 4 条是当天新闻（新浪 AI 热点小时报、卫星通讯社、YouTube 快讯、note.com），其余是常年更新的页面或无关页面。[实测]
- 09-26 exa `category:news` 中文 → 连续 3 次 fetch failed（网络原因），没拿到结果。[实测]

## 搜索引擎结果页（Google / Bing / DDG）

用户决定：Google、Bing、DDG 的结果页走 BrowserOS neo `run`，不走 bb-browser（2026-09-24）；不用百度（2026-09-27）。

| 需求 | 首选 | 备选 | 别用 |
|---|---|---|---|
| 要某个引擎的原始排序，或几个引擎对照看 | neo `run`（脚本见下；三个引擎中英文都跑过） | — | 百度（用户定为不用）；bb 的 4 个搜索引擎 adapter：`google/search`（摘要为空，时好时坏）、`bing/search`（只匹配第一个词）、`duckduckgo/search`（中文 0 条）[旧测]、`baidu/search`（百度不用了）。neo 跑同一个引擎中英文都正常、链接能拿到真实 URL，bb 版没有胜出的场景 |
| Google Scholar | 见 `academic.md` | — | — |

### 命令
先调 `name_session`。`run` 的参数写成 `{"agentName": "claude-code", "session": "<name_session 返回文字里 browseros-neo session: 后面的值>", "code": "<下面的脚本>"}`。单次 run 硬上限 30 秒，一次最多开约 5 个新页面。
```js
const q = encodeURIComponent('大模型 风控 实践');
const use = ['google', 'bing', 'ddg'];  // 只要其中几个，就删掉别的
const E = {  // [url, 等待的选择器, 在页面里执行的代码]
  google: ['https://www.google.com/search?q=' + q, '#search a h3',
    "return [...document.querySelectorAll('#search a h3')].map(h=>({t:h.textContent,u:h.closest('a')&&h.closest('a').href}))"],
  bing: ['https://www.bing.com/search?q=' + q, '#b_results > li.b_algo h2 a',  // 链接是 /ck/a?...&u=a1<base64url>，在页面里解码
    "const d=h=>{const m=/[?&]u=a1([^&]+)/.exec(h);if(!m)return h;try{return decodeURIComponent(escape(atob(m[1].replace(/-/g,'+').replace(/_/g,'/'))))}catch(e){return h}};return [...document.querySelectorAll('#b_results > li.b_algo h2 a')].map(a=>({t:a.textContent,u:d(a.href)}))"],
  ddg: ['https://duckduckgo.com/?q=' + q, 'article[data-testid="result"]',
    "return [...document.querySelectorAll('article[data-testid=\"result\"] a[data-testid=\"result-title-a\"]')].map(a=>({t:a.textContent,u:a.href}))"],
};
const T = Date.now(), ids = {}, out = {};
for (const k of use) ids[k] = await browser.pages.newPage(E[k][0]);
await Promise.all(use.map(async k => {
  await browser.wait(ids[k], {for: 'selector', value: E[k][1], timeout: 15000});
  out[k] = (await browser.evaluate(ids[k], {code: E[k][2]})).value;
  out[k + '_body'] = (await browser.evaluate(ids[k], {code: "return location.href.slice(0,60) + ' | ' + document.title + ' | ' + document.body.innerText.slice(0,150)"})).value;
}));
for (const k in ids) await browser.pages.close(ids[k]);
out._ms = Date.now() - T;
return out;
```

### 返回什么
- 每个引擎一个数组 `[{t, u}]`：标题 + URL，不含摘要（需要摘要就自己加选择器）。`<引擎>_body` 是地址、页面标题和正文开头，0 条时看它判断是验证页、空白页（`about:blank`）还是改版；`_ms` 是整个 run 的耗时。
- Google：09-27 中英文都是直链；09-26 拿到过不透明的 `https://www.google.com/goto?url=...`，打开后能否稳定跳到真实 URL [UNKNOWN]。广告在 `#search` 外面（`#tads`），"AI 概览"也不在 `#search a h3` 里，都不会混进结果 [实测]。
- Bing：原始链接是 `/ck/a?...&u=a1<base64url>` 跳转链接，脚本在页面里解成真实 URL（09-27 本脚本 20/20，另一版解码代码 20/20）[实测]。没看到广告项。
- DDG 普通版：直接给干净 URL，没看到广告项 [实测]。结果和 Bing 几乎一样（09-27 中文 10 条里 9 条相同，英文 8 条相同），想要不同的排序就跑 Google + 其中一个。
- 耗时（09-27）：三个引擎一次 run 共 9.5s（英文）；单引擎 2 个 query 一次 run：Google 3.3–6.6s，Bing 1.4–2.0s，DDG html 版 4.3s。某个引擎打不开时要等满 15s，一次 run 约 25s。

### 坑
- 代理上游断了时，neo 打开这三个引擎都停在 about:blank（百度照常）：`_body` 是 `about:blank`、0 条，就是这个原因，见"网络坏了" [实测]。时通时断时可能只有一部分引擎打开（09-27 08:10 一次 run：Google 9 条，Bing、DDG 0 条）；过几分钟重跑。
- Google 会间歇性出现 "Verifying your request" 验证页：09-26 中文 query 等了 14s 仍是验证页，0 条；09-27 中英文都没出。拿到 0 条先看 `_body`。
- Bing 的标题要用 `textContent`：后台 tab 里靠下的结果 `innerText` 是空字符串（09-27 英文 query 10 条里 6 条）[实测]。
- Bing 会改写中文 query（页面写着 "Including results for 大 模型 风险 控 实践"），结果仍然相关 [实测]。Bing 无视 `site:`：`site:v2ex.com Claude Code` 10 条全是站外，同一查询 Google、DDG 都是 10/10 站内，限定站点别用 Bing [实测，见 `dev-community.md`]。09-26 Bing 返回过一次空白页，09-27 没复现，原因 [UNKNOWN]。
- DDG 的 html 版 `html.duckduckgo.com/html/?q=` 不稳：中文 query 出过一次人机验证（"Select all squares containing a duck"），0 条；英文 10 条，但链接是 `//duckduckgo.com/l/?uddg=<编码后的 URL>` 跳转链接 [实测]。所以脚本用普通版。
- 选择器会随网站改版失效。失效时先用 `snapshot` 看页面结构。
- 只关自己开的页面。`browser.pages.list()` 里 `ownership` 不是自己的，一律不碰。

### 本次验证（2026-09-27）
- neo Google 中文 `大模型 风控 实践` → 9 条，6.6s，直链，没有验证页。[实测]
- neo Google 英文 `LLM agent evaluation benchmark` → 9 条，3.3s，直链，页面上 2 条广告没混进结果。[实测]
- neo Bing 中文 → 10 条，2.0s，跳转链接全部解出真实 URL；英文 → 10 条，1.4s，同上，6 条标题要靠 `textContent` 才拿到。[实测]
- neo DDG 普通版：中文 10 条、英文 10 条，都是干净直链，没有验证页（07:09–08:04 代理上游基本断着，这期间打开都停在 about:blank，08:05 恢复后测到）。[实测]
- neo DDG html 版：中文 → 人机验证，0 条（等满 15s）；英文 → 10 条，4.3s，`uddg=` 跳转链接能解出真实 URL。[实测]
- 上面的脚本原样跑（08:05 前后；中文那次是加 `_ms` 之前的版本，只差计时两行）：中文 Google 9 / Bing 10 / DDG 10；英文 Google 9 / Bing 10 / DDG 10，共 9.5s。所有 URL 都是真实地址，没有跳转链接，没有空标题。[实测]

## Wikipedia

| 需求 | 首选 | 备选 | 别用 |
|---|---|---|---|
| 找词条 | anysearch / exa 通用搜索 [旧测] | bb `wikipedia/search`（只有英文维基）[旧测] | — |
| 读词条全文（中文、英文） | exa `web_fetch_exa` | anysearch `extract`（约 50k 字截断，行内链接多）[旧测] | bb `wikipedia/summary`（只有导语段）[旧测] |

本次验证：exa fetch `zh.wikipedia.org/wiki/大型语言模型` → 正文干净，但行内的外文原名被去掉了（原文显示为"英語：）"）。[实测] 英文 `Web_scraping` 的结论是 [旧测]。

## 网络坏了：怎么判断、怎么兜底

| 需求 | 首选 | 备选 | 别用 |
|---|---|---|---|
| anysearch / exa 连续 fetch failed | 搜索用 WebSearch（服务端执行，见"坑"里的官方文档）；读正文用 neo（给原文，国内站照常；代理上游断了时境外站也打不开 [实测]，脚本见 `read-url.md`） | 搜索用 neo 跑 Google / Bing / DDG（上游断了时同样打不开）；读正文用 WebFetch 碰运气（断网时能不能用 [UNKNOWN]，见"坑"；会转述） | 继续重试 exa / anysearch |

### 判断
- 网络问题：anysearch 报 `fetch failed`，exa 报 `web_search_exa error: fetch failed`。每次约 45–55 秒才返回；三个并行调用一批约 60–78 秒 [实测]。
- 工具问题：anysearch 报 `extract_failed`；exa 报 `CRAWL_UNKNOWN_ERROR` / `SOURCE_NOT_AVAILABLE`，或者不报错只给标题一行；或者返回的是验证码页。重试没用，直接换工具。
- anysearch 还会报 `Service temporarily unavailable`，按网络问题处理，重试。[实测]
- 快速自检（Git Bash），两条都跑：
  - `curl -s -o /dev/null -m 12 -w "%{http_code} %{time_total}\n" https://api.exa.ai`：走环境变量代理 `127.0.0.1:63358`（reclaude 的端口）[实测]。MCP 走不走这条路 [UNKNOWN]。
  - `curl -s -o /dev/null -m 12 -x http://127.0.0.1:7890 -w "%{http_code} %{time_total}\n" https://www.google.com`：走系统代理（mihomo，注册表 `ProxyServer=127.0.0.1:7890`）。neo 是浏览器，用的是系统代理 [推断；09-27 几次 neo 的通断都和这条一致]；这条是 000，neo 大概率也打不开境外站。
  - 两条都换成 `https://www.baidu.com` 再跑一次：百度 200、境外 000 是代理上游断了；百度也超时是本机出口整体不通。

### 规则
- 每次调用 fetch failed 后原样重试最多 2 次（一共调 3 次）。还失败就切换：搜索用 WebSearch，读正文用 neo，不要再等。
- 网络故障往往一整段时间都在失败，之后又时好时坏：连续重试常常都失败，隔几分钟再试才成功。被验证的就是这个工具时，隔几分钟再试，别直接换。

### 坑
- 代理上游断了时 neo 也打不开境外站 [实测]：09-27 05:14–05:43 本机代理上游全断，05:44–05:55 时通时断。同一时刻 neo 开百度 175ms 成功，开 Google、code.claude.com 停在 about:blank；curl 百度 200，google、exa、anysearch 都是 000。07:09–08:04 又基本断着（07:31、08:00 前后各通过一小会儿）：curl 经 7890 全是 000，neo 开 Google、DDG 停在 about:blank，百度照常；08:05 恢复几分钟，08:10 又断。09-26 晚上维护测试时也断过约 31 分钟，bb、anysearch、neo 全失败，只有百度正常。这时搜索只剩 WebSearch。
- 两条代理不一定同时坏：09-26 一次约 4 分钟的故障（原记录的钟点时区不明，不写），curl（环境变量代理）连百度都超时，同时 neo 打开 Google Scholar、arXiv 都成功；09-27 约 07:00 curl 经 63358 访问 google 是 000，neo 紧接着打开了 Google、Bing、DDG；07:05 反过来，经 7890 是 000、经 63358 是 200 [实测]。
- WebFetch 断网时能不能用 [UNKNOWN]，证据相反：09-27 断网期间一组读到了 code.claude.com，另一组连 example.com 都报 "Unable to verify if domain ... is safe to fetch"；07:24 WebFetch 读到了 claude.com 的文档页，紧接着 curl 访问 claude.com 经 7890 超时、经 63358 立即被拒（000）；`dev-community.md` 也记过断网时 linux.do 报同一句。文档（claude.com/docs/third-party/claude-desktop/web-tools）说 Claude Desktop 的 Web Fetch 在用户本机执行，Claude Code 的 WebFetch 抓之前还要问 `api.anthropic.com` 这个域名在不在黑名单，问不通就拒绝，报的应该就是这句（官方文档，未实测验证）。本机 CLI 的 WebFetch 走哪条网络 [UNKNOWN]。别把它当可靠备选。
- WebSearch 标注为 US-only，只返回链接和模型写的摘要，没有原始片段；不过 09-26 中文 query 也给了 9 条相关结果。
- WebFetch 会转述：让它逐字给出 arXiv 摘要，它从第二句起还是改写了，需要原文时用 neo。读知乎返回 403 [旧测]；不能访问需要登录的页面和 localhost。

### 本次验证
- 09-26：exa 调用 14 次，8 次 fetch failed；anysearch 8 次，3 次 fetch failed（`get_sub_domains` 连续 3 次）。全部是网络原因。[实测]
- 09-26 晚上（维护测试）：exa、anysearch 大部分调用前 1–3 次 `fetch failed`，每次约 47–57 秒；exa fetch 连续 3 次失败，隔约 9 分钟第 4 次成功。同时段 curl 百度 200（0.09s），api.exa.ai 12s 超时。[实测]
- 09-27：见上面"坑"的前三条。MCP 每次 fetch failed 约 45–55s，断网时三个并行调用一批约 60–78s。[实测]
