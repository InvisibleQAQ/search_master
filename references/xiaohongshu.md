# 小红书

> 最后验证：2026-09-27。标记：[实测] 本次跑过；[旧测] 引自 2026-09-24 调研；[源码] 只读了源码没跑；[推断] 没验证的推测；[UNKNOWN] 没查清。

| 需求 | 首选 | 备选 | 别用 |
|---|---|---|---|
| 搜索 | neo `run` 脚本 S（一次 20–40 条，带评论、收藏、分享数和发布时间）[实测] | bb `xiaohongshu/search`（20 条，只有点赞数；要按最新、点赞、评论、收藏排序时用它，neo 排序没测 [UNKNOWN]）[实测] | anysearch（没有这个平台）[旧测]；exa（只有用户主页空壳）[旧测]；feedgrab `xhs-so`（没登录）[旧测] |
| 读笔记正文 | neo 脚本 N（同一次打开顺带首屏 10 条评论）[实测] | bb `xiaohongshu/note <完整URL>` [实测] | 同上 |
| 评论 | neo 脚本 N（首屏 10 条，带 IP 属地）；要更多用脚本 P 滚动翻页 [实测] | bb `xiaohongshu/comments <完整URL>`（只有 10 条，不能翻页，没有 IP）[实测] | 同上 |

neo 和 bb 用的都是用户的真实账号，平台会记录浏览行为。neo 不自己发请求，只读页面已经加载好的 Pinia store（`#app.__vue_app__...$pinia`），bb 的 adapter 读的也是这套 store，字段一样可靠。数据接口在 `edith.xiaohongshu.com`，要 X-s/X-t 签名，不要自己 fetch。

## 命令：neo（首选）

先用 Skill 工具加载 browseros-neo，调 `name_session`。`run` 的参数写成 `{"agentName": "claude-code", "session": "<name_session 返回的值>", "code": "<脚本>"}`。三个脚本之间都要隔至少 10 秒。结果超过约 5,000 字符时 `r` 是 `{writtenToFile, path}`，去掉 `\\?\` 前缀后用 Read 或 grep 读 `path`；文件首尾各多一行 `[UNTRUSTED_PAGE_CONTENT ...]` 标记，当 JSON 解析前先去掉（`rules.md`"工具通则"）[实测]。

脚本 S（搜索）：
```js
const kw = '手冲咖啡';
const url = 'https://www.xiaohongshu.com/search_result?keyword=' + encodeURIComponent(kw);
const id = await browser.pages.newPage(url);
let w = await browser.wait(id, {for: 'selector', value: 'section.note-item', timeout: 10000});
// newPage 的导航偶尔一直卡在 about:blank：在同一个 tab 里重新导航一次
if (!w.matched) { await browser.nav(id).goto(url); w = await browser.wait(id, {for: 'selector', value: 'section.note-item', timeout: 10000}); }
const r = await browser.evaluate(id, {code: `
if (!location.hostname.endsWith('xiaohongshu.com')) return {error: 'page not loaded', href: location.href};
const p = document.querySelector('#app')?.__vue_app__?.config?.globalProperties?.$pinia;
if (!p?._s?.get('user')?.loggedIn) return {error: 'not logged in', title: document.title, head: document.body.innerText.slice(0, 200)};
const s = p._s.get('search');
const feeds = JSON.parse(JSON.stringify(s.feeds || [])).filter(it => it.modelType === 'note');
return {has_more: s.hasMore, count: feeds.length, notes: feeds.map(it => { const c = it.noteCard || {}, i = c.interactInfo || {};
  return {note_id: it.id, type: c.type, title: c.displayTitle, author: c.user?.nickname, author_id: c.user?.userId,
    likes: i.likedCount, collects: i.collectedCount, comments: i.commentCount, shares: i.sharedCount,
    time: (c.cornerTagInfo || []).find(t => t.type === 'publish_time')?.text ?? null,
    url: 'https://www.xiaohongshu.com/explore/' + it.id + '?xsec_token=' + encodeURIComponent(it.xsecToken) + '&xsec_source=pc_search'}; })};`});
