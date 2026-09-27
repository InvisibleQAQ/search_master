# 通用网页搜索、新闻、网络兜底

> 最后验证：2026-09-26。标记：[实测] 本次跑过；[旧测] 引自 2026-09-24 调研（`42_expert/搜索工具总览.md` 及其原始报告）；[UNKNOWN] 没查清。
> anysearch 和 exa 走本机网络，经常 `fetch failed`。先看文末"网络坏了"一节，分清是网络故障还是工具故障。
> 给一个 URL 拿正文、别的工具读不到的网页交给 neo：见 `read-url.md`。

## 中文网页搜索

| 需求 | 首选 | 备选 | 别用 |
|---|---|---|---|
| 中文综合、行业话题 | anysearch `search`（不带 domain） | neo 跑百度（能搜出公众号、百家号）或 DDG；exa；WebSearch | bb `bing/search`（只匹配第一个词）[旧测]；在 query 里写 `site:` 或域名（anysearch 结果会变成垃圾）[旧测] |

### 命令
- anysearch：`{"query": "大模型 风控 实践", "max_results": 10}`。多个角度一起搜用 `batch_search`：`{"queries": [{"query": "..."}, {"query": "..."}]}`，最多 5 条。
- exa：`{"query": "大模型 风控 实践", "numResults": 5}`
- neo 跑百度或 DDG：脚本见下文"搜索引擎结果页"。

### 返回什么
- anysearch：Markdown 格式，每条是 `### 标题` + `**URL**` + 1–3 句摘要，部分带 `date:`。单次最多 10 条，服务端耗时 2–3.5s。
- exa：每条包含 Title、URL、Published、Author、Highlights。Highlights 很长，5 条常见 1–2.5 万字。

### 坑
- exa 的中文结果容易集中在同一个站：本次 5 条里有 4 条来自腾讯云开发者社区（同一场演讲的多篇转载）。
- anysearch 的摘要可能混进页面里的无关文字，不能直接当事实用 [旧测]。
- 两个工具的默认搜索都没有日期、域名、语言过滤参数 [旧测]。

### 本次验证
- anysearch `大模型 风控 实践` → 10 条全部相关，来源分散（安全内参、InfoQ、知乎、阿里云、极客时间、腾讯云、CSDN、百度百科），3.5s。[实测]
- exa 同一 query → 第 1 次 fetch failed，重试后成功，5 条相关，但 4 条来自同一个站。[实测]
- neo 百度 → 12 条，其中有 2 篇 mp.weixin 公众号文章和新华网；neo DDG → 10 条，URL 干净，全部相关。[实测]
- WebSearch 同一 query → 9 条相关链接，附模型摘要。[实测]

## 英文网页 / 描述式检索

| 需求 | 首选 | 备选 | 别用 |
|---|---|---|---|
| 英文技术资料；"找一篇讲 X 的文章" | exa `web_search_exa`（把 query 写成对理想页面的描述） | anysearch `search`；neo Google；WebSearch | — |

### 命令
- exa：`{"query": "blog post comparing LLM agent evaluation benchmarks", "numResults": 5}`
- 分类写在 query 里：`category:company` / `people` / `news` / `publication` / `personal site`。写 `github`、`pdf`、`research paper`、`tweet` 无效，只会被当成普通关键词 [旧测，源码]。

### 返回什么
- exa 默认返回 10 条，每条带正文片段。`numResults: 30` 会超出 Claude Code 的单次输出上限，结果被存到文件 [旧测]。

### 坑
- exa 的 `Published` 会被转载站污染 [旧测]；GitHub 结果里 fork 常排在原仓库前面 [旧测]。
- exa 遇到网络错误不会自动重试 [旧测，源码]。

### 本次验证
- exa → 5 条都是"对比 agent 评测基准"的文章或综述（gravity.fast、maratyv.com、arXiv 综述、个人博客、symflower），正中需求。[实测]
- anysearch 同一 query → 10 条，多数是泛泛介绍 LLM benchmark 的文章，还混进了 LinkedIn 帖子和排行榜页，偏题。[实测]
- neo Google `LLM agent evaluation benchmark` → 9 条，6.6s，链接是不透明的 `/goto?url=`。[实测]

## 当天新闻

| 需求 | 首选 | 备选 | 别用 |
|---|---|---|---|
| 英文 / 国际当天新闻 | exa，query 里写 `category:news` 和日期 | anysearch `search` | — |
| 中文当天新闻 | anysearch `search`，query 里写日期 | exa `category:news`（中文这次没跑通，效果 [UNKNOWN]）；WebSearch | — |

### 命令
- exa：`{"query": "category:news AI news September 26 2026", "numResults": 5}`
- anysearch：`{"query": "2026年9月26日 AI 新闻", "max_results": 10}`

### 返回什么
- exa：`Published` 精确到秒（UTC），正文片段带导语。
- anysearch：只有 `date: 13 hours ago` 这类相对时间，而且不是每条都有。

