# search-master 维护说明

这个仓库本身就是 skill 目录（`SKILL.md` 在根目录）。给 agent 用的内容在 `SKILL.md` 和 `references/`；本文件只给维护这个 skill 的人看。术语见 `CONTEXT.md`。

安装：`~/.cc-switch/skills/search-master` 是指向本仓库的 junction（2026-09-27 建）。建好后要在 cc-switch 的 Skills 页扫描导入未登记的技能，并对 Claude 和 Codex 启用，cc-switch 才会把它链接到 `~/.claude/skills`、`~/.codex/skills`。改仓库就是改已安装的技能，不要换成复制。仓库搬家要重建这个 junction。不要在 cc-switch 里点"卸载"，它会对这个路径做 `remove_dir_all`，是否只删 junction、不删仓库，没在本机版本上验证过 [UNKNOWN]；要卸载就手动 `rmdir` 这个 junction。

bb-browser 私有 adapter：`~/.bb-browser/sites` 是指向本仓库 `adapters/` 的 junction（2026-09-27 建，`New-Item -ItemType Junction -Path $env:USERPROFILE\.bb-browser\sites -Target <仓库>\adapters`）。同名时私有目录优先于社区目录 `~/.bb-browser/bb-sites`（`bb-browser` 的 `dist/cli.js` 里 `getAllSites`，`bb.sh` 查找顺序也一样）。`bb-browser site list --json` 里 `source` 为 `local` 说明生效。仓库搬家同样要重建。

## 结构

- `SKILL.md`：入口，只放主 agent 要看的："谁来搜"（主 agent 只派搜索子 agent，不自己调工具）和派子 agent 的提示模板、路由表（平台 → 首选工具 → reference）。控制在 100 行以内，现在 62 行。
- `references/rules.md`：给搜索子 agent 的通用规则（路径、工具通则、硬规则、静默失败检查、结论标记）。原来是 `SKILL.md` 的后半，2026-09-27 挪出：主 agent 不调工具，用不到这些，放在 `SKILL.md` 里每次触发都白读。提示模板让子 agent 先读它、再读平台 reference；各平台 reference 说的"网络""时间""硬规则"都指这个文件。跨平台通用的规则只写在这里，不要抄进平台 reference。
- `references/<平台>.md`：每个平台一个文件，统一结构：路由表（需求 | 首选 | 备选 | 别用）→ 命令 → 返回什么 → 坑 → 本次验证。每个文件 200 行以内。
- `references/read-url.md`：给一个 URL 拿正文，以及"读不到就交给 neo"：什么算读不到、neo 的读取脚本、返回格式。各平台 reference 读全文失败时都落到这里。原来在 `web.md` 里，因为 `web.md` 到了 200 行上限才拆出来。
- `references/workflow.md`：多源搜索流程（来源层、深度档位、五步里主 agent 和子 agent 的分工、bb 和 neo 的并发限制）。
- `scripts/bb.sh`：bb-browser 的唯一入口。有两种模式（adapter 和 eval），负责开和关自己的 tab、等页面加载、加全局锁、拒绝写操作。
- `scripts/bili_subtitle.sh`：B站字幕。通过 `bb.sh eval` 执行，不自己管 tab。
- `adapters/<平台>/<命令>.js`：bb-browser 私有 adapter，覆盖社区同名 adapter 或补新命令，通过上面的 junction 生效。现有 `zhihu/hot`（ID 改从字符串字段取，修 19 位 ID 精度丢失）、`youtube/video`（页面变量缺失或不属于这个视频时，在页面里重拉 watch 页 HTML 解析；修 YouTube service worker 用缓存的 app shell 顶替 watch 页后只剩 9 个字段）。
- `scripts/notify.py`：用 Server酱 推送提醒到用户手机，要用户动手时用（在 neo 里登录、过验证、启动 neo）。SendKey 从 `%USERPROFILE%\.codex\serverchan-notifier.env` 读（一行 `SERVERCHAN_SENDKEY=<key>`，带不带 BOM 都行），不进仓库。网络错误（含读响应时断开）重试 2 次，仍失败就输出一行 `{"ok": false, ...}`。
- `evals/routing/`：description 的路由测试。`cases.json` 是 39 条用户消息和期望的第一个动作（`search-master`、相邻的 skill 或 `NONE`），`skills.txt` 是本机 skill 列表（名称 + description）的快照，`route_eval.py` 生成评判提示、给评判结果打分。用法见"重新验证"。

## 约定

- 提示模板和交回格式只写在 `SKILL.md`，`workflow.md` 引用它，不要再抄一份。
- 新脚本凡是要开 bb-browser tab，一律调用 `bb.sh eval`，不要再写一份开 tab、等加载、关 tab 的代码。
- 结论要带标记：[实测]、[旧测]、[源码]、[推断]、[UNKNOWN]。改路由必须有实测证据，并写进对应文件的"本次验证"。
- reference 里 bb 的耗时写两个数："adapter X 秒 / 实际 Y 秒"。adapter 耗时取 bb.sh stderr 那一行，实际等待含全局锁排队、开 tab、`BB_SETTLE`，两者能差出几十秒，只记前一个会误导。
- 日期和钟点一律写本机时区（美东；取时间的命令见 `references/rules.md`"工具通则"的"时间"）。子 agent 报的 UTC 时间要先换算。
- reference 里的命令写完整路径 `C:/Users/18368/Desktop/00_myCode/43_search_master/scripts/...`，方便直接复制。仓库搬家时要全局替换这个路径。
- 改了某个平台的路由，要同步改 `SKILL.md` 路由表里的那一行。
- 改 frontmatter 的 `description` 前后各跑一次路由测试（`evals/routing/`），候选版本不回退才换。description 是不带引号的 YAML 标量，里面不能出现"冒号+空格"：2026-09-27 写成 `Read-only: for ...` 后 frontmatter 解析失败，Claude Code 技能列表里的 description 只剩标题"Search Master" [实测]。`route_eval.py prompt` 会拦住这种写法。
- 修社区 adapter 或写新 adapter，一律放 `adapters/`，不要改 `~/.bb-browser/bb-sites`：那是社区仓库的 git clone，bb-browser 每次运行都会在后台 `git pull --ff-only`，本地改动要么挡住更新，要么被覆盖。覆盖社区版时在 `@meta` 的 `description` 里写清改了什么；社区版之后修好了，就删掉私有版。
- 密钥（Server酱 SendKey 等）只放在仓库外的文件里，脚本运行时读取。仓库有 GitHub 远程，任何文件里都不能出现 key。
- Server酱用的是会员账号，每天 1000 条（用户确认，2026-09-26），额度不是约束。规定一个子 agent 一次任务只推一条，是为了不刷屏。

