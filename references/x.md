# X / Twitter

> 最后验证：2026-09-27。标记：[实测] 本次跑过；[旧测] 引自 2026-09-24 调研（`C:/Users/18368/Desktop/00_myCode/42_expert/搜索工具调研原始报告/x_compare/结论.md`）；[UNKNOWN] 没查清。
> 原则：bb 能用的用 bb，bb 不能用的用 BrowserOS neo（用户已在 neo 里登录 X）。

| 需求 | 首选 | 备选 | 别用 |
|---|---|---|---|
| 关键词搜讨论 | bb `twitter/search "<q>" 20 top` 和 anysearch `x_top` **并行跑**，合并去重（本次重合 0/10：bb 偏中文，`x_top` 全英文且多引流帖）[实测] | neo 搜索页 `&f=top`（脚本见下，带回复、书签、浏览数）[实测] | exa（抓不到 X）[旧测] |
| 看最新（刚发生的） | bb `twitter/search "<q>" 20`（默认 Latest，严格按时间倒序）[实测] | neo 搜索页 `&f=live`（严格倒序）[实测] | anysearch `x_latest`（不按时间排）[实测] |
| 读帖子和评论区 | bb `twitter/thread <id 或 URL>`（245 条回复的帖拿到 124 条）[实测] | neo 帖子页：只用来拿原帖的完整互动数，回复加载不稳 [实测]；anysearch `extract` [旧测] | exa fetch（`SOURCE_NOT_AVAILABLE`）[旧测] |
| 某人最近发了什么 | bb `twitter/tweets <screen_name>`；返回 0 条（发串帖的账号，如 claudeai）就用 neo 读主页 `https://x.com/<screen_name>` [实测] | bb `twitter/search "from:<screen_name>" 20`（串帖的后续段占大半，覆盖的天数短）[实测] | — |
| 某人的资料（粉丝数等） | 没有可靠工具。间接办法：anysearch `x_top` 搜 `from:<screen_name>`，结果里带 Followers、verified [旧测] | — | bb `twitter/user`（坏了）[实测]；anysearch `x_people`（返回的是普通推文）[实测] |
| 看互动数据 | 按关键词找帖：anysearch `x_top`（唯一带 Followers、Quotes）；看某个帖子或某人的帖：neo（回复、转帖、喜欢、书签、浏览）[实测] | — | bb（只有点赞和转发） |
| bb 的 Chrome 没开 / 不想动真实账号 | anysearch `x_top` [旧测] | — | — |

## 命令：bb

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

anysearch：先调一次 `get_sub_domains {"domains": ["social_media"]}`，再用 `search` 或 `batch_search`：

```json
{"query": "Claude Code", "domain": "social_media", "sub_domain": "social_media.social_media",
 "sub_domain_params": {"type": "x_top", "keyword": "Claude Code"}, "max_results": 10}
```

`keyword` 和 `query` 填同一个字符串。X 高级语法 `from:`、`since:`、`min_faves:`、`lang:` 在两边都生效 [旧测]；`until:` 没测过 [UNKNOWN]。

## 命令：neo（bb 读不到时）

先用 Skill 工具加载 browseros-neo，调 `name_session`。只改 `U`（和想要的条数 `N`），两次 X 调用隔 5 秒以上。在搜索 Latest、搜索 Top、主页三种页面上原样跑过 [实测]；帖子页的第 1 条是原帖，回复加载不稳。

