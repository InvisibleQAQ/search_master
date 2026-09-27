# 知乎

> 最后验证：2026-09-27。标记：[实测] 本次跑过；[旧测] 引自 2026-09-24 调研；[UNKNOWN] 没查清。

| 需求 | 首选 | 备选 | 别用 |
|---|---|---|---|
| 搜索 | bb `zhihu/search`（约 1.5 秒，带类型、赞同数、评论数、时间，只有摘要；全文按下一行逐篇读）[实测] | neo 读搜索页 `https://www.zhihu.com/search?type=content&q=<关键词>`（脚本见 `read-url.md`；只测过能读出页面文字，没有结构化字段）[实测] | anysearch `zhihu`（2026-09-27 用户定为不用：没有时间和赞同数，每条都是全文、挑之前就占满上下文，表格可能丢，走代理常 `fetch failed`）[实测]；exa 搜索（知乎覆盖很薄）[旧测]；feedgrab `zhihu-so`（没登录，0 条）[旧测] |
| 读指定专栏文章 | bb 开 tab + eval `.Post-RichText` [实测] | feedgrab `<url>`（6 秒）[实测]；neo（脚本见 `read-url.md`，2 篇新专栏全文都读到）[实测] | exa fetch（新文章 `CRAWL_UNKNOWN_ERROR`）[实测]；anysearch `extract`（`extract_failed`）[实测]；WebFetch（403）[旧测] |
| 读指定回答 | bb 开回答页 + eval `.RichContent-inner` [实测] | neo（脚本见 `read-url.md`，回答页没测过）[UNKNOWN] | bb `zhihu/question`（403，code 10003）[旧测] |
| 一个问题下的多个回答 | bb 在知乎 tab 里同源 fetch `questions/<qid>/answers` [实测] | — | bb `zhihu/question`（403）[旧测] |
| 评论 | bb 在知乎 tab 里同源 fetch `comment_v5` [实测] | — | 没有现成 adapter |
| 热榜 | bb `zhihu/hot`（私有 adapter，源码在本仓库 `adapters/zhihu/hot.js`，修了 ID 精度）[实测] | — | 社区版 bb `zhihu/hot`（19 位 ID 精度丢失，URL 是错的，已被私有版覆盖）[实测]；anysearch `zhihu_hot`（知乎不用 anysearch，理由见"搜索"行）[旧测] |

## 命令

bb 搜索（参数顺序：`keyword count`，count 默认 10，最大 20）：

```bash
bash C:/Users/18368/Desktop/00_myCode/43_search_master/scripts/bb.sh zhihu/search "大模型 风控" 20
```

bb 热榜（参数：`count`，默认 20，最大 50）：

```bash
bash C:/Users/18368/Desktop/00_myCode/43_search_master/scripts/bb.sh zhihu/hot 20
```

bb 读专栏 / 回答全文（`bb.sh eval` 自己开 tab、等加载、跑完关 tab）：

```bash
BB_SETTLE=3 bash C:/Users/18368/Desktop/00_myCode/43_search_master/scripts/bb.sh eval \
  'https://zhuanlan.zhihu.com/p/1986357544051024545' \
  '(()=>{const e=document.querySelector(".Post-RichText")||document.querySelector(".RichContent-inner")||document.querySelector(".RichText");return JSON.stringify({title:document.title,len:e?e.innerText.length:-1,text:e?e.innerText:""})})()'
# 回答页 URL：https://www.zhihu.com/question/<qid>/answer/<aid>
```

bb 读评论 / 问题下的回答：同样用 `bb.sh eval`，URL 写 `https://www.zhihu.com/`，JS 换成下面这段（`<id>`、`<aid>`、`<qid>` 自己替换，不用的删掉）：

```js
(async()=>{const f=async u=>{const r=await fetch(u,{credentials:"include"});const j=await r.json();return {status:r.status,paging:j.paging,data:j.data}};return JSON.stringify({
 article_comments: await f("/api/v4/comment_v5/articles/<id>/root_comment?order_by=score&limit=20"),
 answer_comments:  await f("/api/v4/comment_v5/answers/<aid>/root_comment?order_by=score&limit=20"),
 answers: await f("/api/v4/questions/<qid>/answers?limit=5&offset=0&sort_by=default&include=data%5B*%5D.content%2Cvoteup_count%2Ccomment_count")})})()
```

feedgrab 读单篇（依赖当前目录，必须设 `OUTPUT_DIR`，否则不写文件）：

```bash
d=$(mktemp -d); cd "$d" && OUTPUT_DIR="$d/out" feedgrab 'https://zhuanlan.zhihu.com/p/<id>'; find "$d/out" -name '*.md'
```

## 返回什么

- bb `zhihu/search`：`{keyword, count, has_more, results[]}`，每条有 `type`（article/answer/question）、`id`（字符串）、`title`、`excerpt`（一两句）、`url`、`author`、`voteup_count`、`comment_count`、`question_id`、`question_title`、`created_time`/`updated_time`（秒级 UTC 时间戳，和页面 `meta[itemprop=datePublished]` 一致）。要 20 回 17。adapter 约 1.5 秒，加上开 tab 实际约 7 秒。
- bb `zhihu/hot`（私有版）：`{count, items[]}`，每条有 `rank`、`id`（字符串，19 位）、`type`、`title`、`url`、`excerpt`、`answer_count`、`follower_count`、`heat`（如"5590 万热度"）、`trend`、`is_new`。adapter 约 0.5 秒。
- bb eval：纯文本全文，表格会变成 Tab 分隔，图片只剩位置。eval 本身约 0.3 秒，加上开 tab、`BB_SETTLE=3` 和排队，每篇实际 7–23 秒。
- `comment_v5`：`data[]` 的字段有 `id`、`content`（HTML）、`created_time`、`hot`、`top`、`score` 等；`paging` 里有 `is_end`、`totals`。点赞数、作者字段名没有逐个核对 [UNKNOWN]。
- `questions/<qid>/answers`：`data[]` 有 `content`（HTML）、`author`、`comment_count`、`content_need_truncated` 等，`paging.totals` 是回答总数。`content_need_truncated` 为 true 时内容会不会被截断 [UNKNOWN]。
- feedgrab：带 frontmatter 的 Markdown，写到 `out/Zhihu/<标题>.md`。

