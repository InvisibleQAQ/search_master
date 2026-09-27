# 微信公众号

> 最后验证：2026-09-27。标记：[实测] 本次跑过；[旧测] 引自 2026-09-24 调研；[UNKNOWN] 没查清。

| 需求 | 首选 | 备选 | 别用 |
|---|---|---|---|
| 搜索并拿全文 | feedgrab `mpweixin-so`（34–35 秒，3 篇全文写成 md）[实测] | anysearch `social_media` + `type: wechatmp`（8 秒，部分摘要就是全文）[实测] | anysearch 通用搜索在 query 里写 `mp.weixin.qq.com`（结果全乱）[旧测] |
| 快速看标题列表 | bb `sogou/weixin`（10 条，adapter 0.5 秒 / 实际 [UNKNOWN]）[实测] | neo 搜狗微信页 [旧测] | exa 搜索（要在 query 里写域名或公众号名才搜得到）[旧测] |
| 读永久链接 `mp.weixin.qq.com/s/<id>` | exa `web_fetch_exa` [实测] | feedgrab `<url>`（5 秒）[实测]；bb 开 tab + eval `#js_content` | anysearch `extract`（失败）[旧测] |
| 读临时链接 `mp.weixin.qq.com/s?src=11&timestamp=...` | exa `web_fetch_exa` [实测] | bb eval（`BB_SETTLE=5`，eval 0.27 秒 / 实际 7 秒）[实测] | anysearch `extract`（失败）[旧测] |
| 读搜狗跳转链接 `weixin.sogou.com/link?url=...` | bb 开 tab（会自动跳到临时链接）+ eval [实测] | — | anysearch `extract`（返回验证码页，不报错）[旧测] |
| 评论（留言） | 没有可用工具 [UNKNOWN] | — | — |

三条搜索路线的数据都来自搜狗微信，排序也一样（本次第 1 条都是同一篇 2023 年的文章）。

## 命令

feedgrab 搜索（依赖当前目录；开关默认关；不设 `OUTPUT_DIR` 就不写文件，stdout 只有约 150 字预览）：

```bash
d=$(mktemp -d); cd "$d" && MPWEIXIN_SOGOU_ENABLED=true OUTPUT_DIR="$d/out" feedgrab mpweixin-so '大模型 风控' --limit 3
find "$d/out" -name '*.md'     # out/mpweixin/search_sogou/<关键词>/<公众号>_<日期>：<标题>.md
```

anysearch 搜索（`get_sub_domains` 本次两次 `fetch failed`，参数已知，直接调）：

```json
{"query": "大模型 风控", "domain": "social_media", "sub_domain": "social_media.social_media",
 "sub_domain_params": {"type": "wechatmp", "keyword": "大模型 风控"}, "max_results": 5}
```

bb 搜索（参数：`query page`）：

```bash
bash C:/Users/18368/Desktop/00_myCode/43_search_master/scripts/bb.sh sogou/weixin "大模型 风控" 1
```

exa 读（永久链接和临时链接都行，可以一次传多个）：

```json
{"urls": ["https://mp.weixin.qq.com/s/zEZ53f7EtnI2ve1QRELUSw"], "maxCharacters": 20000}
```

feedgrab 读单篇：

```bash
d=$(mktemp -d); cd "$d" && OUTPUT_DIR="$d/out" feedgrab 'https://mp.weixin.qq.com/s/<id>'; find "$d/out" -name '*.md'
```

bb 读（搜狗跳转链接、临时链接、永久链接都行；`bb.sh eval` 自己开 tab、等加载、跑完关 tab）：

```bash
BB_SETTLE=5 bash C:/Users/18368/Desktop/00_myCode/43_search_master/scripts/bb.sh eval \
  '<搜狗跳转链接或 mp.weixin.qq.com 链接>' \
  '(()=>{const q=s=>{const e=document.querySelector(s);return e?e.innerText.trim():null};return JSON.stringify({url:location.href,title:q("#activity-name"),account:q("#js_name"),time:q("#publish_time"),text:q("#js_content")})})()'
# 搜狗链接里的空格换成 %20
```

## 返回什么

- feedgrab `mpweixin-so`：每篇一个 md，frontmatter 有 `title`、`source`（临时链接）、`author`（公众号名）、`published`、`cover_image`、`summary`、`search_keyword`，正文是 Markdown（带图片链接）。3 篇各 11~14k 字节。34–35 秒（每篇间隔约 3 秒抓取）。公众号名以 frontmatter 为准，stdout 列表里的可能不对（见"坑"）。
- anysearch `wechatmp`：`标题`、`URL`、正文。URL 有两种：临时链接（本次 3/5）和搜狗跳转链接（2/5）。临时链接那几条的正文经常就是全文；搜狗跳转链接那几条只有一两句摘要。没有公众号名和日期字段。约 8 秒。
- bb `sogou/weixin`：`{query, page, count, total, results[]}`，每条 `rank`、`title`、`url`（搜狗跳转链接）、`account`（总是空）、`snippet`、`time`（实际是公众号名）、`thumbnail`。一页 10 条。
- exa fetch：标题、URL、作者、正文 Markdown。
- bb eval：标题、公众号名、发布时间、正文纯文本。eval 0.27 秒 / 实际 7 秒（`BB_SETTLE=5`）。

