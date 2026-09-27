# 个人收藏

> 最后验证：2026-09-27（重跑了 search、coverage，遇到一次 `bad-token`；`doctor` 正常时的输出仍是 2026-09-26 的）。标记：[实测] 跑过（日期见"本次验证"）；[旧测] 引自 2026-09-24 调研；[UNKNOWN] 没查清。钟点时间都是本机时间（美东，EDT -04:00）。
> 用户问"我收藏 / 书签 / 点赞 / star 过什么"时，不能凭记忆回答，先搜。

| 需求 | 首选 | 备选 | 别用 |
|---|---|---|---|
| 我收藏过什么（B站、知乎、浏览器书签、X 书签） | favbase CLI [实测] | — | 凭记忆回答；公网搜索工具（搜不到私人收藏） |
| 我的 GitHub star | favbase `--platform github`（09-26 是 0 条，没抓取）[实测] | [UNKNOWN] | — |
| 我的 X 书签 / YouTube 播放列表 | favbase `--platform x` / `youtube`（09-27：x 已抓取 2329 条；youtube 09-26 是 0 条，没抓取）[实测] | bb `twitter/bookmarks`（X 已登录）[UNKNOWN 没测] | — |

## favbase
### 命令
```bash
favbase doctor                                   # 配置、daemon、扩展连接、CLI 版本
favbase search "大模型" --limit 5                 # 全部平台
favbase search "大模型" --platform zhihu --limit 5  # bilibili / github / bookmarks / x / zhihu / youtube
favbase coverage                                 # 各平台处理进度和阻塞
favbase get <item_id>                            # 片段太短时取全文
favbase tags                                     # 标签和条数；search 可加 --tag <tag-id>
```
在 PowerShell 5.1 里 `favbase call <tool> --args '<json>'` 的双引号会被吞，改用 `--args-file <path>`。只读，不要运行 `npm install` 或 `favbase install-skill`。
### 返回什么
- `search`：`{count, results: [{item_id, title, url, platform, chunk_text, score}]}`。没有日期字段：既没有收藏时间，也没有发布时间 [实测]。
- `coverage`：`{platforms: [{platform, acquisition, content, embedding, tagging, blockers}]}`，各阶段是 `done / total`，`blockers` 是 `[{capability: "embedding" | "llm", pending}]`。
- `get`：`{found, item_exists, item_id, content}`。`item_exists: false` 表示 id 错了；`item_exists: true, found: false` 表示收藏在但还没抽取正文。

`coverage` 快照（09-27 的数字只记了变化的几项，没记的写 09-26 的值；两天之间重新配对过，可能连的不是同一个扩展实例，见"坑"）：

| 平台 | 已抓取 | 正文 done | 09-26 的值（正文 done / total，embedding，阻塞） |
|---|---|---|---|
| x | 2329（09-27） | 838（09-27） | 0，从没抓取过 |
| bilibili | 2880（09-27） | 146（09-27，字幕） | 已抓取 3297；正文 172 / 3170；embedding 0 / 171；embedding、llm |
| bookmarks | 778（09-26） | 173（09-27，网页正文） | 正文 305 / 778；embedding 0 / 189；embedding、llm |
| zhihu | 924（09-26） | 924（09-26） | 正文 924 / 924；embedding 0 / 916；embedding、llm |
| github / youtube | 0（09-26） | — | 从没抓取过 |

09-27 的 embedding 进度和阻塞没记 [UNKNOWN]。

### 坑
- 语义检索没生效（09-26）：三个平台的 embedding 全是 0，并且都有 `embedding`、`llm` 阻塞，只有关键词检索在工作；09-27 的状态没记 [UNKNOWN]。用收藏里可能出现的原词搜，中英文同义词都试一下（09-26 "browser automation" 0 条，"大模型" 3 条；09-27 "大模型" 能命中，但相关性弱）。
- `score` 全在 0.016 左右，看起来是排名融合分而不是相关度 [UNKNOWN]，不要按分数判断相关性。
- `count: 0` 不等于用户没收藏：09-27 搜 "Claude"、"Claude Code"，zhihu、bilibili、bookmarks 都是 0 条，只有 x 命中，不报错。先跑 `coverage`。`acquisition.done` 为 0 → 让用户在 favbase 里抓取该平台；有 `blockers` → 让用户去扩展的 Settings 配 embedding 和 LLM provider，不要说"稍后再试"。
- 要日期就自己推：结果里没有日期字段；X 书签只能由 URL 里的 status ID 推算发帖时间，那不是收藏时间。
- `coverage` 的数字不能跨天直接比：09-27 重新配对后 bilibili 已抓取 3297→2880、正文 172→146，bookmarks 正文 305→173，x 从 0 变成 2329，可能是连到了另一个扩展实例或 profile [UNKNOWN]。所以 B站正文是否在推进，也没法从这两次看出来。
- 结果可能有重复 [旧测]。
- 前提：Chrome 开着且扩展里 Agent Skills 开关打开。第一次调用会自动起 daemon（stderr 打印 `starting daemon`）。退出码 2 → 跑 `favbase doctor`；1 → 用法或配置错误；3 → 参数或工具错误。
- 退出码 2、报 `bad-token`（`doctor` 也是退出码 2）：扩展的配对 token 和 CLI 的对不上。这要用户动手：请用户用扩展设置卡片上的值重跑 `favbase setup --token <token> --port 17836`，按 `rules.md` 的提醒流程推送（`notify.py` 写法见 `read-url.md`），并列进交回清单"要用户动手的"。token 的值不要出现在输出、交回和文件里。
- 本机 CLI 是 0.2.1，doctor 显示 npm 最新是 0.2.0（本地比 registry 新），不用处理。

## 本次验证
- 2026-09-26：
  - `favbase doctor` → ok，扩展已连接，CLI 0.2.1，daemon 自动启动。
  - `favbase search "browser automation" --limit 5` → 0 条，0.5 秒。
  - `favbase search "大模型" --limit 3` → 3 条（bilibili 2、bookmarks 1），score 约 0.016。
  - `favbase coverage` → 见上表"09-26 的值"；语义检索没生效，结论与 09-24 相同。
- 2026-09-27（冒烟测试）：
  - 05:15 第一次调用 → 退出码 2，`bad-token`；`favbase doctor` 也是退出码 2，用时 18.5 秒。
  - 05:23:43 `~/.favbase/config.json` 被改写、daemon 重启，之后恢复正常；是谁改写的 [UNKNOWN]。
  - 恢复后：search 每次约 1 秒；`coverage` 0.6 秒，快照见上表；分平台 search 9 次，每次约 1 秒。
  - "Claude"、"Claude Code" → zhihu、bilibili、bookmarks 都是 0 条，只有 x 命中；"大模型" 能命中，但相关性弱；结果里没有日期字段。
