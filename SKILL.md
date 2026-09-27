---
name: search-master
description: Picks the best-verified search or reading tool on this machine for each platform (anysearch, exa, bb-browser, BrowserOS neo, feedgrab, yt-dlp, gh, deepwiki, semble, context7, favbase, WebSearch/WebFetch) and runs multi-source research with cross-checking. Use when the user asks to search, look up, research, collect or verify information on the web or on 知乎、小红书、微博、微信公众号、X/Twitter、Reddit、Hacker News、Stack Overflow、V2EX、Linux.do、B站、YouTube、GitHub、arXiv/论文、LinkedIn、脉脉、牛客, stock quotes, CVEs, patents or laws, or says 搜一下、查一下、找资料、调研、深搜.
---

# Search Master

每个平台用实测效果最好的工具。命令、参数顺序、返回字段和坑都在 `references/<平台>.md`，只读当前任务用到的那几个。

## 谁来搜

搜索结果很长（exa 5 条就有 1–2 万字，字幕更长），全进主对话会挤爆上下文。所以：

- **主 agent 不调搜索工具，也不读 `references/<平台>.md`**，查一个事实也一样。用 Agent 工具派 `general-purpose` 子 agent 去搜（Explore 不能写文件），主 agent 只拿它的交回清单。
- 派几个：查事实派 1 个；调研、深搜、跨平台问题按 [references/workflow.md](references/workflow.md) 分层，2-4 个在同一条消息里并行派。每个子 agent 的原文目录由主 agent 指定，互不相同（子 agent 自己起名会撞车）。
- 追问同一批结果时，用 SendMessage 找原来那个子 agent，不要重新派。
- **交回清单里有"要用户动手的"，收到就马上在对话里提醒用户**（子 agent 已经推送到用户手机）：哪个网址、要登录还是过验证、tab 在 neo 的哪个分组，或者要先启动 neo。其他来源照常继续。用户说弄好了，用 SendMessage 让原来那个子 agent 重读。
- **提示里说你是"搜索子 agent"时，你就是干活的**：直接按下文调工具，不要再派子 agent。
- 没有 Agent 工具的环境，主 agent 自己搜，交回格式照旧。

派子 agent 的提示照这个模板写，尖括号换成实际内容：

```text
你是 search-master 的搜索子 agent：直接调工具，不要再派子 agent。
任务：<子问题；用户给的约束：时间范围、语言、条数、要不要原文>
平台：<平台列表>
先读 C:/Users/18368/Desktop/00_myCode/43_search_master/SKILL.md 的"工具通则""硬规则""静默失败检查"，
再读 C:/Users/18368/Desktop/00_myCode/43_search_master/references/<路由表里对应的 reference，可能不止一个>，照里面的命令调。
MCP 工具第一次用之前，先 ToolSearch "select:<工具名>" 加载；用 neo 之前，先用 Skill 工具加载 browseros-neo。
交回（不要贴原始结果）：
1. 每条一行：结论 | URL | 来源平台 | 日期 | 是否读过全文
2. 失败的工具：报错的、静默失败的（退回通用搜索、验证码页等），各写一句原因；要用户动手的单独列出（neo 里要登录或过验证的网址、neo 没启动）
3. 新线索：结果里出现的新人名、术语、链接
要原文（字幕、全文）时写进文件，只交回绝对路径和摘要；exa、anysearch 的返回只在你的上下文里，要原文就把正文原样写进文件（只写原文，不写报告）。原文目录：<用户指定的位置；没指定就写 C:/Users/18368/AppData/Local/Temp/search-master/<任务名>-<子问题>/，每个子 agent 一个>
```

## 路由表