## 坑

- 搜索只给摘要，全文要逐篇 eval，每篇都开一个 tab、在全局锁上排队。先按 `voteup_count`、`created_time`、`type` 挑 3–5 篇再读，别把 17 条全读一遍。
- `author` 带 `<em>` 高亮标签没去掉（例如 `<em>代码</em>科小土豆`），用之前自己剥掉 [实测]。
- `created_time` 是 UTC 秒，按 SKILL.md"时间"一条换成本机时区（Python `datetime.fromtimestamp(ts)`）。本机是美东，同一时刻的日期可能比北京时间早一天，交回时写本机日期，不要混用。页面 `.ContentItem-time` 同样按本机时区显示；后面的"・北京"是作者 IP 属地，不是时区 [实测]。
- bb `zhihu/search` 只取第一页，`has_more: true` 也没有翻页参数；会过滤掉非 `search_result` 条目，所以条数比 count 少。
- bb 参数只能按位置写，`--count 20` 会错位。
- `zhihu/question` 的问题详情接口要签名（403，code 10003），但 `questions/<qid>/answers` 接口不要，本次返回 200 [实测]。
- 热榜接口的 `target.id` 是 19 位数字，超过 JS 数字精度（`2087214676530525535` 解析成 `2087214676530525400`），社区版 `zhihu/hot` 因此生成错的 URL。私有版改从字符串字段 `target.url` 取 ID（`card_id` 如 `Q_<id>` 也是完整的）。私有 adapter 的源码在本仓库 `adapters/`，`~/.bb-browser/sites` 是指向它的 junction，优先于社区目录 `bb-sites/`；`bb-browser site list --json` 里 `source` 为 `local` 就说明生效了 [实测]。自己写知乎接口的 eval 时同样别用数字型 ID。
- 专栏页用 `.Post-RichText`，回答页用 `.RichContent-inner`；上面那段 JS 按顺序兜底，两种页面都能用。
- exa fetch 只对它已经缓存过的旧文章有效，新文章返回 `CRAWL_UNKNOWN_ERROR`。
- feedgrab 读知乎的 Markdown 里夹着大量 `zhida.zhihu.com/search?...` 链接，同一篇 24k 字符，比 bb eval 的纯文本（9k 字）长得多。
- bb 的 Chrome 里知乎是登录状态（页面标题带"(99+ 封私信 / …)"前缀）；未登录时这些接口能不能用 [UNKNOWN]。

## 本次验证

2026-09-27（冒烟测试，"Claude Code Skills"）：

- bb `zhihu/search` "Claude Code Skills" 20 → 17 条，`has_more: true`，adapter 1.17 秒，实际约 7 秒。`author` 带 `<em>`。
- bb eval 5 篇专栏 → 全部拿到正文（最长 10,594 字），eval 0.25–0.34 秒，实际 7–23 秒；没有验证码、登录框。`created_time` 1775526554 = 2026-04-07T01:49:14Z，和页面 meta 一致。
- anysearch `zhihu` max 5 → 4 条，1.6 秒，URL 都是知乎；没有时间，其中一篇正文里一张表的内容缺失（知乎做成了图片还是 anysearch 丢了 [UNKNOWN]）。`get_sub_domains` 两次 `fetch failed`。
- 路由改动：用户决定搜索改用 bb，anysearch `zhihu` 移到"别用"。理由见路由表。
- 热榜探测：接口原文 ID `2087214676530525535`，`JSON.parse` 后 `2087214676530525400`；`target.url`、`card_id` 是完整的。
- 私有 `zhihu/hot` 5 → 5 条，ID 都是 19 位字符串，adapter 0.48 秒；`site list` 显示 `source: local`。打开第 2 条 URL，页面标题和热榜标题一致。热榜随之改用 bb，知乎不再用 anysearch。

2026-09-26：

- anysearch `zhihu` "大模型 风控"，max 10 → 8 条，1.7 秒，专栏和回答都是全文。`get_sub_domains` 两次 `fetch failed`（网络），直接调 `batch_search` 成功。
- bb `zhihu/search` "大模型 风控" 20 → 17 条（article 14、answer 2、question 1），1.46 秒。
- bb eval 专栏 1986357544051024545 → 9,136 字，eval 0.28 秒。
- bb eval 回答页 2066807020787865217 → 2,117 字（`.RichContent-inner`），eval 0.23 秒。
- bb 同源 fetch：文章评论 200（1 条，totals 1）、回答评论 200（1 条）、问题下回答 200（2 条，totals 2），合计 0.9 秒。
- exa fetch 专栏 1986357544051024545 → `CRAWL_UNKNOWN_ERROR`（前两次整批 `fetch failed`，第 3 次才拿到结果）。
- feedgrab 专栏 1986357544051024545 → 6 秒，24,236 字符 Markdown。
- 新专栏 2086494817098396427、2085007317200790369：exa 都是 `CRAWL_UNKNOWN_ERROR`；anysearch `extract` 测了第一篇，`extract_failed`；neo（`read-url.md` 的脚本）全文 17,627 / 20,222 字，读的时候是登录状态。
- neo 读知乎搜索页：等加载后 4,498 字（见 `read-url.md` 的坑）。
