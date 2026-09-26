# 知乎

> 最后验证：2026-09-26。标记：[实测] 本次跑过；[旧测] 引自 2026-09-24 调研；[UNKNOWN] 没查清。

| 需求 | 首选 | 备选 | 别用 |
|---|---|---|---|
| 搜索并直接拿全文 | anysearch `social_media` + `type: zhihu`（摘要就是全文）[实测] | bb `zhihu/search`（1.5 秒，带赞同数和评论数，只有摘要）[实测] | exa 搜索（知乎覆盖很薄）[旧测]；feedgrab `zhihu-so`（没登录，0 条）[旧测] |
| 读指定专栏文章 | bb 开 tab + eval `.Post-RichText` [实测] | feedgrab `<url>`（6 秒）[实测]；neo `run` [旧测] | exa fetch（新文章 `CRAWL_UNKNOWN_ERROR`）[实测]；anysearch `extract`（`extract_failed`）[旧测]；WebFetch（403）[旧测] |
| 读指定回答 | bb 开回答页 + eval `.RichContent-inner` [实测] | anysearch `zhihu`（前提是这条回答能被搜出来） | bb `zhihu/question`（403，code 10003）[旧测] |
| 一个问题下的多个回答 | bb 在知乎 tab 里同源 fetch `questions/<qid>/answers` [实测] | — | bb `zhihu/question`（403）[旧测] |
| 评论 | bb 在知乎 tab 里同源 fetch `comment_v5` [实测] | — | 没有现成 adapter |
| 热榜 | anysearch `type: zhihu_hot` [旧测] | — | bb `zhihu/hot`（19 位 ID 精度丢失，URL 是错的）[旧测] |

## 命令

anysearch 搜索（`get_sub_domains` 本次连续两次 `fetch failed`，但参数已知，可以直接调 `search`/`batch_search`）：

```json
{"query": "大模型 风控", "domain": "social_media", "sub_domain": "social_media.social_media",
 "sub_domain_params": {"type": "zhihu", "keyword": "大模型 风控"}, "max_results": 5}
```

bb 搜索（参数顺序：`keyword count`，count 默认 10，最大 20）：

```bash
bash C:/Users/18368/Desktop/00_myCode/43_search_master/scripts/bb.sh zhihu/search "大模型 风控" 20
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

- anysearch `zhihu`：每条是 `标题`、`URL`、正文。正文格式是"标题 作者: xxx + 一段命中片段 + 全文"。专栏的 URL 是 `https://www.zhihu.com/articles/<id>`（等于 `zhuanlan.zhihu.com/p/<id>`），回答是 `/question/<qid>/answer/<aid>`。没有赞同数、评论数、时间。`max_results` 最大 10，本次要 10 回 8。约 1.7 秒。
- bb `zhihu/search`：`{keyword, count, has_more, results[]}`，每条有 `type`（article/answer/question）、`id`（字符串）、`title`、`excerpt`（一两句）、`url`、`author`、`voteup_count`、`comment_count`、`question_id`、`question_title`、`created_time`/`updated_time`（秒级时间戳）。要 20 回 17。约 1.5 秒。
- bb eval：纯文本全文，表格会变成 Tab 分隔，图片只剩位置。eval 本身约 0.3 秒，加上开 tab 和等待约 5 秒。
- `comment_v5`：`data[]` 的字段有 `id`、`content`（HTML）、`created_time`、`hot`、`top`、`score` 等；`paging` 里有 `is_end`、`totals`。点赞数、作者字段名没有逐个核对 [UNKNOWN]。
- `questions/<qid>/answers`：`data[]` 有 `content`（HTML）、`author`、`comment_count`、`content_need_truncated` 等，`paging.totals` 是回答总数。`content_need_truncated` 为 true 时内容会不会被截断 [UNKNOWN]。
- feedgrab：带 frontmatter 的 Markdown，写到 `out/Zhihu/<标题>.md`。

## 坑

- anysearch `zhihu` 每条都是全文，8 条能到几万字，很占上下文。先用 `max_results: 3~5`。
- anysearch 的标题带 `<em>` 高亮，正文里的 `&#34;`、`&lt;`、`&gt;` 没有反转义，代码段要自己还原。
- anysearch 能不能搜到某一篇取决于它的索引。要读"指定的一篇"，直接用 bb eval，别指望 anysearch 能搜出来。
- bb `zhihu/search` 只取第一页，`has_more: true` 也没有翻页参数；会过滤掉非 `search_result` 条目，所以条数比 count 少。
- bb 参数只能按位置写，`--count 20` 会错位。
- `zhihu/question` 的问题详情接口要签名（403，code 10003），但 `questions/<qid>/answers` 接口不要，本次返回 200 [实测]。
- `zhihu/hot` 的 ID 超过 JS 数字精度，生成的 URL 是错的 [旧测]。
- 专栏页用 `.Post-RichText`，回答页用 `.RichContent-inner`；上面那段 JS 按顺序兜底，两种页面都能用。
- exa fetch 只对它已经缓存过的旧文章有效，新文章返回 `CRAWL_UNKNOWN_ERROR`。
- feedgrab 读知乎的 Markdown 里夹着大量 `zhida.zhihu.com/search?...` 链接，同一篇 24k 字符，比 bb eval 的纯文本（9k 字）长得多。
- bb 的 Chrome 里知乎是登录状态；未登录时这些接口能不能用 [UNKNOWN]。

## 本次验证

- anysearch `zhihu` "大模型 风控"，max 10 → 8 条，1.7 秒。专栏 1986357544051024545 的结尾和 bb eval 拿到的结尾逐字相同，回答 2066807020787865217 也是全文 → "摘要就是全文"成立。
- anysearch `get_sub_domains` → 两次 `fetch failed`（网络），直接调 `batch_search` 成功。
- bb `zhihu/search` "大模型 风控" 20 → 17 条（article 14、answer 2、question 1），1.46 秒。
- bb eval 专栏 1986357544051024545 → 9,136 字，eval 0.28 秒。
- bb eval 回答页 2066807020787865217 → 2,117 字（`.RichContent-inner`），eval 0.23 秒。
- bb 同源 fetch：文章评论 200（1 条，totals 1）、回答评论 200（1 条）、问题下回答 200（2 条，totals 2），合计 0.9 秒。
- exa fetch 专栏 1986357544051024545 → `CRAWL_UNKNOWN_ERROR`（前两次整批 `fetch failed`，第 3 次才拿到结果）。
- feedgrab 专栏 1986357544051024545 → 6 秒，24,236 字符 Markdown。