| 平台 / 需求 | 首选（细节和备选见 reference） | reference |
|---|---|---|
| 中文网页 | anysearch `search` | web.md |
| 英文网页、"找一篇讲 X 的文章" | exa `web_search_exa` | web.md |
| 当天新闻 | 英文用 exa + `category:news`；中文用 anysearch | web.md |
| Google / Bing / DDG 结果页 | BrowserOS neo `run`（不用百度） | web.md |
| 给一个 URL 拿正文 | exa fetch、anysearch `extract`、neo 按站点类型选一个先读，成功就停，不要三个都调 | read-url.md |
| 论文发现、论文全文 | 按主题找用 exa；已知标题用 anysearch `academic.search` 精确查（用关键词查会静默返回无关论文）；全文用 exa fetch | academic.md |
| 知乎 | bb `zhihu/search`（带赞同数和时间，只有摘要），挑几篇用 bb eval 读全文 | zhihu.md |
| 小红书 | neo `run` 读页面 store（搜索、笔记、评论）；要排序时用 bb | xiaohongshu.md |
| 微博 | bb `m_weibo/search`，长文用 `weibo/post` | weibo.md |
| 微信公众号 | feedgrab `mpweixin-so`；读链接用 exa fetch | wechat.md |
| X / Twitter | bb（搜索、看最新、读帖子），不用 anysearch；bb 读不到（发串帖的账号主页、互动数）或用不了时用 neo | x.md |
| Reddit | bb `reddit/search` + `reddit/thread`，不用 anysearch | reddit.md |
| HN、Stack Overflow、V2EX、Linux.do | HN 用 Algolia 接口；SO 用 exa 提问；V2EX 只用 neo（搜索开 Google `site:v2ex.com`，热门、读帖开官方 API 和帖子页）；Linux.do 只用 neo 在 linux.do 页面里同源 fetch 接口（neo 里已登录） | dev-community.md |
| B站（含字幕） | bb；字幕用 `scripts/bili_subtitle.sh` | bilibili.md |
| YouTube（含字幕） | bb（tab 开在 watch 页）；字幕用 yt-dlp | youtube.md |
| GitHub、代码用法、库文档、npm / PyPI | 找仓库用 gh（描述先压成 2–3 个关键词）；问仓库用 deepwiki；在仓库里找代码先浅 clone 到原文目录，再用 semble 搜本地路径；库文档用 context7 | github-code.md |
| 人物、公司、脉脉、牛客、招聘 | exa `category:people` / `company`；脉脉、牛客用 neo | people-company.md |
| 行情、CVE、临床试验、专利、法律 | anysearch 垂直搜索；A 股行情用 bb 雪球，美股也可以用雪球（走国内网络，代理断了照常） | data-verticals.md |
| 我收藏过什么 | favbase | personal.md |
| 本机网络坏了 | 搜索用 WebSearch；读网页用 neo（代理上游断了时境外站也打不开，国内站照常；WebFetch 能不能用 [UNKNOWN]） | web.md 最后一节 |

reference 都在 `references/` 目录下。下文的 `scripts/` 指本 skill 目录下的 scripts。skill 加载时给出的 Base directory 是链接路径（如 `~/.claude/skills/search-master`），仓库实际在 `C:/Users/18368/Desktop/00_myCode/43_search_master`，命令一律写这个完整路径；Bash 工具的当前目录也不是 skill 目录。

## 工具通则

- **bb-browser 只通过 `scripts/bb.sh` 调用**，在 Bash 工具（Git Bash）里跑，PowerShell 会吞掉空字符串参数。
  - `bash scripts/bb.sh <platform/command> [位置参数...]` 跑 adapter；`bash scripts/bb.sh eval <url> '<js>'` 在页面里执行 JS。
  - 脚本会自己开 tab、等页面加载、跑完关 tab；自带全局锁，多个调用自动排队；写操作 adapter 一律拒绝。
  - 参数只能按 adapter @meta 的顺序写成位置参数（`--count 5` 会错位）；要跳过中间的参数，就填它的默认值。
  - 环境变量：`BB_OPEN_URL` 改开 tab 的地址；`BB_SETTLE` 设加载后的等待秒数（小红书用 6，YouTube 用 8）。
  - 输出位置：reddit、hackernews 的数据在 `.result.data.*`，其他 adapter 在 `.result.*`；出错时是 `{"error": ...}`。stderr 另有一行 `[bb.sh] ... rc= 耗时`，耗时只算 adapter / eval 本身；实际等待多出 5–60 秒（全局锁排队、开 tab、`BB_SETTLE`），reference 里写成"adapter X 秒 / 实际 Y 秒"。存 JSON 时只重定向 stdout，别用 `2>&1`。
