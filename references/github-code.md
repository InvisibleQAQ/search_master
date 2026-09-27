# GitHub 与代码

> 最后验证：2026-09-27（找仓库、clone + semble、deepwiki、context7、WebFetch）；其余条目 2026-09-26。标记：[实测] 09-26 或 09-27 跑过（哪天跑的见文末"本次验证"）；[旧测] 引自 2026-09-24 调研；[UNKNOWN] 没查清。时间一律是本机时区（EDT，-04:00）。
> 本机网络不稳：MCP（anysearch/exa/context7/deepwiki，走 Node fetch）和 gh（走 https_proxy）会各自失败，互不同步。09-27 gh 共 28 次调用，20 次 `TLS handshake timeout`（每次 10 秒），成功的每次 5–10 秒。任一工具报 `fetch failed` / `TLS handshake timeout` / `The operation timed out.`，按 SKILL.md"网络"一条，原样重试最多 2 次（一共调 3 次），再换下一个工具。

| 需求 | 首选 | 备选 | 别用 |
|---|---|---|---|
| 找仓库（有关键词 / 要按 star 排） | `gh search repos <词1> <词2> --sort stars` | 换一组同义词再搜 | 整句自然语言丢给 gh；bb-browser（没有 github 搜索 adapter） |
| 找仓库（只有功能描述） | 先把描述压成 2–3 个关键词，再照上一行用 gh | exa `web_search_exa`；anysearch 通用搜索（最后备选） | 同上 |
| 仓库元数据（star、更新时间、issue 数） | `gh api repos/<o>/<r> --jq ...` | anysearch `extract` 读 `api.github.com/repos/<o>/<r>` | bb `github/repo`（字段全 null）；exa fetch（旧快照）；WebFetch（`api.github.com` 被域名预检拒绝）[实测] |
| issue 列表 | `gh api --paginate repos/<o>/<r>/issues`（能翻页，`.pull_request` 过滤掉 PR）[实测] | bb `github/issues`（固定 30 条，不能翻页）[实测] | — |
| 最新版本 / 发布日期 | `npm view <pkg> version time --json`（npm 包）；`gh api repos/<o>/<r>/tags` [实测] | `gh api repos/<o>/<r>/releases/latest` | 只看 `releases/latest`（可能落后很多版）[实测] |
| 读 README | anysearch `extract` 读 raw URL | exa fetch（可能是旧缓存） | bb `github/repo`（不返回 README） |
| 仓库问答、理解架构 | deepwiki `ask_wiki_question` | clone 后用 semble 定位到文件行 | — |
| 在已知仓库里找代码、找实现 | `gh repo clone` 浅 clone 到原文目录，再 semble `search` 传本地路径 | deepwiki（只给概述，路径要核对） | semble `repo` 直接传 https URL（远程 clone 限时 60 秒）[实测] |
| 找代码真实用法（跨仓库） | `gh search code` | anysearch `code.snippet`（带行号和固定到 commit 的链接，一个文件里的多处命中聚在一条）[实测] | — |
| 库 / 框架 API 文档 | context7 | anysearch `code.doc`（混进通用网页）；WebFetch 官方文档页（只有部分站点能读） | — |
| npm 搜包 | bb `npm/search` | — | — |
| PyPI 包详情 | bb `pypi/package` | — | — |
| PyPI 搜包 | [UNKNOWN] 没有验证过能用的 | — | bb `pypi/search`（静默返回 0 条） |

