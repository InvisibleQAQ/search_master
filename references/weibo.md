# 微博

> 最后验证：2026-09-26。标记：[实测] 本次跑过；[旧测] 引自 2026-09-24 调研；[UNKNOWN] 没查清。

| 需求 | 首选 | 备选 | 别用 |
|---|---|---|---|
| 搜索 | bb `m_weibo/search` [实测] | anysearch `social_media` + `type: weibo`（时效新，相关性很差）[实测] | — |
| 读单条全文（含长文） | bb `weibo/post <id>` [实测] | — | 只看 `m_weibo/search` 的 text（长文会被截断） |
| 评论 | bb `m_weibo/comments <id>` [实测] | bb `weibo/comments`（点赞数恒为 0）[实测] | — |
| 热搜 | bb `weibo/hot` [旧测] | anysearch `type: weibo_hot`（没有热度值）[旧测] | bb `m_weibo/hot`（rank 全是 0，URL 约 700 字）[旧测] |

bb 的 Chrome 里微博**没有登录**，以上公开接口未登录也能用。

## 命令

```bash
B=C:/Users/18368/Desktop/00_myCode/43_search_master/scripts/bb.sh
bash $B m_weibo/search "大模型 风控" 1          # 参数：q page（page 默认 1）
bash $B weibo/post 5270271187749886             # 参数：id（数字 id；URL 里的 mblogid 如 Qtu4Cww6a 按 @meta 也支持，没测）
bash $B m_weibo/comments 5270271187749886       # 参数：id max_id（翻页时填上一次返回的 max_id）
bash $B weibo/comments 5270271187749886 20      # 参数：id count max_id
bash $B weibo/hot 30                            # 参数：count（默认 30，最大 50）
```

`m_weibo/search` 返回的 `id` 可以直接给 `weibo/post` 和两个 comments 用。

anysearch（只在需要"今天有人在说什么"时用，别指望相关性）：

```json
{"query": "大模型 风控", "domain": "social_media", "sub_domain": "social_media.social_media",
 "sub_domain_params": {"type": "weibo", "keyword": "大模型 风控"}, "max_results": 5}
```

## 返回什么

- `m_weibo/search`：`{q, page, count, posts[]}`。每条有 `id`、`text`、`user`、`uid`、`created_at`、`source`（博主认证信息）、`reposts_count`、`comments_count`、`likes_count`、`pic_count`、`url`（`m.weibo.cn/status/<id>`）。一页约 16 条，约 1.2 秒。排序是综合排序，不按时间。
- `weibo/post`：`id`、`mblogid`、`text`（长文全文）、`is_long_text`、`created_at`、三个计数、`pics[]`、`user{id, screen_name, verified}`、`url`（`weibo.com/<uid>/<mblogid>`）。约 0.5 秒。
- `m_weibo/comments`：`{id, max_id, count, comments[]}`，每条 `id`、`text`、`user`、`uid`、`created_at`、`likes_count`、`reply_count`。本次一页 18 条。
- `weibo/comments`：`{post_id, count, max_id, has_more, comments[]}`，每条多了 `user{id, screen_name, verified}`、`reply_to`。一页 20 条。
- anysearch `weibo`：`m.weibo.cn/detail/<id>` 链接 + 截断正文 + 发布时间 + 点赞、评论、转发数。约 1.9 秒。

## 坑

- `m_weibo/search` 的长文会截断，以 "...全文" 结尾，要再调 `weibo/post` 取全文。
- `weibo/comments` 的 `likes_count` 永远是 0：adapter 读的是 `c.like_count`（源码第 35 行），同一条评论在 `m_weibo/comments` 里是 4 个赞。要点赞数就用 `m_weibo/comments`。
- `weibo/comments` 传 count=5 还是返回 20 条。是参数没传进去，还是微博接口不认 count [UNKNOWN]。
- `m_weibo/comments` 的 `max_id` 为空字符串时，应该是没有下一页；它没有 `has_more` 字段。
- anysearch `weibo` 像是命中任意一个词就返回：本次 5 条里没有一条同时和"大模型""风控"相关（交行信用卡优惠、数贸会新闻……）。只适合看最新动态，不适合按主题搜。
- bb 参数只能按位置写，`--page 2` 这种写法会错位。
- `m_weibo/hot` 的 rank 全是 0，URL 很长，热搜用 `weibo/hot` [旧测]。
- 微博没登录，`weibo/feed`、`favorites`、`me` 这些个人接口用不了，搜索任务也用不到。
- exa 能不能读 `weibo.com/<uid>/<mblogid>` [UNKNOWN]（本次那一批请求网络失败，重试时没带上它）。

## 本次验证

- bb `m_weibo/search` "大模型 风控" → 16 条，1.15 秒；看过的前 6 条里有 4 条以 "...全文" 截断。
- bb `weibo/post` 5270271187749886（搜索结果里被截断的一条）→ 全文，`is_long_text: true`，0.47 秒。
- bb `m_weibo/comments` 5270271187749886 → 18 条，点赞数正常。
- bb `weibo/comments` 5270271187749886 5 → 20 条，has_more true，`likes_count` 全是 0。
- anysearch `weibo` "大模型 风控" → 5 条，1.9 秒，全部不相关，都是当天的帖子。
