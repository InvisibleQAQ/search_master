---
name: search-master
description: Picks the best-verified search or reading tool on this machine for each platform (anysearch, exa, bb-browser, BrowserOS neo, feedgrab, yt-dlp, gh, deepwiki, semble, context7, favbase, WebSearch/WebFetch) and runs multi-source research with cross-checking. Use when the user asks to search, look up, research, collect or verify information on the web or on 知乎、小红书、微博、微信公众号、X/Twitter、Reddit、Hacker News、Stack Overflow、V2EX、Linux.do、B站、YouTube、GitHub、arXiv/论文、LinkedIn、脉脉、牛客, stock quotes, CVEs, patents or laws; asks what a given URL, article or video says (full text, summary, transcript); or says 搜一下、查一下、找资料、调研、深搜、读一下这个链接. Read-only. For posting, liking, logging in, screenshots or saving pages as files, use browseros-neo.
---

# Search Master

每个平台用实测效果最好的工具。命令、参数顺序、返回字段和坑都在 `references/<平台>.md`，只读当前任务用到的那几个。

## 谁来搜

搜索结果很长（exa 5 条就有 1–2 万字，字幕更长），全进主对话会挤爆上下文。所以：

- **主 agent 不调搜索工具，也不读 `references/<平台>.md`**，查一个事实也一样。用 Agent 工具派 `general-purpose` 子 agent 去搜（Explore 不能写文件），主 agent 只拿它的交回清单。
- 派几个：查事实派 1 个；调研、深搜、跨平台问题按 [references/workflow.md](references/workflow.md) 分层，2-4 个在同一条消息里并行派。每个子 agent 的原文目录由主 agent 指定，互不相同（子 agent 自己起名会撞车）。
- 追问同一批结果时，用 SendMessage 找原来那个子 agent，不要重新派。
- **交回清单里有"要用户动手的"，收到就马上在对话里提醒用户**（子 agent 已经推送到用户手机）：哪个网址、要登录还是过验证、tab 在 neo 的哪个分组，或者要先启动 neo。其他来源照常继续。用户说弄好了，用 SendMessage 让原来那个子 agent 重读。
- **提示里说你是"搜索子 agent"时，你就是干活的**：先读 `references/rules.md` 和对应的平台 reference，直接调工具，不要再派子 agent。
- 没有 Agent 工具的环境，主 agent 自己搜：先读 `references/rules.md`，交回格式照旧。

派子 agent 的提示照这个模板写，尖括号换成实际内容：

```text
你是 search-master 的搜索子 agent：直接调工具，不要再派子 agent。
任务：<子问题；用户给的约束：时间范围、语言、条数、要不要原文>
线索：<已知的术语、人名、链接；滚雪球时是上一轮交回的新线索；没有写"无">
平台：<平台列表>
先读 C:/Users/18368/Desktop/00_myCode/43_search_master/references/rules.md（工具通则、硬规则、静默失败检查），
再读 C:/Users/18368/Desktop/00_myCode/43_search_master/references/<路由表里对应的 reference，可能不止一个>，照里面的命令调。
MCP 工具第一次用之前，先 ToolSearch "select:<工具名>" 加载；用 neo 之前，先用 Skill 工具加载 browseros-neo。
交回（不要贴原始结果）：
1. 每条一行：结论 | URL | 来源平台 | 日期 | 是否读过全文
2. 失败的工具：报错的、静默失败的（退回通用搜索、验证码页等），各写一句原因；要用户动手的单独列出（neo 里要登录或过验证的网址、neo 没启动）
3. 新线索：结果里出现的新人名、术语、链接
要原文（字幕、全文）时写进文件，只交回绝对路径和摘要；exa、anysearch 的返回只在你的上下文里，要原文就把正文原样写进文件（只写原文，不写报告）。原文目录：<用户指定的位置；没指定就写 C:/Users/18368/AppData/Local/Temp/search-master/<任务名>-<子问题>/，每个子 agent 一个>
```

## 路由表

| 平台 / 需求 | 用哪些工具（命令、备选、坑见 reference） | reference |
|---|---|---|
| 中文网页 | anysearch | web.md |
| 英文网页、"找一篇讲 X 的文章" | exa | web.md |
| 当天新闻 | 英文 exa，中文 anysearch | web.md |
| Google / Bing / DDG 结果页 | neo | web.md |
| 给一个 URL 拿正文 | exa、anysearch、neo（按站点类型选一个） | read-url.md |
| 论文发现、论文全文 | exa、anysearch（最新预印本用 bb，被引数用 neo） | academic.md |
| 知乎 | bb | zhihu.md |
| 小红书 | neo（要排序时用 bb） | xiaohongshu.md |
| 微博 | bb | weibo.md |
| 微信公众号 | feedgrab、exa、bb | wechat.md |
| X / Twitter | bb，读不到用 neo | x.md |
| Reddit | bb | reddit.md |
| HN、Stack Overflow、V2EX、Linux.do | HN 用 anysearch、bb；SO 用 exa、bb；V2EX、Linux.do 只用 neo | dev-community.md |
| B站（含字幕） | bb | bilibili.md |
| YouTube（含字幕） | bb、yt-dlp | youtube.md |
| GitHub、代码用法、库文档、npm / PyPI | gh、deepwiki、semble、context7（npm / PyPI 用 bb） | github-code.md |
| 人物、公司、脉脉、牛客、招聘 | exa、anysearch；脉脉、牛客用 neo | people-company.md |
| 行情、CVE、临床试验、专利、法律 | anysearch；A 股、美股行情用 bb | data-verticals.md |
| 我收藏过什么 | favbase | personal.md |
| 本机网络坏了 | WebSearch、neo | web.md 最后一节 |

reference 列的文件都在 `C:/Users/18368/Desktop/00_myCode/43_search_master/references/`；skill 加载时给出的 Base directory 是链接路径，提示里一律写这个完整路径。
