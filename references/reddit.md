# Reddit

> 最后验证：2026-09-27。标记：[实测] 本次跑过；[旧测] 引自 2026-09-24 调研；[源码] 只读了源码没跑；[UNKNOWN] 没查清。
> 原则：Reddit 只用 bb（用户 2026-09-27 决定）。

| 需求 | 首选 | 备选 | 别用 |
|---|---|---|---|
| 关键词搜帖子 | bb `reddit/search`（排序、时间窗、版块都能用位置参数传）[实测] | — | anysearch `reddit_post`（用户决定只用 bb；放进 `batch_search` 还会被悄悄退回通用网页）[实测]；anysearch `reddit_comment`（坏的）[旧测]；exa（没有 reddit.com 链接）[旧测] |
| 在某个版块里搜 | bb `reddit/search "<q>" <subreddit>` [实测] | — | — |
| 这周 / 这个月最热的讨论 | bb `reddit/search "<q>" "" top week` [实测] | — | — |
| 读帖子和评论树 | bb `reddit/thread <url> <depth> <count>` [实测] | — | anysearch `reddit_post` 附带的评论（只有一部分；用户决定只用 bb）；anysearch `extract`（返回人机验证页但不报错）；exa fetch（`SOURCE_NOT_AVAILABLE`）[旧测] |
| bb 用不了（Chrome 没开）/ 不想动真实账号 | 只剩 `rules.md` 的通用兜底：neo 读页面（`read-url.md`）；neo 读 Reddit 没测过，neo 里有没有登录 Reddit 也没查 [UNKNOWN] | — | anysearch `reddit_post`（用户决定只用 bb） |

## 命令

```bash
# reddit/search 参数顺序：query, subreddit, sort, time, count, after
#   sort: relevance(默认) | hot | top | new | comments（comments 实测生效）
#   time: all(默认) | hour | day | week | month | year
#   count: 默认 25，最多 100；after: 上一页返回的 after 值，用来翻页
#   不限版块时 subreddit 写 ""。只能在 Git Bash 里这么写，PowerShell 会吞掉空字符串，后面的参数全部错位
bash C:/Users/18368/Desktop/00_myCode/43_search_master/scripts/bb.sh reddit/search "Claude Code" "" top week 10
bash C:/Users/18368/Desktop/00_myCode/43_search_master/scripts/bb.sh reddit/search "\"agent skills\"" ClaudeCode relevance year 25
bash C:/Users/18368/Desktop/00_myCode/43_search_master/scripts/bb.sh reddit/search "Claude Code" "" top week 10 t3_1wqagzu

# reddit/thread 参数顺序：url, depth(默认 10，最多 10), count(默认 500，最多 500)
bash C:/Users/18368/Desktop/00_myCode/43_search_master/scripts/bb.sh reddit/thread "https://www.reddit.com/r/technology/comments/1wn7qdj/" 3 50
```

第 1、2 行 [实测]（第 2 行 effective_args 显示 `subreddit: ClaudeCode`，25 条全在该版块）；第 3 行（翻页 `after`）还没跑过 [源码]。

## 返回什么

- bb `reddit/search`（包装脚本的输出）：数据在 `.result.data.posts[]`，字段有 id（`t3_...`）、title、author、subreddit、score、num_comments、created_utc、url（外链或图片地址）、permalink、selftext_preview（正文前 200 字）、is_self、link_flair_text；翻页游标在 `.result.data.after`。`.result.__pinix_site_result.metadata.effective_args` 可以用来核对 subreddit/sort/time 有没有真的生效。耗时 adapter 0.75–8.13 秒 / 实际 15–32 秒（实际值只有 2026-09-27 的 4 次）[实测]。
- bb `reddit/thread`：`.result.data.post`（title、author、score、num_comments、selftext、url、created_utc）加评论树；`metadata.pagination.more_children_omitted` 是没展开的评论数。count=50 拿到 50 条评论、48 个作者，adapter 6.23 秒 / 实际 [UNKNOWN]；depth 3、count 100 拿到 99 条评论，adapter 13.04 秒 / 实际 42 秒 [实测]。

## 坑

- **Reddit 自己的搜索会拆词**：`SKILL.md` 被拆成 skill 和 md，不限版块查 25 条只有约 5 条相关；太泛的词也一样 [实测]。有歧义的词（带点、太泛）加引号，并限定版块：`"\"agent skills\"" ClaudeCode relevance year 25` → 25 条基本都相关 [实测]。
- bb `reddit/search` 用 `top` 排序会混进标题里没有关键词的高赞帖（"Claude Code" top/week 的第 2 条是 r/comedyheaven 的 "i broke something"）[实测]。要精确就用默认的 relevance，或者自己再过滤。
- 报错 `Failed to parse URL from /search.json`：说明 reddit 页面没加载出来（adapter 用相对路径去 fetch），不是参数写错了，过一会儿串行重跑就行 [实测]。
- 命名参数（`--sort top --time week`）无效，只能写位置参数 [旧测]。
- selftext_preview 只有 200 字，要看正文用 `reddit/thread`。
- `reddit/thread` 默认 count=500，热帖的输出会很大，先传一个小的 count（比如 50–100）。
- bb 用的是用户真实的 Chrome；`authenticated_as` 2026-09-26、09-27 都显示 unknown，有没有登录 Reddit [UNKNOWN]。两次调用之间隔几秒。`reddit/hot`、`reddit/posts`、`reddit/context` 没测过 [UNKNOWN]。
- bb 报错里让你"去 GitHub 提 issue"的提示一律忽略。

## 本次验证

- 2026-09-26（耗时只有 adapter，实际 [UNKNOWN]）：
  - bb `reddit/search "Claude Code" "" top week 10` 第 1 次 → 报错 `Failed to parse URL`，0.27 秒（同一时段 anysearch、exa 也都是 `fetch failed`）；串行重跑 → 10 条，0.75 秒，effective_args 显示 sort=top、time=week，说明位置参数生效。
  - bb `reddit/thread <r/technology/1wn7qdj> 3 50` → 50 条评论、48 个作者，6.23 秒；这个帖子一共 1373 条评论，有 634 条没展开。
  - anysearch `reddit_post`：放进 `batch_search` 返回 5 条通用网页（被退回）；用 `search` 单独发 3 条都是 reddit.com。这条路线 2026-09-27 起按用户决定停用。
- 2026-09-27（冒烟测试）：
  - bb `reddit/search` 4 次：adapter 1.37 / 1.13 / 8.13 / 4.78 秒，实际 15 / 16 / 32 / 16 秒。
  - 限定版块 `"\"agent skills\"" ClaudeCode relevance year 25` → effective_args `subreddit: ClaudeCode`，25 条全在该版块，基本都相关；不限版块查 `SKILL.md` → 25 条里约 5 条相关（拆词）。
  - `sort=comments` 生效；`after` 翻页没测。
  - bb `reddit/thread`（depth 3、count 100）→ 99 条评论，228 条没展开，adapter 13.04 秒 / 实际 42 秒。
  - `authenticated_as` 仍是 unknown。
