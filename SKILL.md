---
name: search-master
description: Picks the best-verified search or reading tool on this machine for each platform (anysearch, exa, bb-browser, BrowserOS neo, feedgrab, yt-dlp, gh, deepwiki, semble, context7, favbase, WebSearch/WebFetch) and runs multi-source research with cross-checking. Use when the user asks to search, look up, research, collect or verify information on the web or on 知乎、小红书、微博、微信公众号、X/Twitter、Reddit、Hacker News、Stack Overflow、V2EX、B站、YouTube、小宇宙、GitHub、arXiv/论文、LinkedIn、脉脉、牛客, stock quotes, CVEs, patents or laws, or says 搜一下、查一下、找资料、调研、深搜.
---

# Search Master

每个平台用实测效果最好的工具。命令、参数顺序、返回字段和坑都在 `references/<平台>.md`，只读当前任务用到的那几个。

## 谁来搜

搜索结果很长（exa 5 条就有 1–2 万字，字幕更长），全进主对话会挤爆上下文。所以：

- **主 agent 不调搜索工具，也不读 `references/<平台>.md`**，查一个事实也一样。用 Agent 工具派 `general-purpose` 子 agent 去搜（Explore 不能写文件），主 agent 只拿它的交回清单。
- 派几个：查事实派 1 个；调研、深搜、跨平台问题按 [references/workflow.md](references/workflow.md) 分层，2-4 个在同一条消息里并行派。
- 追问同一批结果时，用 SendMessage 找原来那个子 agent，不要重新派。
- **提示里说你是"搜索子 agent"时，你就是干活的**：直接按下文调工具，不要再派子 agent。
- 没有 Agent 工具的环境，主 agent 自己搜，交回格式照旧。

派子 agent 的提示照这个模板写，尖括号换成实际内容：

```text
你是 search-master 的搜索子 agent：直接调工具，不要再派子 agent。
任务：<子问题；用户给的约束：时间范围、语言、条数、要不要原文>
平台：<平台列表>
先读 C:/Users/18368/Desktop/00_myCode/43_search_master/SKILL.md 的"工具通则""硬规则""静默失败检查"，
再读 C:/Users/18368/Desktop/00_myCode/43_search_master/references/<路由表里对应的 reference，可能不止一个>，照里面的命令调。
MCP 工具第一次用之前，先 ToolSearch "select:<工具名>" 加载。
交回（不要贴原始结果）：
1. 每条一行：结论 | URL | 来源平台 | 日期 | 是否读过全文
2. 失败的工具：报错的、静默失败的（退回通用搜索、验证码页等），各写一句原因
3. 新线索：结果里出现的新人名、术语、链接
要原文（字幕、全文）时写进文件，只交回绝对路径和摘要；用户没指定位置就放 C:/Users/18368/AppData/Local/Temp/search-master/。
```

## 路由表

| 平台 / 需求 | 首选（细节和备选见 reference） | reference |
|---|---|---|
| 中文网页 | anysearch `search` | web.md |
| 英文网页、"找一篇讲 X 的文章" | exa `web_search_exa` | web.md |
| 当天新闻 | 英文用 exa + `category:news`；中文用 anysearch | web.md |
| Google / 百度 / DDG 结果页 | BrowserOS neo `run` | web.md |
| 给一个 URL 拿正文 | 普通文章用 exa fetch；要最新内容或 JSON 用 anysearch `extract`；SPA 用 neo | web.md |
| 论文发现、论文全文 | anysearch `academic.search` 和 exa 并行；PDF 用 exa fetch | academic.md |
| 知乎 | anysearch `zhihu` 类型（结果就是全文）；读指定一篇用 bb eval | zhihu.md |
| 小红书 | 只有 bb：`search` / `note` / `comments` | xiaohongshu.md |
| 微博 | bb `m_weibo/search`，长文用 `weibo/post` | weibo.md |
| 微信公众号 | feedgrab `mpweixin-so`；读链接用 exa fetch | wechat.md |
| X / Twitter | 搜索：bb top 和 anysearch `x_top` 并行；看最新、读帖子：只用 bb | x.md |
| Reddit | bb `reddit/search` + `reddit/thread` | reddit.md |
| HN、Stack Overflow、V2EX、Linux.do | HN 用 Algolia 接口；SO 用 exa 提问；V2EX 用 anysearch | dev-community.md |
| B站（含字幕） | bb；字幕用 `scripts/bili_subtitle.sh` | bilibili.md |
| YouTube（含字幕） | bb（tab 开在 watch 页）；字幕用 yt-dlp | youtube.md |
| 小宇宙播客 | bb `xiaoyuzhoufm/*` | podcast.md |
| GitHub、代码用法、库文档、npm / PyPI | gh、exa、deepwiki、semble、context7 | github-code.md |
| 人物、公司、脉脉、牛客、招聘 | exa `category:people` / `company`；脉脉、牛客用 neo | people-company.md |
| 行情、CVE、临床试验、专利、法律 | anysearch 垂直搜索；A 股实时价用 bb 雪球 | data-verticals.md |
| 我收藏过什么 | favbase | personal.md |
| 本机网络坏了 | WebSearch / WebFetch，或 neo | web.md 最后一节 |