## 找仓库
### 命令
gh（Bash 里跑；只读）。功能描述先压成 2–3 个关键词（领域名词、技术名），多个词分开传：
```bash
gh search repos agent skills --sort stars --limit 5 --json fullName,stargazersCount,pushedAt,isFork,description
```
压不出关键词、换两组词都搜不到时才用 exa（查询写成"想要的页面长什么样"）：`{"query": "GitHub repository: browser automation for AI agents with logged-in sessions", "numResults": 5}`
### 返回什么
- gh：JSON 数组，含 star、最后 push 时间、是否 fork。`agent skills` 5 条 5.4 秒。[实测]
- exa：每条 = 仓库 URL + README 大段 highlights，没有 star 数，5 条约 10k 字。[实测]
### 坑
- gh：把整句放进一个带空格的参数，会被加引号当成精确短语；多个词分开传是 AND。6 个词的自然语言查询返回 `[]`。只用 2-3 个关键词。[实测]
- gh 按 star 排序会混进只沾边的高星仓库：`agent skills` 第 5 是 Snailclimb/JavaGuide（Java 面试指南），`browser agent login` 混进 `CNTRUN/Termux-command`。要看 description 过滤。[实测]
- exa 会把 fork 和原仓库并列返回，还会给镜像域名（`download.plaud.ai/arDaraz/...`），链接要改回 `github.com/<o>/<r>`；目标原仓库可能不在前 5。[实测]
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
issue 列表（自动翻页；`is_pr` 用来区分 PR）：
```bash
gh api --paginate 'repos/epiral/bb-browser/issues?state=open&per_page=100' --jq '.[] | {number,title,is_pr:(.pull_request!=null),comments,created_at,labels:[.labels[].name]}'
```
最新版本：三个口径可能对不上，都查：
```bash
npm view bb-browser version time --json      # 用户实际装到的版本（慢，约 25 秒）
gh api 'repos/epiral/bb-browser/tags?per_page=5' --jq '.[].name'
gh api repos/epiral/bb-browser/releases/latest --jq '{tag_name,published_at}'
```
### 返回什么
- gh api：一行干净 JSON；网络好时约 1 秒，09-27 成功的每次 5–10 秒。[实测]
- anysearch extract：GitHub API 原样 JSON，数值和 gh 一致（stars 6232），但约 7k 字里大半是 `*_url` 样板。[实测]
- gh api issues：83 条（62 issue + 21 PR）一次拿全，985ms。[实测]
- bb `github/issues`：30 条（number、title、state、labels、comments、created_at、is_pr）。[旧测]
### 坑
- 看"最近有没有人维护"用 `pushed_at`，不要用 `updated_at`：09-26 updated_at=2026-09-25，pushed_at=2026-05-29（被 star 之类的动作刷新）。[实测]
- `open_issues_count` 包含未关闭的 PR。
- bb `github/repo` 仍然坏：stars/forks/language/topics 全 null，license 只返回 "LICENSE"，没有 README；前两次分别报 `Cannot find default execution context` 和 `TypeError: Failed to fetch`，原因 [UNKNOWN]。[实测]
- bb `github/issues` 固定 per_page=30，不能翻页；09-26 2 次都报 `Cannot find default execution context`（排队串行也一样）。[实测]
- 版本号三个口径可能对不上：bb-browser 的 npm latest 是 0.14.2（2026-05-29），git tag 最新是 v0.14.0，GitHub Releases 最新是 0.11.6（2026-05-11）。只查 `releases/latest` 会得出错误结论。[实测]
- 只做只读调用：不要跑 `github/fork`、`github/issue-create`、`github/pr-create`、`bb-browser star`；gh 只用 `gh api`（GET）、`gh search` 和 `gh repo clone`（只 clone 到原文目录）。

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
- README 不等于源码现状：README 仍写 `--mcp` 模式，但 0.14.2 发布包里没有任何 MCP 代码，`bb-browser --mcp` 只打印帮助就退出（09-24 读 dist 源码核实，上游 issue #235）。关键结论要看源码或发布包。[旧测]

## 仓库问答（deepwiki）
### 命令
```json
{"repoName": "epiral/bb-browser", "question": "How is the code organized? Describe the architecture: CLI, daemon, how site adapters are loaded and executed."}
```
（`mcp__deepwiki__ask_wiki_question`。先看目录：`mcp__deepwiki__read_wiki_structure` `{"repoName": "epiral/bb-browser"}`。）
### 返回什么
分层架构说明 + mermaid 图，点到函数名（`getAllSites`、`executeSiteAdapter` 在 `packages/daemon/src/site-adapter.ts`，和 semble 定位的一致）。[实测]
### 坑
- 会报 `The operation timed out.`：这是传输层超时，不是仓库没索引；`ask_wiki_question`、`read_wiki_structure` 都遇到过，原样重试第 3 次成功。[实测]
- 没索引的仓库返回 `Repository not found. Visit https://deepwiki.com/<o>/<r> to index it`。[旧测]
- 目录结构可能不全：它说 anthropics/skills 的 skill-creator 有 SKILL.md、scripts/、references/、assets/，漏了 agents/、eval-viewer/、LICENSE.txt（gh api 和 clone 后 `ls` 都核对过）。要完整文件列表就 clone 后 `ls`。[实测]
- 它是 AI 基于 wiki 的总结，会照抄 README 里过时的说法（说 bb-browser 有 `--mcp` 模式，见"读 README"）。函数名和路径要用 semble 或 raw 文件核对。[实测]