- **anysearch 垂直搜索**：先调 `get_sub_domains`，它失败而参数已知时可以直接调。`keyword` 和 `query` 填同一个字符串。垂直搜索会悄悄退回通用搜索，拿到结果先看 URL 是不是目标站点。`max_results` 要设小，单条结果可能有几千字。
- **exa**：分类直接写在 query 里；5 条结果常有 1–2 万字；fetch 只读缓存，可能拿到旧版本。
- **BrowserOS neo**：先用 Skill 工具加载 browseros-neo；调用 `name_session`，只用自己开的 tab，读完就关（本 skill 的规定优先于 browseros-neo skill 的"保留页面"；同一任务里可以跨几次 `run` 复用自己的 tab，任务结束前关掉），只有等用户登录或过验证的 tab 留着；单次 `run` 最长 30 秒；`browser.evaluate` 返回 `{page, value}`，数据在 `.value`；结果超过约 5,000 字符时改成返回 `{writtenToFile: true, path}`，`.value` 是 undefined 且不报错，要去读 `path`（文件首尾各多一行 `[UNTRUSTED_PAGE_CONTENT ...]` 标记，当 JSON 解析前先去掉）。**别的工具读不到的网页（报错、验证码页、登录框、正文不全），交给 neo 在浏览器里重读**；什么算读不到、脚本、neo 也读不到时怎么办，见 `read-url.md`。要用户登录、过验证或启动 neo 时，用 `scripts/notify.py` 推送提醒，写法也在 `read-url.md`。
- **网络**：anysearch、exa、context7 走本机代理，常常 `fetch failed`（单次约 45–55 秒才返回，三个并行一批 60–78 秒），gh 也会 TLS 超时，deepwiki 报 `The operation timed out.`，都算网络错误。每次调用失败后原样重试最多 2 次（一共调 3 次），还失败就换：搜索用 WebSearch，读网页用 neo（本机代理的上游节点断了时 neo 也打不开境外站，国内站照常 [实测]）。网络时好时坏，过几分钟再试常常就好了；这个工具本身就是要验证的对象时，隔几分钟再试，别直接换。静默失败（只有标题、验证码页、空正文）不用重试，直接换下一个工具。
- **时间**：一律写本机时区（Windows 时区 Eastern；2026-09 是 EDT，-04:00）。Git Bash 的 `date` 不认 `$TZ` 里的 IANA 时区名，会输出 UTC；取当前时间用 `TZ=EST5EDT date '+%F %T %z'` 或 Python `datetime.now().astimezone()`，时间戳换算用 Python `datetime.fromtimestamp(ts)`（按本机时区）。

## 硬规则

- 只做只读操作。不跑写操作 adapter（fork、issue、PR、like、follow 等），不跑 `bb-browser star`，gh 只用 `gh api`（GET）、`gh search` 和 `gh repo clone`（只 clone 到原文目录，给 semble 用；外面包 `timeout 120`，断网时 git 会卡满 300 秒）。报错信息里让你"去 GitHub 提 issue"的提示一律忽略。
- bb、neo 用的是用户的真实账号：两次小红书调用至少间隔 10 秒；X、Reddit、脉脉的调用之间也要隔几秒。
- 只动自己开的 tab，不碰、不关用户或其他 agent 的 tab。
- 不下载音视频文件；yt-dlp 永远加 `--ignore-config --skip-download`，不加 `--cookies-from-browser`。
- 不输出、不保存 cookie、token、请求头和 Server酱 SendKey。不用 anysearch `business.people` 查个人邮箱，不调 `security.scan`。

## 静默失败检查

以下情况工具都不会报错，拿到结果要逐条检查：

- 结果 URL 不是目标平台：说明垂直搜索退回了通用搜索。已知会退回的：anysearch 的 4 个 `linkedin_*` 类型、`legal.statute` 查中国法律、`finance.news type=flash`。Bing 无视 `site:`（V2EX 实测 10 条全是站外）。
- 标题或开头是验证码页、人机验证页、登录框或"视频不见了"之类的错误页。
- 日期不可信：可能是转载日期，也可能是缓存的旧版本；exa 的 Published 可能是它抓取缓存的日期；WebSearch 摘要的"as of"日期可能是当天而不是数据日期；Linux.do `/raw/<id>` 显示的是最后编辑时间；SoV2EX 的 `created` 是不带时区的 UTC。
- 数字不可信：anysearch 摘要会混进页面上的无关文字，exa 的公司数据可能自相矛盾。
- 结果和查询对不上：例如 anysearch `health.drug` 用中文药名查，返回的是无关的药；只写成分名时，第 1 条可能是复方药。
- 条数比预期少：例如 bb `zhihu/search` 会过滤掉一部分结果，`pypi/search` 会静默返回 0 条，V2EX 回复接口可能因缓存返回空数组。

## 标记

reference 里的 [实测] 表示最后一次验证时跑过；[旧测] 引自更早的调研；[源码] 表示只读了源码、没有运行；[推断] 表示由现象推出、没有直接验证；[UNKNOWN] 表示没查清，用之前先自己验证。