```js
// U 可选：搜索 Top  'https://x.com/search?q=' + encodeURIComponent('<q>') + '&f=top'
//        搜索最新 'https://x.com/search?q=' + encodeURIComponent('<q>') + '&f=live'
//        主页     'https://x.com/<screen_name>'（置顶帖 context='已置顶'，同一串按正序）
//        帖子     'https://x.com/<user>/status/<id>'
const U = 'https://x.com/search?q=' + encodeURIComponent('Claude Code') + '&f=live';
const N = 20, t0 = Date.now();
const id = await browser.pages.newPage(U);
try {
  const SEL = {for: 'selector', value: 'article[data-testid="tweet"]', timeout: 10000};
  let w = await browser.wait(id, SEL);
  if (!w.matched) { await browser.nav(id).goto(U); w = await browser.wait(id, SEL); } // newPage 偶尔卡在 about:blank
  // 帖子页的原帖（tabindex=-1）时间在底部、不包 <a>，引用卡片的 <time> 排在前面，所以取最后一个 <time>、URL 用页面地址
  const GRAB = `window.__x = window.__x || new Map();
  for (const a of document.querySelectorAll('article[data-testid="tweet"]')) {
    const focal = a.getAttribute('tabindex') === '-1', ts = a.querySelectorAll('time'), tm = focal ? ts[ts.length - 1] : ts[0];
    const url = focal ? location.origin + location.pathname : tm?.closest('a')?.href;
    if (!tm || !url || window.__x.has(url)) continue;
    const g = a.querySelector('[role="group"][aria-label]')?.getAttribute('aria-label') || '', n = {};
    for (const p of g.split(/,\\s+|[，、]/)) { // 例：3 回复、10 次转帖、45 喜欢、53 书签、2841 次观看；为 0 的项不出现
      const m = p.match(/([\\d,.]+)\\s*(\\S.*)/); if (!m) continue;
      const k = /repl|回复/i.test(m[2]) ? 'replies' : /repost|retweet|转/i.test(m[2]) ? 'retweets'
        : /like|喜欢/i.test(m[2]) ? 'likes' : /bookmark|书签/i.test(m[2]) ? 'bookmarks' : /view|查看|观看/i.test(m[2]) ? 'views' : '';
      if (k) n[k] = +m[1].replace(/,/g, '');
    }
    window.__x.set(url, {url, time: tm.getAttribute('datetime'),
      author: a.querySelector('[data-testid="User-Name"] a[href^="/"]')?.getAttribute('href').slice(1),
      context: a.querySelector('[data-testid="socialContext"]')?.innerText,
      text: a.querySelector('[data-testid="tweetText"]')?.innerText || '', ...n});
  }
  return window.__x.size;`;
  // 时间线是虚拟列表，滚走的 article 会被移出 DOM，所以在页面里按 url 累积。
  // MORE 在页面里用 setTimeout 等新帖，最多 3 秒：后台 tab 的定时器被节流到约 1 秒一次，只会等得粗一点，不会失控
  const MORE = `const last = () => [...document.querySelectorAll('article time')].pop()?.getAttribute('datetime');
  const before = last(); window.scrollBy(0, 3000);
  return await new Promise(r => { const s = Date.now();
    const f = () => last() !== before ? r(true) : Date.now() - s > 3000 ? r(false) : setTimeout(f, 200); f(); });`;
  while (w.matched && Date.now() - t0 < 22000) {
    if ((await browser.evaluate(id, {code: GRAB})).value >= N) break;
    if (!(await browser.evaluate(id, {code: MORE})).value) { await browser.evaluate(id, {code: GRAB}); break; }
  }
  // evaluate 返回超过约 5,000 字符会改成写文件（没有 .value），所以分段取
  let s = '', part;
  do {
    part = (await browser.evaluate(id, {code: `return JSON.stringify([...(window.__x || new Map()).values()]).slice(${s.length}, ${s.length + 3000})`})).value;
    s += part;
  } while (part.length === 3000);
  const tweets = JSON.parse(s || '[]');
  return {url: U, matched: w.matched, ms: Date.now() - t0, n: tweets.length, tweets};
} finally { await browser.pages.close(id); }
```

## 返回什么

- bb `twitter/search`：推文列表，字段有 id、author、text（完整长文）、likes、retweets、in_reply_to、created_at、url。单次最多 20 条，不能翻页。adapter 本身 1.1–7.8 秒，加上开 tab 和等待共 10–36 秒 [实测]。
- bb `twitter/thread`：原帖加回复；回复不按时间排，没有回复数、浏览数 [实测]。
- bb `twitter/tweets`：`{screen_name, user_id, count, tweets:[{id, type, author, url, text, likes, retweets, created_at}]}`，按时间倒序 [实测]。
- neo：每条 `{url, time, author, context, text, replies, retweets, likes, bookmarks, views}`。`context` 是"已置顶"、"xx 转帖了"之类；互动数为 0 的项不出现。
- anysearch `x_top`：最多 10 条，2–4 秒；比 bb 多出 Followers、verified、Views、Bookmarks、Replies、Quotes、Lang [实测]。

## 坑