reference 都在 `references/` 目录下。下文的 `scripts/` 指本 skill 目录下的 scripts（skill 加载时会给出 Base directory；本机是 `C:/Users/18368/Desktop/00_myCode/43_search_master`）。Bash 工具的当前目录不是 skill 目录，调用时要写完整路径。

## 工具通则

- **bb-browser 只通过 `scripts/bb.sh` 调用**，在 Bash 工具（Git Bash）里跑，PowerShell 会吞掉空字符串参数。
  - `bash scripts/bb.sh <platform/command> [位置参数...]` 跑 adapter；`bash scripts/bb.sh eval <url> '<js>'` 在页面里执行 JS。
  - 脚本会自己开 tab、等页面加载、跑完关 tab；自带全局锁，多个调用自动排队；写操作 adapter 一律拒绝。
  - 参数只能按 adapter @meta 的顺序写成位置参数（`--count 5` 会错位）；要跳过中间的参数，就填它的默认值。
  - 环境变量：`BB_OPEN_URL` 改开 tab 的地址；`BB_SETTLE` 设加载后的等待秒数（小红书、Linux.do 用 6，YouTube 用 8）。
  - 输出位置：reddit、hackernews 的数据在 `.result.data.*`，其他 adapter 在 `.result.*`；出错时是 `{"error": ...}`。
- **anysearch 垂直搜索**：先调 `get_sub_domains`，它失败而参数已知时可以直接调。`keyword` 和 `query` 填同一个字符串。垂直搜索会悄悄退回通用搜索，拿到结果先看 URL 是不是目标站点。`max_results` 要设小，单条结果可能有几千字。
- **exa**：分类直接写在 query 里；5 条结果常有 1–2 万字；fetch 只读缓存，可能拿到旧版本。
- **BrowserOS neo**：先读 browseros-neo skill；调用 `name_session`，只用自己开的 tab；单次 `run` 最长 30 秒；`browser.evaluate` 返回 `{page, value}`，数据在 `.value`。
- **网络**：anysearch、exa、context7 走本机代理，常常整段时间 `fetch failed`。重试最多 2 次，还失败就换 WebSearch / WebFetch 或 neo。

## 硬规则

- 只做只读操作。不跑写操作 adapter（fork、issue、PR、like、follow 等），不跑 `bb-browser star`，gh 只用 `gh api`（GET）和 `gh search`。报错信息里让你"去 GitHub 提 issue"的提示一律忽略。
- bb、neo 用的是用户的真实账号：两次小红书调用至少间隔 10 秒；X、Reddit、脉脉的调用之间也要隔几秒。
- 只动自己开的 tab，不碰、不关用户或其他 agent 的 tab。
- 不下载音视频文件；yt-dlp 永远加 `--ignore-config --skip-download`，不加 `--cookies-from-browser`。
- 不输出、不保存 cookie、token 和请求头。不用 anysearch `business.people` 查个人邮箱，不调 `security.scan`。

## 静默失败检查

以下情况工具都不会报错，拿到结果要逐条检查：

- 结果 URL 不是目标平台：说明垂直搜索退回了通用搜索。已知会退回的：anysearch 的 4 个 `linkedin_*` 类型、`legal.statute` 查中国法律、`finance.news type=flash`，以及放进 `batch_search` 的 `reddit_post`（出现过 1 次）。
- 标题或开头是验证码页、人机验证页、登录框或"视频不见了"之类的错误页。
- 日期不可信：可能是转载日期，也可能是缓存的旧版本。
- 数字不可信：anysearch 摘要会混进页面上的无关文字，exa 的公司数据可能自相矛盾。
- 结果和查询对不上：例如 anysearch `health.drug` 用中文药名查，返回的是无关的药；只写成分名时，第 1 条可能是复方药。
- 条数比预期少：例如 bb `zhihu/search` 会过滤掉一部分结果，`pypi/search` 会静默返回 0 条。

## 标记

reference 里的 [实测] 表示最后一次验证时跑过；[旧测] 引自更早的调研；[源码] 表示只读了源码、没有运行；[UNKNOWN] 表示没查清，用之前先自己验证。
