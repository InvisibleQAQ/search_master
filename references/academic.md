# 学术论文：发现 + 读全文

> 最后验证：2026-09-26。标记：[实测] 本次跑过；[旧测] 引自 2026-09-24 调研（`42_expert/搜索工具总览.md` 及其原始报告）；[UNKNOWN] 没查清。
> 测试目标：query `chain of thought prompting`；论文 arXiv `2201.11903`（Wei et al.，CoT）。
> anysearch 和 exa 走本机网络，网络故障的判断和兜底见 `web.md` 最后一节。

## 论文发现

| 需求 | 首选 | 备选 | 别用 |
|---|---|---|---|
| 按关键词找论文 | anysearch `academic.search`（不加 sort）和 exa 普通 query（不加 category）并行跑，合并去重。两边各只测过 1 个 query，谁更好还没定论 | neo Google Scholar | anysearch `academic.search` 加 `sort: cited_by_count:desc`（URL 和标题错配）[旧测] |
| 描述式找论文（如"证明 X 能提升 Y 的论文"） | exa 普通 query | anysearch `academic.search` | exa `category:research paper`（无效，只会被当成关键词）[旧测] |
| 要权威被引数，或按影响力挑论文 | neo Google Scholar（看 "Cited by N"） | anysearch 结果里的 `cited N times`（统计口径不同，数字偏低） | — |
| 找最新提交的预印本 | bb `arxiv/search`（按时间排序）[旧测] | — | anysearch `academic.preprint`（sort 不生效）[旧测] |
| 引用关系、参考文献 | anysearch `academic.citation`（`id` 必填，传 DOI，不带前缀）[旧测] | neo Google Scholar 的 "Cited by" 链接 | — |
| 生物医学文献 | anysearch `academic.biomedical`（没测过 [UNKNOWN]） | exa | — |
| 本机网络坏了 | neo Google Scholar | WebSearch | anysearch / exa |

### 命令
- anysearch 做垂直搜索前必须先调 `get_sub_domains`：`{"domains": ["academic"]}`，会返回 biomedical、citation、dataset、preprint、search 5 个 sub_domain 及其参数。然后：
  `{"query": "chain of thought prompting", "domain": "academic", "sub_domain": "academic.search", "sub_domain_params": {}, "max_results": 5}`
  可选过滤参数：`year_from` / `year_to`（四位年份）、`category`（如 `Computer Science`）、`min_citations`、`venue`（要和 S2 里的名字完全一致，如 `NeurIPS`）、`open_access`、`doi`。
- exa：`{"query": "chain of thought prompting paper", "numResults": 5}`。`category:publication` 能用，但先看下面的坑。
- neo Google Scholar（先调 `name_session`；`run` 的参数写成 `{"agentName": "claude-code", "session": "<上次结果 _meta 里的值>", "code": "<下面的脚本>"}`）：
```js
const id = await browser.pages.newPage('https://scholar.google.com/scholar?q=' + encodeURIComponent('chain of thought prompting'));
try { await browser.wait(id, {for: 'selector', value: '#gs_res_ccl_mid .gs_r, #gs_captcha_ccl', timeout: 15000}); } catch (e) {}
const r = await browser.evaluate(id, {code: "return {title: document.title, r: [...document.querySelectorAll('#gs_res_ccl_mid .gs_r.gs_or')].map(d=>{const a=d.querySelector('h3 a');const c=[...d.querySelectorAll('.gs_fl a')].find(x=>/Cited by|被引用/.test(x.innerText));return {t:(d.querySelector('h3')||{}).innerText,u:a&&a.href,cited:c&&c.innerText}})}"});
await browser.pages.close(id);
return r;
```

### 返回什么
- anysearch：每条是标题 + URL（多为 `doi.org/...`，也有 `arxiv.org/abs/...`）+ 摘要，或者只有"作者 (年份) — cited N times"。5 条耗时 2.4s，输出紧凑。
- exa：每条包含 Title、URL、Published、Author、Highlights（摘要加正文片段），5 条约 2 万字。
- neo Scholar：每条有标题、直链（NeurIPS、arXiv、ACL Anthology 等）和 "Cited by N"。一页 10 条，耗时 14s。

### 坑
- exa 加 `category:publication` 时，只有第 1 条是原文 PDF，其余 4 条的 URL 是 `exa.ai/library/publication/<id>`，不是出版方或 arXiv 的链接，没法直接拿去读原文或引用。要原始 URL 就去掉 category（09-24 不加 category 时返回的是 NeurIPS PDF、arXiv、ACM DL 等真实链接 [旧测]）。
- anysearch 的摘要格式不统一：有的给完整摘要，有的只有"作者 (年份) — cited N"。
- 各来源的被引数差距很大：CoT 原文 anysearch 给 2218，Google Scholar 给 39278，`academic.citation` 给过 383 [旧测]。要引用数以 Scholar 为准。
- anysearch 给的 DOI 可能是会议论文集的 DOI（`10.52202/068431-1800`），而不是 arXiv DOI（`10.48550/arXiv.2201.11903`）。
- Google Scholar 对自动化访问会弹验证码，频率上限 [UNKNOWN]；本次只调了一次，没有遇到。等待的选择器里已包含 `#gs_captcha_ccl`，返回 0 条时先看 title。
- bb `arxiv/search` 按编号搜索会返回 0 条 [旧测]。已知编号就直接读 abs 页（见下一节）。

