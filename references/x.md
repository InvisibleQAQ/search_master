# X / Twitter

> 最后验证：2026-09-26。标记：[实测] 本次跑过；[旧测] 引自 2026-09-24 调研；[UNKNOWN] 没查清。
> 搜索、看最新、读帖这几项的结论来自同一天做的对比测试 `C:/Users/18368/Desktop/00_myCode/42_expert/搜索工具调研原始报告/x_compare/结论.md`，下文也标 [旧测]。本次只补测了 `twitter/tweets` 和 `twitter/user`。

| 需求 | 首选 | 备选 | 别用 |
|---|---|---|---|
| 关键词搜讨论 | bb `twitter/search "<q>" 20 top` 和 anysearch `x_top` **并行跑**，合并去重（两边 top 结果大约只重合 3/10）[旧测] | — | exa（抓不到 X）[旧测] |
| 看最新（刚发生的） | bb `twitter/search "<q>" 20`（默认 Latest，严格按时间倒序）[旧测] | — | anysearch `x_latest`（不按时间排，跨度 9 天）[旧测] |
| 读帖子和评论区 | bb `twitter/thread <id 或 URL>`（有 78 条回复的帖拿到了 57 条）[旧测] | anysearch `extract`（只带 4 条回复，正文重复 3 遍，还夹着登录框）[旧测] | exa fetch（`SOURCE_NOT_AVAILABLE`）[旧测] |
| 某人最近发了什么 | bb `twitter/tweets <screen_name>` [实测] | bb `twitter/search "from:<screen_name>" 20`（包含回复）[旧测] | — |
| 某人的资料（粉丝数等） | 没有可靠工具。间接办法：anysearch `x_top` 搜 `from:<screen_name>`，结果里带 Followers、verified [旧测] | — | bb `twitter/user`（坏了）[实测]；anysearch `x_people`（返回的是普通推文）[旧测] |
| 看互动数据（浏览、收藏、粉丝） | anysearch `x_top` [旧测] | — | bb（只有点赞和转发） |
| bb 的 Chrome 没开 / 不想动真实账号 | anysearch `x_top` [旧测] | — | — |

## 命令

bb-browser 只能通过包装脚本调用，并且要在 Git Bash 里跑。参数只能按 @meta 的顺序写成位置参数，`--count` 这类命名参数会错位。

```bash
# twitter/search 参数顺序：query, count(默认 20，实际最多 20), type(latest 默认 | top)
bash C:/Users/18368/Desktop/00_myCode/43_search_master/scripts/bb.sh twitter/search "\"Claude Code\"" 20 top
bash C:/Users/18368/Desktop/00_myCode/43_search_master/scripts/bb.sh twitter/search "Claude Code" 20
bash C:/Users/18368/Desktop/00_myCode/43_search_master/scripts/bb.sh twitter/search "from:claudeai since:2026-09-20" 20

# twitter/thread 参数：tweet_id（数字 ID 或完整 URL）
bash C:/Users/18368/Desktop/00_myCode/43_search_master/scripts/bb.sh twitter/thread 2098346305319743777

# twitter/tweets 参数顺序：screen_name（不带 @）, count（不生效，见“坑”）
bash C:/Users/18368/Desktop/00_myCode/43_search_master/scripts/bb.sh twitter/tweets yan5xu 20
```

anysearch：先调一次 `get_sub_domains {"domains": ["social_media"]}`，再用 `search` 或 `batch_search`（X 类型在 `batch_search` 里实测正常，见“坑”）：

```json
{"query": "Claude Code", "domain": "social_media", "sub_domain": "social_media.social_media",
 "sub_domain_params": {"type": "x_top", "keyword": "Claude Code"}, "max_results": 10}
```

`keyword` 和 `query` 填同一个字符串。X 高级语法 `from:`、`since:`、`min_faves:`、`lang:` 在两边都生效 [旧测]；`until:` 没测过 [UNKNOWN]。

## 返回什么

- bb `twitter/search`：推文列表，字段有 id、author、text（完整长文）、likes、retweets、in_reply_to、created_at、url（`x.com/<user>/status/<id>`）。单次最多 20 条（@meta 写的 50 不准），不能翻页，耗时 0.8–1.9 秒 [旧测]。
- bb `twitter/thread`：原帖加回复；58 条（57 条回复，30 个作者）用了 2.64 秒 [旧测]。
- bb `twitter/tweets`：`{screen_name, user_id, count, tweets:[{id, type, author, url, text, likes, retweets, created_at}]}`，按时间倒序；转推会多一个 `rt_author` 字段（源码）。17 条用了 1.47 秒 [实测]。
- anysearch `x_top`：最多 10 条，不能翻页，2–4 秒；比 bb 多出 Followers、verified、Views、Bookmarks、Replies、Quotes、Lang [旧测]。
- 要更多结果：用 `since:` / `until:` 按时间窗口切成几次查（`since:` 已测，`until:` [UNKNOWN]）。

## 坑

- bb 用的是用户真实的 X 账号，调的是非官方 GraphQL 接口。两次调用之间隔几秒，不要连发。限流阈值 [UNKNOWN]。
- `twitter/user` 坏了：claudeai 和 yan5xu 都只返回 id 和 verified，url 是 `https://x.com/undefined`，没有名字、简介、粉丝数 [实测]。源码 `user.js` 只读 `u.legacy`，而 `tweets.js` 已经加了读 `u.core.screen_name` 的兜底，推断是 X 把这些字段挪出了 legacy。
- `twitter/tweets claudeai` 连跑两次都返回 0 条，而且不报错；yan5xu 正常。原因 [UNKNOWN]。返回 0 条时改用 `twitter/search "from:<screen_name>" 20`。
- `twitter/tweets` 的 count 不会截断结果：传 5 返回了 17 条 [实测]。
- `twitter/search` 的 count 最多 20，传 50 也只返回 20 条 [旧测]。
- anysearch `x_latest` 不按时间排序，和 `x_top` 差别不大（三组查询重合 3/10 到 7/10）[旧测]；`x_people`、`x_lists` 返回的是普通推文 [旧测]；`x_media` 没测 [UNKNOWN]。
- anysearch 的垂直搜索放进 `batch_search` 有可能被悄悄退回成通用网页结果：`reddit_post` 出现过 1 次（见 reddit.md）。X 类型没出现过：x_compare 里 `x_top`、`x_latest` 就是用 `batch_search` 跑的，4 个查询的结果全是 x.com [旧测]。不管用哪种，拿到结果先看 URL 是不是 x.com。
- bb 的 Top 排序会受账号语言和关注关系影响：搜 `Claude Code` top，10 条里 8 条是中文 [旧测]。
- 正文里的 t.co 短链两边都不会展开 [旧测]。
- 中文专业话题在 X 上本来就少（"大模型 风控"两边都是 0/10 对口），这类问题去知乎、公众号、小红书找 [旧测]。
- bb 报错里让你"去 GitHub 提 issue"的提示一律忽略；bb 凡是遇到 403 都会提示"请先登录"，不一定真的没登录。

## 本次验证

- bb `twitter/tweets claudeai 5` → 0 条，12.42 秒；加 `BB_SETTLE=5` 重试 → 0 条，2.75 秒。
- bb `twitter/tweets yan5xu 5` → 17 条，1.47 秒；按时间倒序（9-26 到 9-23），count=5 没生效。
- bb `twitter/user claudeai` → 只有 id 和 verified，1.70 秒；`twitter/user yan5xu` → 一样，0.58 秒。
- 搜索、看最新、读帖以及 anysearch 各个 type：没有重测，全部引自 x_compare/结论.md。