### 坑
- anysearch 的 `date:` 不等于发布日期：斯坦福 AI Index、NVIDIA GTC 这类常年更新的页面也会标"几小时前"。
- anysearch 的新闻结果会混进完全无关的页面（本次有一条是 Plano 市公共图书馆）。
- 两个工具都没有日期过滤参数，只能把日期写进 query。exa 要按日期过滤得先开启 `web_search_advanced_exa` [旧测]。
- 关键事实要回原文核对：exa 的 `Published` 可能被转载站改写 [旧测]。

### 本次验证
- exa `category:news` 英文 → 5/5 是 2026-09-26 当天的新闻（ABC、DW、the-decoder、France 24 等），主题一致；第 1 次 fetch failed，重试后成功。[实测]
- anysearch 中文 → 10 条里 4 条是当天新闻（新浪 AI 热点小时报、卫星通讯社、YouTube 快讯、note.com），其余是常年更新的页面或无关页面。[实测]
- exa `category:news` 中文 → 连续 3 次 fetch failed（网络原因），没拿到结果。[实测] 注意：两边 query 语言不同，不是严格对照。

## 搜索引擎结果页（Google / 百度 / DDG / Bing）

用户 2026-09-24 已决定：Google、Bing、DDG 的结果页走 BrowserOS neo `run`，不走 bb-browser。百度这次用 neo 也跑通了；bb `baidu/search` 保留为备选 [旧测]。

| 需求 | 首选 | 备选 | 别用 |
|---|---|---|---|
| 要某个引擎的原始排序，或需要百度独有的结果 | neo `run`（脚本见下） | bb `baidu/search`、bb `duckduckgo/search`（仅英文）[旧测] | bb `google/search`（摘要为空，时好时坏）、bb `bing/search` [旧测] |
| Google Scholar | 见 `academic.md` | — | — |

### 命令
先调 `name_session`。`run` 的参数写成 `{"agentName": "claude-code", "session": "<name_session 返回文字里 browseros-neo session: 后面的值>", "code": "<下面的脚本>"}`。单次 run 硬上限 30 秒，一次最多开约 5 个新页面。
```js
const q = encodeURIComponent('大模型 风控 实践');
const E = {  // [url, 等待的选择器, 在页面里执行的代码]
  google: ['https://www.google.com/search?q=' + q, '#search a h3',
    "return [...document.querySelectorAll('#search a h3')].map(h=>({t:h.innerText,u:h.closest('a')&&h.closest('a').href}))"],
  ddg: ['https://duckduckgo.com/?q=' + q, 'article[data-testid="result"]',
    "return [...document.querySelectorAll('article[data-testid=\"result\"] a[data-testid=\"result-title-a\"]')].map(a=>({t:a.innerText,u:a.href}))"],
  baidu: ['https://www.baidu.com/s?wd=' + q, '#content_left h3',
    "return [...document.querySelectorAll('#content_left h3')].map(h=>{const c=h.closest('[mu]');return {t:h.innerText,u:c&&c.getAttribute('mu')}})"],
};
const ids = {}, out = {};
for (const k in E) ids[k] = await browser.pages.newPage(E[k][0]);
await Promise.all(Object.keys(E).map(async k => {
  try { await browser.wait(ids[k], {for: 'selector', value: E[k][1], timeout: 15000}); } catch (e) {}
  out[k] = await browser.evaluate(ids[k], {code: E[k][2]});
  out[k + '_body'] = await browser.evaluate(ids[k], {code: "return document.title + ' | ' + document.body.innerText.slice(0,150)"});
}));
for (const k in ids) await browser.pages.close(ids[k]);
return out;
```
Bing 的选择器是 `#b_results > li.b_algo h2 a`。它的链接是 `/ck/a?...&u=a1<base64url>`：去掉 `a1` 前缀后做 base64url 解码，得到真实 URL [旧测]。

### 返回什么
- 标题 + URL，不含摘要（需要摘要就自己加选择器）。`evaluate` 的返回值形如 `{page, value}`。
- Google 的链接是不透明的 `https://www.google.com/goto?url=...`。百度 `h3 a` 的 href 是 `baidu.com/link?url=` 跳转链接，真实 URL 在结果容器的 `mu` 属性里。DDG 直接给干净 URL。
- 耗时：3 个引擎放在一次 run 里共 21s（其中 Google 等待占 14s）；Google 单独跑 6.6s。

### 坑
- Google 会间歇性出现 "Verifying your request" 验证页：本次中文 query 等了 14s 仍是验证页，0 条；几分钟后换英文 query 就正常了。拿到 0 条先看 `_body`。
- Bing 本次返回空白页（title 为空，等 23s 后仍是 0 条），原因 [UNKNOWN]。09-24 的笔记里 Bing 是可用的。
- 百度有些结果是聚合卡片（"精选笔记"、知乎卡片），`mu` 是字符串 "null"，也没有链接，要过滤掉。
- 百度结果里常有公众号文章（`mp.weixin.qq.com/s?__biz=...` 临时链接），是发现公众号内容的便宜入口。
- 选择器会随网站改版失效。失效时先用 `snapshot` 看页面结构。
- 只关自己开的页面。`browser.pages.list()` 里 `ownership` 不是自己的，一律不碰。
- Google `/goto` 链接打开后能否稳定跳到真实 URL [UNKNOWN]。

