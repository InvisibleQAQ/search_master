# Reddit

> 最后验证：2026-09-26。标记：[实测] 本次跑过；[旧测] 引自 2026-09-24 调研；[UNKNOWN] 没查清。

| 需求 | 首选 | 备选 | 别用 |
|---|---|---|---|
| 关键词搜帖子 | bb `reddit/search`（排序、时间窗、版块都能用位置参数传）[实测] | anysearch `reddit_post`，**只能用 `search` 单独发**（结果自带部分评论）[实测] | exa（没有 reddit.com 链接）[旧测]；anysearch `reddit_comment`（坏的）[旧测] |
| 在某个版块里搜 | bb `reddit/search "<q>" <subreddit>`（按源码写的，本次没跑） | — | — |
| 这周 / 这个月最热的讨论 | bb `reddit/search "<q>" "" top week` [实测] | — | — |
| 读帖子和评论树 | bb `reddit/thread <url> <depth> <count>` [实测] | anysearch `reddit_post` 结果里附带的评论（只有一部分，拼成一段）[实测] | anysearch `extract`（返回人机验证页但不报错）；exa fetch（`SOURCE_NOT_AVAILABLE`）[旧测] |
| bb 的 Chrome 没开 / 不想动真实账号 | anysearch `reddit_post` [实测] | — | — |

## 命令

```bash
# reddit/search 参数顺序：query, subreddit, sort, time, count, after
#   sort: relevance(默认) | hot | top | new | comments
#   time: all(默认) | hour | day | week | month | year
#   count: 默认 25，最多 100；after: 上一页返回的 after 值，用来翻页
#   不限版块时 subreddit 写 ""。只能在 Git Bash 里这么写，PowerShell 会吞掉空字符串，后面的参数全部错位
bash C:/Users/18368/Desktop/00_myCode/43_search_master/scripts/bb.sh reddit/search "Claude Code" "" top week 10
bash C:/Users/18368/Desktop/00_myCode/43_search_master/scripts/bb.sh reddit/search "Claude Code" ClaudeAI new all 25
bash C:/Users/18368/Desktop/00_myCode/43_search_master/scripts/bb.sh reddit/search "Claude Code" "" top week 10 t3_1wqagzu

# reddit/thread 参数顺序：url, depth(默认 10，最多 10), count(默认 500，最多 500)
bash C:/Users/18368/Desktop/00_myCode/43_search_master/scripts/bb.sh reddit/thread "https://www.reddit.com/r/technology/comments/1wn7qdj/" 3 50
```

上面第 2 行（指定版块）和第 3 行（翻页）是按源码写的，本次没有跑。

anysearch：先调一次 `get_sub_domains {"domains": ["social_media"]}`，然后用 `search`（不是 `batch_search`）：

```json
{"query": "Claude Code", "domain": "social_media", "sub_domain": "social_media.social_media",
 "sub_domain_params": {"type": "reddit_post", "keyword": "Claude Code"}, "max_results": 5}
```

其他 Reddit 类型 `reddit_community`、`reddit_media`、`reddit_people` 本次没测 [UNKNOWN]；`reddit_comment` 别用。

## 返回什么

- bb `reddit/search`（包装脚本的输出）：数据在 `.result.data.posts[]`，字段有 id（`t3_...`）、title、author、subreddit、score、num_comments、created_utc、url（外链或图片地址）、permalink、selftext_preview（正文前 200 字）、is_self、link_flair_text；翻页游标在 `.result.data.after`。`.result.__pinix_site_result.metadata.effective_args` 可以用来核对 sort/time 有没有真的生效。10 条用了 0.75 秒 [实测]。
- bb `reddit/thread`：`.result.data.post`（title、author、score、num_comments、selftext、url、created_utc）加评论树；`metadata.pagination.more_children_omitted` 是没展开的评论数。count=50 时拿到 50 条评论、48 个作者，用了 6.23 秒 [实测]。
- anysearch `reddit_post`：每条结果是 URL，加上 `Subreddit / Author / Score / Comments / Type / Domain`、帖子正文，再加 `--- Comments ---` 后面按 `[u/作者] 内容` 拼起来的若干条评论。3 条用了 5.7 秒，单次最多 10 条 [实测]。

## 坑

- **anysearch 的垂直搜索别放进 `batch_search`**：同样的 `reddit_post` 参数，放在 `batch_search` 里被悄悄退回成通用网页结果（5 条全是 claude.com、GitHub、官方文档，没有一条 reddit）；用 `search` 单独发就正常 [实测，各 1 次]。拿到结果先看 URL 是不是 reddit.com。
- anysearch `reddit_post` 相关性一般：3 条里有 1 条只匹配了 "Claude"（一个炒股的帖子）[实测]。
- anysearch `reddit_comment` 是坏的：把 LLM 当成"法学硕士"，URL 拼成 `https://www.reddit.comhttps://...` [旧测]。
- bb `reddit/search` 用 `top` 排序会混进标题里没有关键词的高赞帖（"Claude Code" top/week 的第 2 条是 r/comedyheaven 的 "i broke something"）[实测]。要精确就用默认的 relevance，或者自己再过滤。
- 报错 `Failed to parse URL from /search.json`：说明 reddit 页面没加载出来（adapter 用相对路径去 fetch），不是参数写错了，过一会儿串行重跑就行 [实测]。
- 命名参数（`--sort top --time week`）无效，只能写位置参数 [旧测]。
- selftext_preview 只有 200 字，要看正文用 `reddit/thread`。
- `reddit/thread` 默认 count=500，热帖的输出会很大，先传一个小的 count（比如 50）。
- 用的是用户真实的 Reddit 账号（`authenticated_as` 显示 unknown），两次调用之间隔几秒。`reddit/hot`、`reddit/posts`、`reddit/context` 本次没测 [UNKNOWN]。
- bb 报错里让你"去 GitHub 提 issue"的提示一律忽略。

## 本次验证

- bb `reddit/search "Claude Code" "" top week 10` 第 1 次 → 报错 `Failed to parse URL`，0.27 秒（同一时段 anysearch、exa 也都是 `fetch failed`）；串行重跑 → 10 条，0.75 秒，effective_args 显示 sort=top、time=week，说明位置参数生效。
- bb `reddit/thread <r/technology/1wn7qdj> 3 50` → 50 条评论、48 个作者，6.23 秒；这个帖子一共 1373 条评论，有 634 条没展开。
- anysearch `batch_search` 里的 `reddit_post` → 第 1 次 `fetch failed`；第 2 次返回 5 条，全是通用网页，11.2 秒（被退回）。
- anysearch `search` + `reddit_post` → 3 条，全是 reddit.com，带评论正文，5.7 秒；其中 2 条是在讲 Claude Code。