## 重新验证

工具和网站都会变，每隔一段时间要重测一次：按平台分组开子 agent，每组读自己的 reference，把主路由和备选各跑一次，更新"本次验证"和日期。第一次完整验证是 2026-09-26，由 6 个子 agent 完成；同一天晚上又做了一次维护测试（静态检查、脚本行为、按 SKILL.md 派子 agent 的端到端场景），报告是 `../42_expert/搜索工具调研原始报告/search-master维护测试_2026-09-26.md`。更早的证据也在这个目录。第二次是 2026-09-27：在 Claude Code 里装好后，按 SKILL.md 派 8 个搜索子 agent 做冒烟测试，覆盖路由表所有平台；然后按用户的决定改路由（知乎、Reddit、X 不用 anysearch，V2EX、Linux.do 只用 neo，搜索引擎去掉百度，删掉小宇宙），由 5 个维护子 agent 实测后改 reference。证据只写进了各文件的"本次验证"，没有单独出报告。

路由测试（只在改 `description` 时跑）：`python C:/Users/18368/Desktop/00_myCode/43_search_master/evals/routing/route_eval.py prompt [候选 description 文件] > <临时目录>/prompt.txt`，派 2 个 `general-purpose` 子 agent，提示里只让它读这个文件、交回表格（不告诉它测的是哪个 skill）；表格存成文件后用 `route_eval.py score <文件>` 打分；新旧 description 各跑 2 次。评判子 agent 在本仓库里运行，能看到这个 CLAUDE.md，命中率的绝对值偏乐观，只用来比新旧 [推断]；它的系统提示里还带着 SKILL.md 当前的 description，测候选时两者不一致，所以候选写进 SKILL.md 之后要再跑一次作为最终验证。第一次是 2026-09-27（按 yao-meta-skill 做优化时）：旧 description 在基础 25 条上 25/25，在困难 14 条上 13/14（两次结果一样），错的是"帮我读一下这篇文章讲了什么 <URL>"被 browseros-neo 抢走，因为 neo 的 description 写着 any task that touches a website (open, read …)，而旧 description 没提"读给定链接"。补上"读给定 URL、文章、视频"和"发帖、点赞、登录、截图、存页面交给 browseros-neo"后，合并成 39 条跑 2 次都是 39/39，截图、存 PDF、点赞、发帖仍然交给 neo [实测]。用户点名搜索工具时（"用 exa 搜…"），评判选择直接调工具、不进 skill，`cases.json` 里这类用例的期望写成 `search-master|NONE`。

## 已知待办

- bb adapter 坏了或有 bug、需要写私有 adapter（放在 `adapters/`）的：
  - `twitter/user`：字段全空。
  - `twitter/tweets`：发串帖的账号返回 0 条（不读置顶帖 `inst.entry` 和串帖模块 `content.items[]`）；twitter 各 adapter 写死的兜底 queryId 已过期，见 `x.md`。
  - `github/repo`：stars 等字段全是 null。
  - `sogou/weixin`：公众号名和时间字段错位。
  - `zhihu/search`：`author` 带 `<em>` 高亮标签。
  - `weibo/comments`：点赞数恒为 0。
  - `npm/search`：version 为 null。
  - `pypi/search`：静默返回 0 条。
- B站字幕可以改写成私有 adapter `bilibili/subtitle`，取代 `bili_subtitle.sh`。
- `Cannot find default execution context` 的根因还没查清。bb.sh 的全局锁只挡住了并发这一个诱因：2026-09-26 晚上网络正常、排队串行时照样出现（`github/issues` 2/2），和站点有关。上游线索：bb-browser issue #41（adapter 报 `Failed to fetch`，同样的 fetch 用 eval 却正常）。2026-09-27 的新数据点：`duckduckgo/search` 出现 1 次；`hackernews/thread` 在断网、`BB_OPEN_URL` 指向的页面打不开时出现；`stackoverflow/search` 在网络正常时出现 1 次，重跑就好。`Daemon request timed out` 是另一回事：每次都出现在目标站很慢或代理断网的时候，是 bb daemon 的 30 秒上限，加 `BB_SETTLE` 没用。
- exa 的 `web_search_advanced_exa` 没开启（能按日期和域名过滤），开启方法见 `../42_expert/搜索工具总览.md` §5.2。
- neo 读 SPA：小红书、X 用 `browser.wait` 等正文选择器实测可用（超时返回 `{matched: false}`，不报错），其他 SPA 没测。
- neo `read` 的全文文件存在 BrowserOS 的版本目录下（`BrowserClaw\Application\<版本号>\.browseros\tool-output\`），升级后路径会变。
- 本机没有 Whisper，也没有 `GROQ_API_KEY`，没有字幕的音视频转不了文字。