## 在仓库里找代码（clone + semble）
### 命令
先浅 clone 到自己的原文目录（Git Bash 里跑；外面包 `timeout`，Bash 工具超时只会转后台、不杀进程）：
```bash
timeout 120 gh repo clone anthropics/skills C:/Users/18368/AppData/Local/Temp/search-master/<任务名>-<子问题>/skills -- --depth 1
```
再用 semble 搜本地路径（`mcp__semble__search`）：
```json
{"query": "skill-creator validate SKILL.md frontmatter name description", "repo": "C:/Users/18368/AppData/Local/Temp/search-master/<任务名>-<子问题>/skills", "top_k": 5, "max_snippet_lines": 4}
```
查 README、SKILL.md 这类文档加 `"content": "docs"`，代码和文档一起查用 `"all"`。拿到 file_path 和行号就直接读 clone 里的文件，不要再 grep 一遍。
### 返回什么
- file_path（相对 `repo` 的路径，Windows 反斜杠）+ 起止行号 + 片段 + score。上面的查询第 1 条就是 `skills\skill-creator\scripts\quick_validate.py:13`（`validate_skill`，检查 frontmatter）。[实测]
- 首次调用现场建索引：anthropics/skills（浅 clone 16 MB、419 个文件）约 10 秒；同一路径、同一 content 再调直接复用索引。[实测]
### 坑
- `gh repo clone` 先 POST `api.github.com/graphql` 查仓库，这一步 TLS 超时就直接失败（10 秒），不会进入 git 阶段：连续 3 次这样，隔 3 分钟第 4 次 8.3 秒成功。[实测]
- clone 途中断网时 git 会卡满 300 秒才报 `Connection timed out`（直接 `git clone` 实测），所以要包 `timeout 120`；`timeout` 能按时杀掉卡在 API 阶段的 gh [实测]，卡在 git 阶段时 git 子进程会不会一起退出 [UNKNOWN]。
- 默认 content 是 `code`，只索引代码文件（anthropics/skills 只有 70 个，不含 .md）：查 SKILL.md 的 frontmatter 字段，默认 5 条全是 .py；加 `"content": "docs"` 第 1 条就是 `skills\skill-creator\SKILL.md:68`。[实测]
- 每种 content 各建一份索引（code 70 个文件、docs 118、all 194），第一次切换时各多等约 10 秒。索引落盘在 `%LOCALAPPDATA%\semble\Cache\<hash>\index*`，记录根路径和每个文件的 mtime。[实测]
- `repo` 传仓库根目录或子目录都行：传子目录只索引子目录，file_path 相对子目录，拼 GitHub URL 时要补前缀。[实测]
- 别让 semble 远程 clone（`repo` 传 https URL）：限时 60 秒，anthropics/skills 连续超时 3 次；远程仓库被 clone 到随机临时目录（索引里的根路径是 `Temp\tmpaob3urrn` 这类），所以换 `content` 就重新 clone 一次。[实测]
- 查询写函数名、类名或"做什么"的描述都行；score 是 0.01–0.03 量级的相对分，不能当相关性阈值（09-26 自然语言查 bb-sites 只返回 0.008 的无关片段）。[实测]
- 浅 clone 没有历史：要 `git log`、`git blame` 就别加 `--depth 1`。

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
可选参数（`get_sub_domains` 返回）：`lang`、`path`（如 `src/components/`）、`repo`（如 `facebook/react`）。
### 返回什么
- gh：repo、path、固定到 commit 的 blob URL、`textMatches` 代码片段（不带行号）。3 条都是真实的 `route.fulfill` 用法。[实测]
- anysearch：`github.com/<o>/<r> / .../file.ts:59` 格式，带 `L59:` 行号和固定到 commit 的 blob URL；同一个文件里的多处命中拼在一条里。要 5 条返回 3 条，2.0 秒。[实测]
### 坑
- gh 的多个查询词是 AND；不写 `--json` 只给路径，看不到代码。[实测]
- gh 的 code search 限流额度、是否支持正则：[UNKNOWN]（09-26、09-27 查 rate_limit 都 TLS 超时，没拿到）。
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
- `resolve-library-id`：候选列表（ID、代码片段数、来源信誉、benchmark 分、版本号）。Playwright 有 5 个候选，选 `/microsoft/playwright`（High，6873 个片段，版本 v1.51–v1.63）。[实测]
- `query-docs`：官方文档片段 + 多语言代码示例，每段注明出处（`github.com/microsoft/playwright/blob/main/docs/src/...`），还有 `Route.fulfill` 的完整参数表。质量好。[实测]
- `code.doc`：第 1 条是官方文档片段，后面混进 StackOverflow、dev.to 等通用网页，不报错。[旧测]
### 坑
- context7 走本机网络，会 `fetch failed`：09-26 上午 3/3 失败；09-27 `query-docs` 第 1 次失败、第 2 次成功。[实测]
- 同一个库常有多个候选 ID（官方仓库、官网、devdocs、fork），选官方仓库或官方文档站、代码片段多、信誉 High 的那个；Claude Code 选 `/websites/code_claude`（官方文档站）。[实测]
- WebFetch 服务端执行、不走本机代理，但不是所有站点都能读：`code.claude.com` 能读；`api.github.com` 被域名预检拒绝，`github.com/<o>/<r>` 超过 300 秒上限。只能当官方文档站的备选，不能当 gh 的备选；而且是小模型转述，不是原文。[实测]
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
- `npm/search` 的 `version` 全是 null（页面选择器失效）；版本号要另查。第一次报 `Cannot find default execution context`（27s），重试 0.6s 成功。[实测]
- `pypi/package` 单次 25 秒，慢，原因 [UNKNOWN]。[实测]
- `pypi/search` 静默返回 `count: 0`：pypi.org 搜索页返回 `<title>Client Challenge</title>`（JS 质询），adapter 不报错。别用。[实测]
- npm 包详情用 `npm view <pkg> version time dist-tags repository.url --json`：能用，但慢（23–29 秒）[实测]。PyPI 可试 anysearch `extract` 读 `https://pypi.org/pypi/<name>/json` [UNKNOWN 未测]。

