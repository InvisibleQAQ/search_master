# 个人收藏

> 最后验证：2026-09-26。标记：[实测] 本次跑过；[旧测] 引自 2026-09-24 调研；[UNKNOWN] 没查清。
> 用户问"我收藏 / 书签 / 点赞 / star 过什么"时，不能凭记忆回答，先搜。

| 需求 | 首选 | 备选 | 别用 |
|---|---|---|---|
| 我收藏过什么（B站、知乎、浏览器书签） | favbase CLI [实测] | — | 凭记忆回答；公网搜索工具（搜不到私人收藏） |
| 我的 GitHub star | favbase `--platform github`（目前 0 条，没抓取）[实测] | [UNKNOWN] | — |
| 我的 X 书签 / YouTube 播放列表 | favbase `--platform x` / `youtube`（目前 0 条，没抓取）[实测] | bb `twitter/bookmarks`（X 已登录）[UNKNOWN 没测] | — |

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
- `search`：`{count, results: [{item_id, title, url, platform, chunk_text, score}]}`。
- `coverage`：`{platforms: [{platform, acquisition, content, embedding, tagging, blockers}]}`，各阶段是 `done / total`，`blockers` 是 `[{capability: "embedding" | "llm", pending}]`。
- `get`：`{found, item_exists, item_id, content}`。`item_exists: false` 表示 id 错了；`item_exists: true, found: false` 表示收藏在但还没抽取正文。

本次 `coverage` 快照：

| 平台 | 已抓取 | 正文 | embedding | 阻塞 |
|---|---|---|---|---|
| bilibili | 3297 | 172 / 3170（字幕） | 0 / 171 | embedding、llm |
| bookmarks | 778 | 305 / 778（网页正文） | 0 / 189 | embedding、llm |
| zhihu | 924 | 924 / 924（正文） | 0 / 916 | embedding、llm |
| github / x / youtube | 0 | — | — | 从没抓取过 |

### 坑
- 语义检索仍没生效：三个平台的 embedding 全是 0，并且都有 `embedding`、`llm` 阻塞，现在只有关键词检索在工作。用收藏里可能出现的原词搜，中英文同义词都试一下（"browser automation" 0 条，"大模型" 3 条）。
- `score` 全在 0.016 左右，看起来是排名融合分而不是相关度 [UNKNOWN]，不要按分数判断相关性。
- `count: 0` 不等于用户没收藏：先跑 `coverage`。`acquisition.done` 为 0 → 让用户在 favbase 里抓取该平台；有 `blockers` → 让用户去扩展的 Settings 配 embedding 和 LLM provider，不要说"稍后再试"。
- B站正文只完成 172 / 3170，没有对应的 blocker 条目；是否在推进要隔一段时间再看 `content.done` 有没有变 [UNKNOWN]。
- 结果可能有重复 [旧测]。
- 前提：Chrome 开着且扩展里 Agent Skills 开关打开。第一次调用会自动起 daemon（stderr 打印 `starting daemon`）。退出码 2 → 跑 `favbase doctor`；1 → 用法或配置错误；3 → 参数或工具错误。
- 本机 CLI 是 0.2.1，doctor 显示 npm 最新是 0.2.0（本地比 registry 新），不用处理。

## 本次验证
- `favbase doctor` → ok，扩展已连接，CLI 0.2.1，daemon 自动启动。
- `favbase search "browser automation" --limit 5` → 0 条，0.5 秒。
- `favbase search "大模型" --limit 3` → 3 条（bilibili 2、bookmarks 1），score 约 0.016。
- `favbase coverage` → 见上表；语义检索没生效，结论与 09-24 相同。
