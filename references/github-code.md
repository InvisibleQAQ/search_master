# GitHub 与代码

> 最后验证：2026-09-26。标记：[实测] 本次跑过；[旧测] 引自 2026-09-24 调研；[UNKNOWN] 没查清。
> 本机网络不稳：同一分钟内 MCP（anysearch/exa/context7，走 Node fetch）和 gh（走 https_proxy）会各自失败，互不同步。任一工具报 `fetch failed` / `TLS handshake timeout`，先原样重试 1 次，再换下一个工具。

| 需求 | 首选 | 备选 | 别用 |
|---|---|---|---|
| 找仓库（只有功能描述） | exa `web_search_exa` | anysearch 通用搜索（最后备选） | bb-browser（没有 github 搜索 adapter） |
| 找仓库（有关键词 / 要按 star 排） | `gh search repos <词1> <词2> --sort stars` | exa | 整句自然语言丢给 gh |
| 仓库元数据（star、更新时间、issue 数） | `gh api repos/<o>/<r> --jq ...` | anysearch `extract` 读 `api.github.com/repos/<o>/<r>` | bb `github/repo`（字段全 null）；exa fetch（旧快照） |
| issue 列表 | bb `github/issues` [旧测] | `gh api repos/<o>/<r>/issues` [UNKNOWN 未测] | — |
| 读 README | anysearch `extract` 读 raw URL | exa fetch（可能是旧缓存） | bb `github/repo`（不返回 README） |
| 理解仓库架构 | deepwiki `ask_wiki_question` | semble 搜远程仓库（定位到文件行） | — |
| 找代码真实用法（跨仓库） | `gh search code` | anysearch `code.snippet`（带行号和固定到 commit 的链接，一个文件里的多处命中聚在一条）[实测] | — |
| 在已知仓库里找实现 | semble `search` | deepwiki | — |
| 库 / 框架 API 文档 | context7 | anysearch `code.doc`（混进通用网页）；WebFetch 官方文档页 | — |
| npm 搜包 | bb `npm/search` | — | — |
| PyPI 包详情 | bb `pypi/package` | — | — |
| PyPI 搜包 | [UNKNOWN] 没有验证过能用的 | — | bb `pypi/search`（静默返回 0 条） |

## 找仓库
### 命令
exa（语义发现，查询写成"想要的页面长什么样"）：
```json
{"query": "GitHub repository: browser automation for AI agents with logged-in sessions", "numResults": 5}
```
gh（关键词 + star 排序，Bash 里跑；只读）：
```bash
gh search repos browser agent login --sort stars --limit 5 --json fullName,stargazersCount,pushedAt,isFork,description
```
### 返回什么
- exa：每条 = 仓库 URL + README 大段 highlights，没有 star 数。[实测]
- gh：JSON 数组，含 star、最后 push 时间、是否 fork。[实测]
### 坑
- exa 5 条都相关，但目标原仓库 epiral/bb-browser 没进前 5；fork 会和原仓库并列出现（BUNotesAI/agent-browser-session 是 vercel-labs/agent-browser 的 fork）。[实测]
- exa 会返回 GitHub 镜像域名（`download.plaud.ai/arDaraz/...`），链接要改回 `github.com/<o>/<r>` 再用。[实测]
- exa 5 条结果约 10k 字，很占上下文；numResults 别开大。[实测]
- gh：把整句放进一个带空格的参数，会被加引号当成精确短语；多个词分开传是 AND。6 个词的自然语言查询返回 `[]`。只用 2-3 个关键词。[实测]
- gh 按 star 排序会混进无关高星仓库（`CNTRUN/Termux-command`），要看 description 过滤。[实测]
- anysearch 通用搜索 5 条里只有 1 条是 github.com 仓库，其余是 github.io 页面、博客、gist。[实测]
- 搜到候选后一律用下面的 `gh api` 核对 star 和 isFork，别信搜索结果和博客里的数字。