## 本次验证
09-27（05:26–05:41 本机代理上游全断，之后到 05:55 左右时通时断；07:00–08:18 又是大部分时间不通，偶尔恢复几十秒到几分钟）：
- gh 两段共 28 次调用，20 次 `TLS handshake timeout`（每次 10.1 秒）；把 `https_proxy` 换成 mihomo 的 7890 端口也一样超时，问题不在本机代理这一层。
- `gh search repos agent skills --sort stars --limit 5` → 5.4 秒：obra/superpowers、mattpocock/skills、affaan-m/ECC、anthropics/skills（第 4）、Snailclimb/JavaGuide（无关）。
- `gh repo clone anthropics/skills <目录> -- --depth 1`：前 3 次 graphql TLS 超时（各 10 秒），07:05 第 4 次 8.3 秒成功，浅 clone 16 MB。07:14 直接 `git clone --depth 1` 卡 300 秒后连接超时。
- semble 本地路径：默认 content 约 10 秒建索引（70 个代码文件），第 1 条 `quick_validate.py:13`；同样的调用再来一次复用索引（index/ 没重写）；`docs`（118 个文件）第 1 条 `skill-creator\SKILL.md:68`；`all`（194 个）SKILL.md 和 quick_validate.py 排前 2；传 `skills/skill-creator` 子目录 → 9 个文件，第 1 条 `scripts\quick_validate.py:13`。
- semble 远程（05:43–05:52）：clone 60 秒超时 3 次；换 `content` 重新 clone；默认 content 下 SKILL.md 一次也没命中。
- deepwiki `ask_wiki_question`、`read_wiki_structure`：`The operation timed out.`，第 3 次成功；skill-creator 目录漏了 agents/、eval-viewer/、LICENSE.txt。
- context7 `resolve-library-id("Claude Code")` → 选 `/websites/code_claude`；`query-docs` 第 1 次 fetch failed，第 2 次成功。
- WebFetch：`api.github.com` 被域名预检拒绝；`github.com/<repo>` 超过 300 秒；`code.claude.com` 能读。

09-26：
- 找仓库：exa 第 1 次 fetch failed，重试 5 条全是仓库（无 star，bb-browser 不在前 5，1 条镜像域名）；anysearch 通用搜索 5 条只有 1 条 github.com；gh 6 个词分开传 → `[]`；`browser agent login --sort stars` → 5.7s，epiral/bb-browser 第 1；`"bb-browser"` → 973ms，原仓库第 1。
- 元数据：`gh api repos/epiral/bb-browser` 重试后 942ms（stars 6232、pushed_at 2026-05-29）；anysearch extract 读 api.github.com 和 raw README 都是第 2 次成功，数值和 gh 一致；bb `github/repo` 3 次：execution context 错误 27.6s / Failed to fetch 3.7s / 成功 7.8s 但字段全 null。
- `gh api --paginate .../issues` → 83 条 985ms；bb `github/issues` 2 次 execution context 错误；`npm view bb-browser version time --json` 23.0s，`dist-tags repository.url` 29.0s。
- deepwiki `ask_wiki_question(epiral/bb-browser)` → 架构说明到函数和文件，但照 README 说有 `--mcp`；semble 远程 bb-browser 第 1 次 clone 超时，重试命中 `site-adapter.ts:183`；bb-sites 自然语言查询只有低分无关片段。
- 代码用法：`gh search code "page.route" "fulfill"` → 5 条，加 textMatches 第 1 次 TLS 超时、重试 4.8s；anysearch `code.snippet` 上午 3/3 fetch failed，下午 3 条 2.0s 全相关。
- context7 Playwright：上午 3/3 fetch failed，下午 5 个候选，`query-docs` 返回 5 段官方文档，含 `Route.fulfill` 参数表。
- npm / PyPI：bb `npm/search` 第 1 次 execution context 错误、重试 0.62s，version 全 null；`pypi/package requests` 25.3s；`pypi/search` 0.52s `count: 0`（Client Challenge）。