### 本次验证
- neo 百度 `大模型 风控 实践` → 12 条（10 条有真实 URL），没有验证码。[实测]
- neo DDG 同一 query → 10 条，URL 干净。bb 的 DDG adapter 搜中文返回 0 条 [旧测]，neo 打开的完整版 DDG 搜中文正常。[实测]
- neo Google：中文 query → 验证页，0 条；英文 query → 9 条，6.6s。[实测]
- neo Bing 英文 → 空白页，0 条。[实测]

## Wikipedia

| 需求 | 首选 | 备选 | 别用 |
|---|---|---|---|
| 找词条 | anysearch / exa 通用搜索 [旧测] | bb `wikipedia/search`（只有英文维基）[旧测] | — |
| 读词条全文（中文、英文） | exa `web_fetch_exa` | anysearch `extract`（约 50k 字截断，行内链接多）[旧测] | bb `wikipedia/summary`（只有导语段）[旧测] |

本次验证：exa fetch `zh.wikipedia.org/wiki/大型语言模型` → 正文干净，但行内的外文原名被去掉了（原文显示为"英語：）"）。[实测] 英文 `Web_scraping` 的结论是 [旧测]。

## 网络坏了：怎么判断、怎么兜底

| 需求 | 首选 | 备选 | 别用 |
|---|---|---|---|
| anysearch / exa 连续 fetch failed | 搜索用 WebSearch（在 Anthropic 服务端执行）；读正文用 neo（给原文；代理上游节点断了时 neo 也打不开，见下面"坑"，脚本见 `read-url.md`） | 搜索用 neo 跑搜索引擎结果页；读正文用 WebFetch（neo 没连上时用；会转述） | 继续重试 exa / anysearch |

### 判断
- 网络问题：anysearch 报 `fetch failed`，exa 报 `web_search_exa error: fetch failed`。
- 工具问题：anysearch 报 `extract_failed`；exa 报 `CRAWL_UNKNOWN_ERROR` / `SOURCE_NOT_AVAILABLE`；或者返回的是验证码页。重试没用，直接换工具。
- 快速自检（Git Bash）：`curl -s -o /dev/null -m 12 -w "%{http_code} %{time_total}\n" https://www.baidu.com`。如果连百度都超时，说明是本机出口坏了，不是某个服务的问题。百度正常、`api.exa.ai` / `api.anysearch.com` 超时，是代理出口不通，同样按下面的规则切换。[实测]
- anysearch 还会报 `Service temporarily unavailable`，按网络问题处理，重试。[实测]

### 规则
- 每次调用 fetch failed 后原样重试最多 2 次（一共调 3 次）。还失败就切换：搜索用 WebSearch，读正文用 neo，不要再等。
- 网络故障往往一整段时间都在失败（本次持续了几分钟），之后又时好时坏：连续重试常常都失败，隔几分钟再试才成功。被验证的就是这个工具时，隔几分钟再试，别直接换。

### 坑
- neo 不一定能兜底：2026-09-27 本机代理的上游节点断网约 31 分钟，期间 bb、anysearch、neo 全部失败，只有百度正常。neo 和系统代理可能走同一个上游 [推断]。这时只剩 WebSearch / WebFetch（在服务端执行）。
- WebSearch 标注为 US-only，只返回链接和模型写的摘要，没有原始片段；不过本次中文 query 也给了 9 条相关结果。
- WebFetch 会转述：让它逐字给出 arXiv 摘要，它从第二句起还是改写了，需要原文时用 neo。读知乎返回 403 [旧测]；不能访问需要登录的页面和 localhost。

### 本次验证（2026-09-26 下午）
- exa：调用 14 次，8 次 fetch failed（全部是网络原因），6 次成功。[实测]
- anysearch：调用 8 次，3 次 fetch failed（`get_sub_domains` 连续 3 次），5 次成功。[实测]
- 13:35 在 Git Bash 里经环境变量代理 curl：api.exa.ai、api.anysearch.com、export.arxiv.org、www.baidu.com 全部 12s 超时。说明是本机出口整体不通，不是哪个服务坏了。[实测]
- 同一时段 neo 打开 Google Scholar 和 arXiv 都成功，WebSearch / WebFetch 也成功。约 13:39 之后 MCP 恢复。[实测]
- 单次失败要等多久，这次没测准 [UNKNOWN]；09-24 测到的是约 10.6s [旧测]。
- 晚上（维护测试）：exa、anysearch 大部分调用前 1–3 次 `fetch failed`，每次约 47–57 秒才返回；exa fetch 连续 3 次失败，隔约 9 分钟第 4 次成功。同时段 curl 百度 200（0.09s），api.exa.ai 12s 超时。[实测]