const v = r.value;
// 没登录、0 条（可能是验证页）：留 tab 给用户处理，按 read-url.md 推送提醒；其他情况都关
if (!(v && (v.error === 'not logged in' || v.count === 0))) await browser.pages.close(id);
return {matched: w.matched, r};
```

脚本 N（笔记正文和首屏 10 条评论；`url` 用 S 结果里的完整 url）：
```js
const url = '<S 结果里的 url>';
const nid = url.match(/explore\/([0-9a-f]+)/)[1];
const id = await browser.pages.newPage(url);
const w = await browser.wait(id, {for: 'selector', value: '#detail-desc, .note-content, #noteContainer', timeout: 15000});
await browser.wait(id, {for: 'selector', value: '.parent-comment', timeout: 8000});
const r = await browser.evaluate(id, {code: `
const d = JSON.parse(JSON.stringify(document.querySelector('#app')?.__vue_app__?.config?.globalProperties?.$pinia?._s?.get('note')?.noteDetailMap?.['${nid}'] || null));
if (!d?.note) return {error: 'note not loaded', title: document.title, href: location.href, head: document.body.innerText.slice(0, 200)};
const n = d.note, i = n.interactInfo || {}, c = d.comments || {};
return {note: {note_id: n.noteId, title: n.title, desc: n.desc, type: n.type, author: n.user?.nickname, author_id: n.user?.userId,
    created_time: n.time, last_update_time: n.lastUpdateTime, ip_location: n.ipLocation ?? null,
    likes: i.likedCount, collects: i.collectedCount, comments: i.commentCount, shares: i.shareCount,
    tags: (n.tagList || []).map(t => t.name), images: (n.imageList || []).map(x => x.urlDefault || x.urlPre)},
  comments: {count: (c.list || []).length, has_more: c.hasMore, list: (c.list || []).map(x => ({id: x.id, author: x.userInfo?.nickname, content: x.content,
    likes: x.likeCount, sub_comment_count: x.subCommentCount, sub_preview: (x.subComments || []).map(s => (s.userInfo?.nickname || '') + ': ' + s.content),
    created_time: x.createTime, ip_location: x.ipLocation}))}};`});
