# 小红书

> 最后验证：2026-09-26。标记：[实测] 本次跑过；[旧测] 引自 2026-09-24 调研；[UNKNOWN] 没查清。

| 需求 | 首选 | 备选 | 别用 |
|---|---|---|---|
| 搜索 | bb `xiaohongshu/search` [实测] | neo（浏览器里已登录小红书，没测过）[UNKNOWN] | anysearch（没有这个平台）[旧测]；exa（只有用户主页空壳）[旧测]；feedgrab `xhs-so`（没登录）[旧测] |
| 读笔记正文 | bb `xiaohongshu/note <完整URL>` [实测] | — | 同上 |
| 评论 | bb `xiaohongshu/comments <完整URL>` [实测] | — | 同上 |

只有 bb-browser 能用。bb 的 Chrome 用的是用户的真实账号，平台会记录浏览行为。

## 命令

三条命令都要带这两个环境变量：先开 `explore` 页拿自己的 tab，再等 6 秒让前端加载完，否则会报 `Not logged in`。

```bash
# 搜索。参数顺序：keyword sort；sort 可选 general（默认）/ latest / likes / comments / collects
BB_OPEN_URL=https://www.xiaohongshu.com/explore BB_SETTLE=6 bash C:/Users/18368/Desktop/00_myCode/43_search_master/scripts/bb.sh xiaohongshu/search "手冲咖啡" general

# 等至少 10 秒再跑下一条
# 读笔记。参数：note_id（传搜索结果里的完整 url，带 xsec_token，必须加引号）
BB_OPEN_URL=https://www.xiaohongshu.com/explore BB_SETTLE=6 bash C:/Users/18368/Desktop/00_myCode/43_search_master/scripts/bb.sh xiaohongshu/note 'https://www.xiaohongshu.com/explore/<note_id>?xsec_token=<token>&xsec_source='

# 等至少 10 秒
# 读评论。参数：note_id（同上，传完整 url）
BB_OPEN_URL=https://www.xiaohongshu.com/explore BB_SETTLE=6 bash C:/Users/18368/Desktop/00_myCode/43_search_master/scripts/bb.sh xiaohongshu/comments 'https://www.xiaohongshu.com/explore/<note_id>?xsec_token=<token>&xsec_source='
```

两次调用之间可以插别的平台的调用来凑够 10 秒，不需要干等。

## 返回什么

- `search`：`{keyword, sort, sort_label, count, has_more, notes[]}`。每条有 `note_id`、`xsec_token`、`title`、`type`（normal / video）、`url`（带 xsec_token）、`author`、`author_id`、`likes`（字符串）、`time`（一直是 null）。一次 20 条，没有翻页参数。adapter 自己约 10 秒，加上开 tab 和等待约 20 秒。
- `note`：`title`、`desc`（正文）、`type`、`author`、`author_id`、`likes`、`comments`（评论数）、`collects`、`shares`、`tags[]`、`images[]`（图片 URL）、`created_time`/`last_update_time`（毫秒时间戳）、`ip_location`。约 2.6 秒。
- `comments`：`{note_id, count, has_more, cursor, comments[]}`。每条有 `id`、`author`、`author_id`、`content`、`likes`（字符串）、`sub_comment_count`、`created_time`（毫秒）。只返回页面首屏的约 10 条一级评论，不展开楼中楼。约 3~4 秒。

## 坑

- 两次小红书调用间隔至少 10 秒。真实账号，频率太高有风控风险。
- 必须用自己的 tab（bb.sh 会自动开）。adapter 会用 `router.push` 让 tab 跳转，不加 `--tab` 会把用户正在看的小红书页面跳走。
- `note` 和 `comments` 要传完整 URL（带 `xsec_token`）。只传 note_id 时，adapter 要从当前页面数据里找 token，新开的 tab 里找不到（报错提示原文："Pass a full note URL, or search/feed that note first"）[源码]。
- `xsec_token` 多久失效 [UNKNOWN]。拿到搜索结果后尽快读。
- `search` 的 `time` 永远是 null，发布时间要从 `note` 的 `created_time` 取。
- 图文笔记的文字常常在图片里，`desc` 可能只有几个话题标签（本次那篇就是），要看图片 URL。没有 OCR。
- `images` 数量不稳定：本次 1 张，上次那篇 6 张。是不是只返回了部分图片 [UNKNOWN]。
- `comments` 返回了 `cursor` 和 `has_more`，但 adapter 没有 cursor 参数，翻不了页。
- 搜索结果里没有评论数。想找评论多的笔记，用 `sort=comments`（本次返回 `sort_label: "Most Comments"`，排序生效）。
- `likes` 是字符串，大数可能是"1.2万"这种格式 [UNKNOWN]。
- 视频笔记能不能拿到视频流 [UNKNOWN]。
- 不要跑 `xiaohongshu/me`、`feed`、`user_posts`，搜索任务用不到，只会多留浏览记录。

## 本次验证

- `search` "手冲咖啡" `comments` → 20 条，has_more，sort 生效，`time` 全是 null，adapter 9.72 秒（含开 tab 共 22 秒）。
- `note` 69e7791c0000000021007bde（上一步评论最多的笔记）→ 成功，2.60 秒，`comments: "1873"`，`desc` 只有 5 个话题标签，`images` 1 张，`ip_location` null。
- `comments` 同一篇 → 10 条一级评论，has_more true，带 cursor 和 `sub_comment_count`，点赞数正常。上次调研留下的"有评论的笔记上是否正常"已确认：正常。
- 三次调用的间隔：search→note 约 70 秒，note→comments 约 28 秒。
- neo 读小红书：没测，保留 [UNKNOWN]。