## 仓库元数据
### 命令
```bash
gh api repos/epiral/bb-browser --jq '{full_name,description,stargazers_count,forks_count,open_issues_count,pushed_at,updated_at,language,license:.license.spdx_id,topics,archived,fork}'
```
gh 不可用时（anysearch MCP）：
```json
{"url": "https://api.github.com/repos/epiral/bb-browser"}
```
issue 列表（Git Bash；repo 是位置参数）：
```bash
bash C:/Users/18368/Desktop/00_myCode/43_search_master/scripts/bb.sh github/issues epiral/bb-browser
```
### 返回什么
- gh api：一行干净 JSON，约 1 秒。[实测]
- anysearch extract：GitHub API 原样 JSON，数值和 gh 一致（stars 6232），但约 7k 字里大半是 `*_url` 样板。[实测]
- bb `github/issues`：30 条（number、title、state、labels、comments、created_at、is_pr）。[旧测]
### 坑
- 看"最近有没有人维护"用 `pushed_at`，不要用 `updated_at`：本次 updated_at=2026-09-25，pushed_at=2026-05-29（被 star 之类的动作刷新）。[实测]
- `open_issues_count` 包含未关闭的 PR。
- bb `github/repo` 仍然坏：stars/forks/language/topics 全 null，license 只返回 "LICENSE"，没有 README。[实测]
- bb `github/repo` 前两次分别报 `Cannot find default execution context`（27s）和 `TypeError: Failed to fetch`，第 3 次才跑通；原因 [UNKNOWN]。[实测]
- bb `github/issues` 固定 per_page=30，不能翻页。[旧测]
- 只做只读调用：不要跑 `github/fork`、`github/issue-create`、`github/pr-create`、`bb-browser star`，gh 也只用 `gh api`（GET）和 `gh search`。

## 读 README
### 命令
```json
{"url": "https://raw.githubusercontent.com/epiral/bb-browser/HEAD/README.md"}
```
（工具：`mcp__anysearch__extract`。`HEAD` 自动指向默认分支，不用猜 main 还是 master。）
### 返回什么
原样 Markdown，代码块、表格、换行都保留，`title` 为空字符串。[实测]
### 坑
- 文件名大小写和后缀不固定（`readme.md`、`README.rst`），404 时先用 `gh api repos/<o>/<r>/readme --jq .name` 查真实文件名。[UNKNOWN 未测]
- 读 `github.com/<o>/<r>` 页面本身会把代码块和表格压成一行，别用。[旧测]
- exa fetch 带仓库元数据，但 README 和 star 数可能是旧快照（抓到过旧版 README、旧 star 6053）。[旧测]
- README 不等于源码现状：README 仍写 `--mcp` 模式，但 0.14.2 发布包里没有任何 MCP 代码，`bb-browser --mcp` 只打印帮助就退出（09-24 读 dist 源码核实，上游 issue #235）。deepwiki 照 README 说有 MCP 模式，同样是错的。关键结论要看源码或发布包。[旧测]

## 理解仓库架构
### 命令
deepwiki（问答）：
```json
{"repoName": "epiral/bb-browser", "question": "How is the code organized? Describe the architecture: CLI, daemon, how site adapters are loaded and executed."}
```
先看目录：`mcp__deepwiki__read_wiki_structure` `{"repoName": "epiral/bb-browser"}`
semble（定位到具体文件和行）：
```json
{"query": "executeSiteAdapter evaluate adapter script in tab", "repo": "https://github.com/epiral/bb-browser", "top_k": 3, "max_snippet_lines": 4}
```
### 返回什么
- deepwiki：分层架构说明 + mermaid 图，点到函数名（`getAllSites`、`executeSiteAdapter` 在 `packages/daemon/src/site-adapter.ts`）。[实测]
- semble：file_path + 行号 + 片段；本次命中 `packages\daemon\src\site-adapter.ts:183`，和 deepwiki 说法吻合。[实测]
### 坑
- deepwiki 只覆盖已索引的公开仓库，没索引时返回 `Repository not found. Visit https://deepwiki.com/<o>/<r> to index it`。[旧测]
- deepwiki 是 AI 基于 wiki 的总结，函数名和路径要用 semble 或 raw 文件核对。
- semble 首次调用要 git clone，限时 60 秒；本次 bb-browser（592 KB）第一次就超时，重试成功。[实测]
- semble 查询写函数名 / 类名比写自然语言准：自然语言查 bb-sites 返回的都是低分无关片段（score 约 0.008）。[实测]
- semble 返回的 file_path 是 Windows 反斜杠，拼 GitHub URL 时要换成 `/`。[实测]