await browser.pages.close(id);  // 要用 P 翻评论就去掉这一行，P 跑完再关
return {matched: w.matched, r};
```

脚本 P（评论翻页，每次多 10 条；在 N 留着的 tab 上跑，每次隔至少 10 秒，翻完 `browser.pages.close`）。从实测写法精简而来，精简后没有原样跑过：
```js
const nid = '<note_id>';
const id = (await browser.pages.list()).find(p => p.ownership === 'mine' && String(p.url).includes(nid)).pageId;
const cnt = `return document.querySelector('#app').__vue_app__.config.globalProperties.$pinia._s.get('note').noteDetailMap['${nid}'].comments.list.length`;
const before = (await browser.evaluate(id, {code: cnt})).value;
await browser.evaluate(id, {code: 'window.scrollTo(0, document.scrollingElement.scrollHeight); return 1'});
let after = before;
for (let k = 0; k < 8 && after <= before; k++) { await sleep(1000); after = (await browser.evaluate(id, {code: cnt})).value; }
return {before, after};  // 然后用 N 里那段 evaluate 取数据
```

## 命令：bb（备选，要排序时用）

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

- neo S：`{has_more, count, notes[]}`，每条有 `note_id`、`type`、`title`、`author`、`author_id`、`likes`、`collects`、`comments`、`shares`、`time`、`url`（带 xsec_token 和 `xsec_source=pc_search`）。`time` 格式不统一："06-15"（今年省略年份）、"2025-11-19"、"6天前"。页面自己加载 2 页，正常一共 40 条、约 2 万字符；2026-09-27 一次只拿到 20 条、10,289 字符（`has_more: true`），可能是第一张卡片出现后马上取数、第二页还没加载 [推断，没再调一次验证]。两种情况都超过约 5,000 字符，都会写进文件。
- neo N：`note` 的字段和 bb `note` 一样（毫秒时间戳），外加 `comments.list[]`：`likes`、`sub_comment_count`、1 条预载的楼中楼、`ip_location`、`created_time`。
- bb `search`：`{keyword, sort, sort_label, count, has_more, notes[]}`。每条有 `note_id`、`xsec_token`、`title`、`type`（normal / video）、`url`、`author`、`author_id`、`likes`（字符串）、`time`（一直是 null）。一次 20 条，没有翻页参数。adapter 约 10 秒 / 实际约 22 秒。
- bb `note`：`title`、`desc`（正文）、`type`、`author`、`author_id`、`likes`、`comments`（评论数）、`collects`、`shares`、`tags[]`、`images[]`、`created_time`/`last_update_time`（毫秒时间戳）、`ip_location`。adapter 约 2.6 秒 / 实际 [UNKNOWN]。
- bb `comments`：`{note_id, count, has_more, cursor, comments[]}`。每条有 `id`、`author`、`author_id`、`content`、`likes`（字符串）、`sub_comment_count`、`created_time`（毫秒）。只有首屏约 10 条一级评论。adapter 约 3–4 秒 / 实际 [UNKNOWN]。

## 坑

- 两次小红书调用间隔至少 10 秒，neo 和 bb 一样。真实账号，频率太高有风控风险。neo 的 N 一次拿到正文和 10 条评论，只算 1 次调用；bb 要调 `note` 和 `comments` 2 次。
- 搜索页打开后会自己连发 2 次搜索请求（40 条），这个间隔控制不了；取数太早可能只有第 1 页的 20 条 [推断]。结果里混着 `hot_query` 等非笔记项，要按 `modelType === 'note'` 过滤（脚本 S 已经做了）。
- 带 token 的链接：store 里是 `xsecToken`，DOM 里在 `section.note-item a.cover`（`/search_result/<id>?xsec_token=…`）。卡片里第一个 `a` 是 `/explore/<id>`，不带 token，打不开；只有带 `xsec_token` 的完整链接能打开 [实测]。neo 和 bb 对同一篇拿到的 token 相同 [实测]；多久失效 [UNKNOWN]，拿到后尽快读。
- neo `newPage` 的导航偶尔一直停在 about:blank（1 分钟后还是，同一时刻 example.com 0.4 秒就打开了）；`browser.nav(id).goto(url)` 在同一个 tab 里重新导航，5 秒就好了 [实测 1 次]。页面没打开时不要报成"没登录"，脚本 S 先查 hostname。
- neo 翻评论要滚 `window`：`window.scrollTo(0, document.scrollingElement.scrollHeight)`。`.note-scroller` 的 `clientHeight` 等于 `scrollHeight`，滚不动。
- neo 新开的 tab 在后台，页面里的 `setTimeout` 会被节流到约 1 秒一次；要轮询就在 run 里 `sleep()`，别在 evaluate 里循环（在页面里循环 28 次，每次 250ms，结果超过了 30 秒）[实测]。
- 笔记本身的 IP 属地：neo 和 bb 在 3 篇笔记上都是空的 [实测]，评论的 IP 属地有。
- 图文笔记的正文可能全在图片里：69e43882… 的 `desc` 只有 4 个话题标签，正文在 23 张图里 [实测]。没有 OCR，这种笔记交回时"是否读过全文"写"部分（正文在图里）"，附图片 URL。
- bb：必须用自己的 tab（bb.sh 会自动开）。adapter 会用 `router.push` 让 tab 跳转，不加 `--tab` 会把用户正在看的小红书页面跳走。
- bb：`note` 和 `comments` 要传完整 URL（带 `xsec_token`）。只传 note_id 时，adapter 要从当前页面数据里找 token，新开的 tab 里找不到 [源码]。
- bb：`search` 的 `time` 永远是 null；`comments` 有 `cursor` 和 `has_more`，但 adapter 没有 cursor 参数，翻不了页。
- `likes` 是字符串，大数可能是"1.2万"这种格式 [UNKNOWN]。视频笔记能不能拿到视频流 [UNKNOWN]。
- 不要跑 `xiaohongshu/me`、`feed`、`user_posts`，搜索任务用不到，只会多留浏览记录。

## 本次验证

- bb `search` "手冲咖啡" `comments` → 20 条，has_more，sort 生效，`time` 全是 null，adapter 9.72 秒 / 实际 22 秒。
- bb `note` 69e7791c0000000021007bde → 成功，adapter 2.60 秒 / 实际 [UNKNOWN]，`comments: "1873"`，`desc` 只有 5 个话题标签，`images` 1 张，`ip_location` null。
- bb `comments` 同一篇 → 10 条一级评论，has_more true，带 cursor 和 `sub_comment_count`，点赞数正常。
- 三次 bb 调用的间隔：search→note 约 70 秒，note→comments 约 28 秒。
- neo（维护测试，同日晚些时候，子 agent）："手冲咖啡"搜索 → 40 条，5.5 秒（newPage 3.2 秒）；bb 同一关键词 20 条、21.7 秒，19 条和 neo 重合，xsec_token 一致。笔记 6a2230940000000007024b22 → 3.9 秒，906 字正文和全部字段，首屏 10 条评论；滚到页底约 4 秒后评论变成 20 条，id 不重复。任意两次小红书调用间隔都在 30 秒以上，没遇到验证码。[实测]
- neo（主 agent 原样复测 S、N）：S 第一次 newPage 卡在 about:blank，1 分钟后还是（同时 example.com 0.4 秒打开）；同一 tab `nav().goto` 后 5.3 秒到 30 条卡片，取数 40 条、11 个字段齐全、每条都有时间和评论数，约 2 万字符写进文件。N 读 68e7a7d10000000003019680 → 5.6 秒，正文 213 字、4 张图、3 个标签，10 条评论都有 IP 属地和子评论数，笔记 IP 属地为空。[实测]
- 改完后把脚本 S 从本文件原样抽出来再跑一次：第一次导航就到了（`matched: true`），40 条约 2 万字符写进文件，tab 已关。[实测]
- 2026-09-27（冒烟测试，neo）：
  - 脚本 S "Claude Code Skills" → 第一次导航就到了（`matched: true`），5.2 秒；只拿到 20 条、10,289 字符，`has_more: true`，写成了文件，文件首尾各多一行 `[UNTRUSTED_PAGE_CONTENT ...]`。
  - 脚本 N 读 69e43882…（距 S 超过 4 分钟）→ 3.5 秒；笔记 `ip_location` 为 null；10 条评论都有 IP 属地，`has_more: true`；`desc` 只有 4 个话题标签，正文在 23 张图里，读全文只算部分完成。
