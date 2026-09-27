# search-master 维护说明

这个仓库本身就是 skill 目录（`SKILL.md` 在根目录）。给 agent 用的内容在 `SKILL.md` 和 `references/`；本文件只给维护这个 skill 的人看。术语见 `CONTEXT.md`。

## 结构

- `SKILL.md`：入口。"谁来搜"（主 agent 只派搜索子 agent，不自己调工具）和派子 agent 的提示模板、路由表（平台 → 首选工具 → reference）、工具通则、硬规则、静默失败检查。前两块给主 agent 看，后面给搜索子 agent 看。控制在 100 行以内，现在 99 行，再加内容就把后面三块挪进 `references/`。
- `references/<平台>.md`：每个平台一个文件，统一结构：路由表（需求 | 首选 | 备选 | 别用）→ 命令 → 返回什么 → 坑 → 本次验证。每个文件 200 行以内。
- `references/read-url.md`：给一个 URL 拿正文，以及"读不到就交给 neo"：什么算读不到、neo 的读取脚本、返回格式。各平台 reference 读全文失败时都落到这里。原来在 `web.md` 里，因为 `web.md` 到了 200 行上限才拆出来。
- `references/workflow.md`：多源搜索流程（来源层、深度档位、五步里主 agent 和子 agent 的分工、bb 和 neo 的并发限制）。
- `scripts/bb.sh`：bb-browser 的唯一入口。有两种模式（adapter 和 eval），负责开和关自己的 tab、等页面加载、加全局锁、拒绝写操作。
- `scripts/bili_subtitle.sh`：B站字幕。通过 `bb.sh eval` 执行，不自己管 tab。
- `scripts/notify.py`：用 Server酱 推送提醒到用户手机，要用户动手时用（在 neo 里登录、过验证、启动 neo）。SendKey 从 `%USERPROFILE%\.codex\serverchan-notifier.env` 读（一行 `SERVERCHAN_SENDKEY=<key>`，带不带 BOM 都行），不进仓库。网络错误（含读响应时断开）重试 2 次，仍失败就输出一行 `{"ok": false, ...}`。

## 约定

- 提示模板和交回格式只写在 `SKILL.md`，`workflow.md` 引用它，不要再抄一份。
- 新脚本凡是要开 bb-browser tab，一律调用 `bb.sh eval`，不要再写一份开 tab、等加载、关 tab 的代码。
- 结论要带标记：[实测]、[旧测]、[源码]、[UNKNOWN]。改路由必须有实测证据，并写进对应文件的"本次验证"。
- reference 里的命令写完整路径 `C:/Users/18368/Desktop/00_myCode/43_search_master/scripts/...`，方便直接复制。仓库搬家时要全局替换这个路径。
- 改了某个平台的路由，要同步改 `SKILL.md` 路由表里的那一行。
- 密钥（Server酱 SendKey 等）只放在仓库外的文件里，脚本运行时读取。仓库有 GitHub 远程，任何文件里都不能出现 key。
- Server酱用的是会员账号，每天 1000 条（用户确认，2026-09-26），额度不是约束。规定一个子 agent 一次任务只推一条，是为了不刷屏。

## 重新验证

工具和网站都会变，每隔一段时间要重测一次：按平台分组开子 agent，每组读自己的 reference，把主路由和备选各跑一次，更新"本次验证"和日期。第一次完整验证是 2026-09-26，由 6 个子 agent 完成；同一天晚上又做了一次维护测试（静态检查、脚本行为、按 SKILL.md 派子 agent 的端到端场景），报告是 `../42_expert/搜索工具调研原始报告/search-master维护测试_2026-09-26.md`。更早的证据也在这个目录。

## 已知待办

- bb adapter 坏了或有 bug、需要写私有 adapter（放在 `~/.bb-browser/sites/`）的：
  - `twitter/user`：字段全空。
  - `twitter/tweets`：发串帖的账号返回 0 条（不读置顶帖 `inst.entry` 和串帖模块 `content.items[]`）；twitter 各 adapter 写死的兜底 queryId 已过期，见 `x.md`。
  - `github/repo`：stars 等字段全是 null。
  - `sogou/weixin`：公众号名和时间字段错位。
  - `zhihu/hot`：ID 精度丢失。
  - `weibo/comments`：点赞数恒为 0。
  - `npm/search`：version 为 null。
  - `pypi/search`：静默返回 0 条。
- B站字幕可以改写成私有 adapter `bilibili/subtitle`，取代 `bili_subtitle.sh`。
- `Cannot find default execution context` 的根因还没查清。bb.sh 的全局锁只挡住了并发这一个诱因：2026-09-26 晚上网络正常、排队串行时照样出现（`github/issues` 2/2），和站点有关。上游线索：bb-browser issue #41（adapter 报 `Failed to fetch`，同样的 fetch 用 eval 却正常）。`Daemon request timed out` 是另一回事：每次都出现在目标站很慢或代理断网的时候，是 bb daemon 的 30 秒上限，加 `BB_SETTLE` 没用。
- exa 的 `web_search_advanced_exa` 没开启（能按日期和域名过滤），开启方法见 `../42_expert/搜索工具总览.md` §5.2。
- neo 读 SPA：小红书、X 用 `browser.wait` 等正文选择器实测可用（超时返回 `{matched: false}`，不报错），其他 SPA 没测。
- neo `read` 的全文文件存在 BrowserOS 的版本目录下（`BrowserClaw\Application\<版本号>\.browseros\tool-output\`），升级后路径会变。
- 本机没有 Whisper，也没有 `GROQ_API_KEY`，没有字幕的音视频转不了文字。