## 找代码真实用法
### 命令
gh（跨全 GitHub，需要登录；本机 gh 已登录）：
```bash
gh search code "page.route" "fulfill" --language typescript --limit 5 --json repository,path,url,textMatches --jq '.[] | {repo:.repository.nameWithOwner, path, url, frag:.textMatches[0].fragment}'
```
其他过滤：`--repo <o>/<r>`、`--filename <名>`、`--extension ts`、`--owner <o>`。
anysearch `code.snippet`：
```json
{"query": "page.route route.fulfill mock response", "domain": "code", "sub_domain": "code.snippet", "sub_domain_params": {"lang": "TypeScript"}, "max_results": 5}
```
可选参数（`get_sub_domains` 本次返回）：`lang`、`path`（如 `src/components/`）、`repo`（如 `facebook/react`）。
### 返回什么
- gh：repo、path、固定到 commit 的 blob URL、`textMatches` 代码片段（不带行号）。3 条都是真实的 `route.fulfill` 用法。[实测]
- anysearch：`github.com/<o>/<r> / .../file.ts:59` 格式，带 `L59:` 行号和固定到 commit 的 blob URL；同一个文件里的多处命中拼在一条里。要 5 条返回 3 条，2.0 秒。[实测]
### 坑
- gh 的多个查询词是 AND；不写 `--json` 只给路径，看不到代码。[实测]
- gh 的 code search 限流额度、是否支持正则：[UNKNOWN]（查 rate_limit 时 TLS 超时，没拿到）。
- anysearch `code.snippet` 上午 3/3 `fetch failed`（本机网络整段不通），下午网络恢复后一次成功；3 条都是真实的 `route.fulfill` 用法（mastra、OpenMAIC、BusinessOS 的 e2e 测试）。[实测]
- `code.snippet` 返回的条数可能比 `max_results` 少（要 5 回 3）。[实测]
- `code.snippet` 是代码行搜索，不是仓库搜索，别拿它找"有哪些仓库做 X"。[旧测]

## 库 / 框架 API 文档
### 命令
```json
{"libraryName": "Playwright", "query": "page.route mock network response with route.fulfill"}
```
（`mcp__context7__resolve-library-id`，拿到 `/org/project` 后调 `mcp__context7__query-docs` `{"libraryId": "<返回的 ID>", "query": "<单一主题>"}`；不要猜 ID。）
备选 anysearch `code.doc`：
```json
{"query": "how to use page.route to intercept network requests", "domain": "code", "sub_domain": "code.doc", "sub_domain_params": {"library": "playwright"}, "max_results": 3}
```
### 返回什么
- context7 `resolve-library-id`：返回候选列表（ID、代码片段数、来源信誉、benchmark 分、版本号）。Playwright 有 5 个候选，选 `/microsoft/playwright`（High，6873 个片段，版本 v1.51–v1.63）。[实测]
- context7 `query-docs`：官方文档片段 + 多语言代码示例，每段都注明出处（`github.com/microsoft/playwright/blob/main/docs/src/...`），还有 `Route.fulfill` 的完整参数表。质量好。[实测]
- `code.doc`：第 1 条是官方文档片段，后面混进 StackOverflow、dev.to 等通用网页，不报错。[旧测]
### 坑
- context7 走本机网络：上午 3/3 `TypeError: fetch failed`（和 anysearch、exa 同一段时间不通），下午网络恢复后一次成功。失败 2 次就换备选。[实测]
- 同一个库常有多个候选 ID（官方仓库、官网、devdocs、fork），选官方仓库、代码片段多、信誉 High 的那个。[实测]
- 本机网络全坏时，用 WebFetch 读官方文档页（服务端执行，不受本机网络影响，但是小模型转述，不是原文）。[旧测]
- context7 查询会发到外部 API，不要带私有代码或密钥。