### 本次验证
- anysearch `get_sub_domains(academic)` → 前 3 次 fetch failed（网络原因），网络恢复后第 4 次成功。[实测]
- anysearch `academic.search` 不加 sort → 5 条：CoT 原文排第 1（cited 2218），其余是 Auto-CoT、SCoT、THOR、CCoT，全部相关，2.4s。[实测]
- exa `category:publication chain of thought prompting` → 5 条都相关（原文 NeurIPS PDF + 3 篇综述或分析），但有 4 条是 exa.ai/library 链接。这个 query 此前连续 3 次 fetch failed。[实测]
- neo Google Scholar → 8 条（CoT 原文 Cited by 39278、Auto-CoT 1960 等），都是直链，14s；是在 exa 和 anysearch 全部 fetch failed 的那段时间里跑通的。[实测]

## 读全文

| 需求 | 首选 | 备选 | 别用 |
|---|---|---|---|
| arXiv 论文全文 | exa `web_fetch_exa` 读 `arxiv.org/pdf/<id>`，`maxCharacters: 200000` | neo 读 `arxiv.org/html/<id>v<N>`（正文加附录，不截断） | anysearch `extract` 读 `/pdf/`（不支持 PDF）[旧测]；WebFetch（会转述） |
| 只要标题、作者、摘要、版本历史 | anysearch `extract` / exa fetch 读 `arxiv.org/abs/<id>` [旧测] | WebFetch 读 abs 页（摘要会被改写） | — |
| 非 arXiv 的开放 PDF（NeurIPS、ACL 等） | exa fetch 读 PDF URL [UNKNOWN，只测过 arXiv] | neo 打开后读 | anysearch `extract` |
| 只要 5 万字以内的正文，不想让结果落盘 | anysearch `extract` 读 `arxiv.org/html/<id>v<N>` | — | — |

### 命令
- exa：`{"urls": ["https://arxiv.org/pdf/2201.11903"], "maxCharacters": 200000}`
- anysearch：`{"url": "https://arxiv.org/html/2201.11903v6"}`
- neo：
```js
const id = await browser.pages.newPage('https://arxiv.org/html/2201.11903v6');
try { await browser.wait(id, {for: 'selector', value: '.ltx_page_main', timeout: 20000}); } catch (e) {}
const r = await browser.evaluate(id, {code: "return (document.querySelector('.ltx_page_main')||document.body).innerText"});
await browser.pages.close(id);
return r;
```

### 返回什么
- exa 读 PDF：136,680 字，包括正文、References 和 Appendix A–H，表格会转成 Markdown 表。结果超出 Claude Code 的输出上限，会被存到 `tool-results/*.txt`，返回的是文件路径。
- neo 读 HTML：130,524 字，含附录，耗时 16.7s。返回值很大时 neo 会给文件路径（见 neo skill 的说明）。
- anysearch 读 HTML：约 50,000 字，截断在 References 中间，附录没有了。49KB 的输出同样会被存到文件。

### 坑
- 不是每篇 arXiv 论文都有 HTML 版（LaTeX 转换失败的只有 PDF）。`/html/` 返回 404 就改读 PDF。HTML 版的覆盖率 [UNKNOWN]。
- 本次只测了带版本号的 `/html/2201.11903v6`；不带版本号是否可用 [UNKNOWN]。
- exa fetch 走缓存：论文出了新版本时，可能拿到的还是旧版 [UNKNOWN]。
- WebFetch 读 abs 页时，即使要求逐字给出摘要，它从第二句起还是改写了。
- 全文十几万字，很占上下文。先对落盘文件 grep `Appendix` 或章节标题定位，再分段读。

### 本次验证
- exa fetch PDF（200000）→ 136,680 字，含 Appendix A/B/C…，结尾是附录里的示例题；结果被存到文件。与 09-24 的结果一致。[实测]
- anysearch extract `/html/2201.11903v6` → 50,350 字节，§1–§8 和致谢完整，截断在 References 里的 Raffel et al. 2020 条目，没有附录。[实测]
- neo `/html/2201.11903v6` → 130,524 字，含附录，16.7s；是在 exa 和 anysearch 网络故障期间跑通的。[实测]
- WebFetch `arxiv.org/abs/2201.11903` → 标题、9 位作者、v1–v6 版本历史和 DOI 都对，但摘要被改写了。[实测]