## 坑

- 搜索结果按相关性排序，不按时间：本次前两条是 2023 年的文章。要新内容就在关键词里加年份或具体事件，三条路线都没有时间过滤参数。
- feedgrab 必须在临时目录里跑，并设 `MPWEIXIN_SOGOU_ENABLED=true` 和 `OUTPUT_DIR`，然后去读 md 文件。
- `sogou/weixin` 字段错位：`account` 是空的，公众号名在 `time` 里，真正的发布时间拿不到。
- `sogou/weixin` 返回的 URL 里 query 参数带一个没编码的空格；本次换成 `%20` 后打开正常。
- 搜狗跳转链接和临时链接都会过期（带 `timestamp`、`signature`）。临时链接拿到约 14 分钟后还能读 [实测 1 次]，确切过期时间 [UNKNOWN]。拿到后尽快读。
- 临时链接转不成永久链接：页面里 `biz`、`mid`、`idx` 有值，但 `sn` 和 `msg_link` 是空的 [实测]。好在 exa 和 bb 都能直接读临时链接。
- 频繁打开搜狗跳转链接会不会触发验证码 [UNKNOWN]；一次任务里少开几个。
- bb eval 拿到的 `#publish_time` 是浏览器英文格式，如 "Mar 15, 2026, 7:00 PM"、"Mar 25, 2026, 8:57 PM" [实测]。
- exa 走本机代理：2026-09-26 前两次整批 `fetch failed`，第 3 次才成功；2026-09-27 05:25–05:30 断网时段读临时链接 3/3 `fetch failed`，是网络问题，不代表 exa 读不了公众号。失败时换 feedgrab 或 bb eval。
- feedgrab 的公众号名：同一篇文章 stdout 列表写 "FunLifeDC"，文件名和 frontmatter 写 "geekStudy"，bb eval 读到的 `#js_name` 也是 "geekStudy" [实测]，所以以 frontmatter 为准，stdout 列表不准。另一例：同一篇永久链接，feedgrab 文件名写"千问AI平台"，exa 显示"阿里云开发者"，哪个准 [UNKNOWN]。
- 公众号留言：本机没有工具能拿到 [UNKNOWN]。

## 本次验证

2026-09-26（bb 耗时只有 adapter，实际 [UNKNOWN]）：

- feedgrab `mpweixin-so '大模型 风控' --limit 3` → 3 篇全部抓到全文（11,488 / 13,217 / 13,855 字节），34 秒，`source` 都是临时链接。
- anysearch `wechatmp` "大模型 风控" → 5 条，8.0 秒；临时链接的 3 条正文较完整（第 4、5 条是几千字的长文全文），搜狗跳转链接的 2 条只有一两句摘要。
- bb `sogou/weixin` "大模型 风控" → 10 条，0.54 秒，`account` 全空，公众号名在 `time`。
- bb 打开搜狗跳转链接（第 2 条）→ 自动跳到临时链接，`#js_content` 3,520 字，标题、公众号名、时间齐全；`msg_link` 为空，没有 `og:url`。
- bb 直接打开 anysearch 给的临时链接 → 1,713 字；`biz`/`mid`/`idx` 有值，`sn` 为空。
- exa fetch 永久链接 zEZ53f7EtnI2ve1QRELUSw 和一条临时链接 → 两条都拿到正文（前两次 `fetch failed`）。
- feedgrab 读永久链接 zEZ53f7EtnI2ve1QRELUSw → 5 秒，16,187 字符 md。

2026-09-27（冒烟测试）：

- feedgrab `mpweixin-so 'Claude Code Skills' --limit 3` → 3/3 全文，35 秒。
- exa fetch 读其中的临时链接 → 3/3 `fetch failed`（05:25–05:30 断网时段）。
- bb eval 读同一条临时链接（`BB_SETTLE=5`）→ 3,312 字，标题、公众号名、时间齐全，时间是 "Mar 25, 2026, 8:57 PM"；eval 0.27 秒 / 实际 7 秒；链接拿到约 14 分钟后还没过期。
- 同一篇文章 feedgrab stdout 列表写公众号 "FunLifeDC"，文件名和 frontmatter 写 "geekStudy"，bb eval `#js_name` 是 "geekStudy"。