## npm / PyPI
### 命令（Git Bash）
```bash
bash C:/Users/18368/Desktop/00_myCode/43_search_master/scripts/bb.sh npm/search playwright 5
bash C:/Users/18368/Desktop/00_myCode/43_search_master/scripts/bb.sh pypi/package requests
```
### 返回什么
- `npm/search`：name、description、url；5 条相关（playwright、@playwright/mcp、@playwright/cli 等）。[实测]
- `pypi/package`：name、version（2.34.2）、summary、license、requires_python、classifiers、project_urls（含 Source 仓库链接）、requires_dist。[实测]
### 坑
- `npm/search` 的 `version` 全是 null（页面选择器失效）；版本号要另查。[实测]
- `npm/search` 第一次报 `Cannot find default execution context`（27s），重试 0.6s 成功。[实测]
- `pypi/package` 单次 25 秒，慢，原因 [UNKNOWN]。[实测]
- `pypi/search` 静默返回 `count: 0`：pypi.org 搜索页返回 `<title>Client Challenge</title>`（JS 质询），adapter 不报错。别用。[实测]
- npm 包详情可试 `npm view <pkg> version description repository --json`，PyPI 可试 anysearch `extract` 读 `https://pypi.org/pypi/<name>/json`：都 [UNKNOWN 未测]。

## 本次验证
- exa 搜仓库，第 1 次 `fetch failed`，重试 → 5 条全是 GitHub 仓库，无 star，bb-browser 不在前 5，1 条镜像域名。
- anysearch 通用搜仓库，第 1 次 `fetch failed`，重试 → 5 条 2965ms，只有 1 条 github.com 仓库。
- `gh search repos` 整句（一个参数）→ TLS 超时；重试时 6 个词分开传 → `[]`，783ms。
- `gh search repos browser agent login --sort stars` → 5 条 5.7s，epiral/bb-browser 第 1（6232 star）。
- `gh search repos "bb-browser"` → 5 条 973ms，原仓库第 1，bb-sites 第 2。
- `gh api repos/epiral/bb-browser` 第 1 次 TLS 超时，重试 942ms → stars 6232、forks 605、open_issues 83、pushed_at 2026-05-29。
- anysearch extract `api.github.com/repos/...` 第 1 次失败，重试 → 原样 JSON，数值和 gh 一致。
- anysearch extract raw README（HEAD）第 1 次失败，重试 → 原样 Markdown 完整。
- bb `github/repo` 3 次：execution context 错误 27.6s / Failed to fetch 3.7s / 成功 7.8s 但 stars 等全 null。
- deepwiki `ask_wiki_question` → 成功，架构说明具体到函数和文件；但它说 bb-browser 有 `--mcp` 模式，这和 0.14.2 发布包不符（见"读 README"的坑）。
- semble 搜 bb-browser：第 1 次 clone 超时 60s，重试 → 3 条，第 1 条 `site-adapter.ts:183 executeSiteAdapter`。
- semble 搜 bb-sites（自然语言查询）→ 3 条低分无关片段，工具本身可用。
- anysearch `get_sub_domains(code)` → `code.doc`（library 必填）、`code.snippet`（lang/path/repo）。
- anysearch `code.snippet` 上午 3 次全 `fetch failed`；下午重跑 `page.route route.fulfill mock response`（lang=TypeScript）→ 3 条，2.0 秒，全部相关。
- `gh search code "page.route" "fulfill" --language typescript` → 5 条带 commit blob URL；加 textMatches 第 1 次 TLS 超时，重试 4.8s → 3 条真实 `route.fulfill` 片段。
- context7 `resolve-library-id(Playwright)` 上午 3 次全 `TypeError: fetch failed`；下午重跑 → 5 个候选；`query-docs(/microsoft/playwright, page.route mock ... route.fulfill)` → 5 段官方文档，含 `Route.fulfill` 参数表。
- bb `npm/search playwright 5`：第 1 次 execution context 错误 27.7s，重试 0.62s → 5 条，version 全 null。
- bb `pypi/package requests` → 成功 25.3s。
- bb `pypi/search playwright` → 0.52s，`count: 0`；curl 搜索页 200，标题 `Client Challenge`。