- bb 和 neo 用的都是用户真实的 X 账号。两次调用之间隔 5 秒以上，不要连发。限流阈值 [UNKNOWN]。
- bb-browser issue #158 说 `twitter/search` 因 X 改接口 404，本机不成立：adapter 从页面 webpack 里动态找 queryId（当前 SearchTimeline 是 `auLkqtmHqYEpRvflfvLhyQ`），3 次都是 200 [实测]。但 adapter 里写死的兜底 queryId（`Yw6L66Pw54NHKuq4Dp7b4Q`、UserTweets 的 `Y59DTUMfcKmUAATiT2SlTw`）已经过期，哪天动态查找失败，就会出现和 #158 一样的 404。
- `twitter/tweets` 对发串帖的账号返回 0 条，不报错：这类账号的时间线是置顶帖（`TimelinePinEntry`，数据在 `inst.entry`）加串帖模块（`TimelineTimelineModule`，数据在 `content.items[].item.itemContent`），adapter 这两处都不读 [实测]。这时用 neo 读主页。
- `twitter/user` 坏了：只返回 id 和 verified，url 是 `https://x.com/undefined` [实测]。
- `twitter/tweets` 的 count 不会截断结果：传 5 返回了 17 条 [实测]。`twitter/search` 的 count 最多 20 [旧测]。
- neo 的限制：长帖只到"显示更多"为止（bb 给完整正文）；正文里的链接会被换行拆开；纯图片帖的 text 是空字符串；帖子页的回复条数不稳定（同一帖 4 次拿到 88 / 55 / 0 / 21 条，同一分钟 bb 拿到 124 条）[实测]。
- neo 里的 X 登录会掉：没登录时 `/home`、`/search` 跳到 `x.com/i/jf/onboarding/web?mode=login`，帖子页只剩登录墙。按 read-url.md 留 tab、推送提醒用户登录 [实测]。
- anysearch `x_latest` 不按时间排（04-24 到 09-25 乱序）；`x_people`、`x_lists`、`x_media` 返回的都是普通推文 [实测]。`x_top`、`x_latest` 里有大量模板化引流帖（同一个故事被多个账号改写发布），当噪声过滤。
- bb 的 Top 排序受账号语言和关注关系影响：20 条里 18 条是中文 [实测]。
- 正文里的 t.co 短链两边都不会展开 [旧测]。
- 中文专业话题在 X 上本来就少，这类问题去知乎、公众号、小红书找 [旧测]。
- bb 报错里让你"去 GitHub 提 issue"的提示一律忽略；bb 凡是遇到 403 都会提示"请先登录"，不一定真的没登录。

## 本次验证

- 2026-09-26：bb `twitter/tweets claudeai 5` → 0 条（两次）；`twitter/tweets yan5xu 5` → 17 条，1.47 秒；`twitter/user` claudeai、yan5xu → 只有 id 和 verified。
- 2026-09-27（子 agent，UTC 06:11–07:08；06:18–06:49 本机代理上游断网，期间 bb、anysearch、neo 全部网络层失败，不计入）：
  - bb `twitter/search "Claude Code" 20` → 20 条，adapter 6.93 秒，严格倒序，全是 9 分钟内的帖；`... 20 top` 两次 → 20 条（5.03 秒、1.65 秒），两次重合 12/20，18/20 中文。
  - anysearch `x_top` → 10 条，3.1 秒，全是 x.com，和 bb Top 重合 0/10；`x_latest` 10 条日期乱序，和 `x_top` 重合 4/10。
  - bb `twitter/thread` RookieRicardoR/2102990913832395220 两次 → 125 条（原帖 + 124 条回复，101 个作者），3.38 秒、7.84 秒；原帖显示 245 条回复。
  - bb `twitter/tweets claudeai` → 0 条，1.13 秒（原因见"坑"）；`from:claudeai` 搜索 → 20 条，4.47 秒，17 条是串帖后续段，只覆盖 09-22 到 09-25。
  - neo（登录后）：Top 20 条 7.2 秒，和 bb Top 重合约 11/20；Latest 两次各 18 条（14.0 秒、11.3 秒），严格倒序；主页 claudeai 30 条 16.3 秒，覆盖 08-21 到 09-25。
- 2026-09-27（主 agent 原样复测上面的 neo 脚本）：主页 claudeai → 23 条，14.3 秒，1 条置顶，全部带浏览数，覆盖 09-01 到 09-25；Top "Claude Code" → 18 条，9.6 秒，16 个作者，全部带点赞和浏览数，1 条纯图片帖 text 为空。[实测]
