# 结构化数据垂直：行情、CVE、临床试验、药品、专利、空气质量、法律

> 最后验证：2026-09-26。标记：[实测] 本次跑过；[旧测] 引自 2026-09-24 调研；[UNKNOWN] 没查清。
> anysearch 垂直必须先 `get_sub_domains(domains=[...])`（一次最多 5 个），参数只能用它给的。下面的 JSON 是它在 09-24 / 09-26 给出的参数，照抄前仍要先调一次确认。其余 sub_domain 的参数也用它查。
> `batch_search` 一次最多 5 条，传输层失败时整批都丢；5 条垂直结果本次合计 6 万字，被存成了文件。控制 `max_results`。

| 需求 | 首选 | 备选 | 别用 |
|---|---|---|---|
| A 股实时快照 | bb `xueqiu/stock SH600519` [实测 0.3 秒] | anysearch `finance.quote` + `cn_code`（逐日收盘）[实测] | bb `eastmoney/stock`（Failed to fetch）[实测] |
| A 股日线 / 估值（PE、PB、股息率） | anysearch `finance.quote` + `cn_code` + `period` [实测] | bb `xueqiu/stock`（只有当天） | — |
| 美股报价 | anysearch `finance.quote` + `symbol` [实测 1.3 秒] | bb `yahoo-finance/quote`（25 秒）[实测] | — |
| 港股 | bb `xueqiu/stock 00700` [UNKNOWN] | anysearch `finance.quote` [UNKNOWN] | — |
| 外汇 / 加密 / 商品 / 指数 / ETF | anysearch `finance.quote` `type=forex/crypto/commodity/index/etf` [UNKNOWN] | — | — |
| 个股英文新闻 | anysearch `finance.news` `type=stock` [旧测 好] | — | `finance.news` `type=flash`（退回通用搜索）[旧测] |
| 财报 / 基本面 / 宏观 | anysearch `finance.fundamental` / `finance.macro` [UNKNOWN] | — | — |
| CVE | anysearch `security.vuln` [实测] | — | `security.scan`（把 IOC 提交第三方，禁用） |
| 临床试验 | anysearch `health.trial` [实测] | — | — |
| 药品说明书 / 不良反应 / 召回 | anysearch `health.drug` `type=name`，query 写英文通用名加剂型 [实测] | — | 用中文药名查（返回无关药品，不报错）[实测] |
| 专利 | anysearch `ip.global` [实测] | — | 依赖 `applicant` 过滤（不生效）[旧测] |
| 空气质量 | anysearch `environment.aqi` [实测] | — | — |
| 中国法律条文 | anysearch 通用搜索（能搜到 cac.gov.cn 等官方原文） | `legal.statute` + `jurisdiction:CN`（实际就是通用搜索）[实测] | 把 `legal.statute` 当按条款的结构化检索 |
| 美 / 欧 / 英法规、判例、国会法案 | anysearch `legal.statute` / `legal.case` / `legal.legislation` [UNKNOWN] | — | — |

## 股票行情
### 命令
anysearch（先 `get_sub_domains(domains=["finance"])`）：
```json
{"query": "Apple stock quote", "domain": "finance", "sub_domain": "finance.quote",
 "sub_domain_params": {"type": "stock", "symbol": "AAPL", "cn_code": "", "period": "7d"}}
{"query": "贵州茅台 行情", "domain": "finance", "sub_domain": "finance.quote",
 "sub_domain_params": {"type": "stock", "symbol": "", "cn_code": "600519.SH", "period": "7d"}}
```
`symbol` 和 `cn_code` 都标必填但二选一，不用的传 `""`。`cn_code` 形如 `600519.SH`、`000001.SZ`、`510300.SH`；`period`：`7d / 14d / 30d / 90d / 180d / 1y / 5y / {N}d`。

bb-browser（Git Bash）：
```bash
bash C:/Users/18368/Desktop/00_myCode/43_search_master/scripts/bb.sh xueqiu/stock SH600519   # 也接受 SZ000858、AAPL、00700
bash C:/Users/18368/Desktop/00_myCode/43_search_master/scripts/bb.sh yahoo-finance/quote AAPL
```
### 返回什么
- anysearch 美股：一行 `Symbol | Name | Exchange | Price | Open | PrevClose | Change | Change% | DayHigh | DayLow | YearHigh | YearLow | Volume | MarketCap | Avg50 | Avg200`，来源 financialmodelingprep。
- anysearch A 股：每个交易日一条 `600519.SH <日期> 日线行情`，JSON 字段 `trade_date, open, high, low, close, pre_close, change, pct_chg, vol, amount, turnover_rate, pe, pe_ttm, pb, ps, ps_ttm, dv_ratio, dv_ttm, total_mv, circ_mv`。和雪球对过数：`vol` 单位是手，`amount` 是千元，`total_mv` / `circ_mv` 是万元。
- bb `xueqiu/stock`：`name, symbol, exchange, currency, price, change, changePercent, open, high, low, prevClose, amplitude, volume（股）, amount, turnover_rate, marketCap, floatMarketCap, ytdPercent, market_status（如"休市"）, time（UTC）, url`。不用登录。
- bb `yahoo-finance/quote`：`symbol, name, price, change（字符串）, changePercent, open, high, low, prevClose, volume, currency, exchange, source, url`。
### 坑
- anysearch 美股没有报价时间戳；还会附带 AAPL.L / .MX / .TO / .NE / .DE 以及名字里含 AAPL 的无关印度股票，只取 `Symbol` 完全匹配的那条。`period` 对美股不返回历史序列 [旧测]。
- anysearch A 股给的是日线收盘，不是盘中实时价；要当前价和交易状态用雪球。
- bb `eastmoney/stock` 两次都是 `TypeError: Failed to fetch`。adapter 在 `quote.eastmoney.com` 页里请求 `searchapi.eastmoney.com` 和 `push2.eastmoney.com`，失败原因 [UNKNOWN]。`eastmoney/news` 没测。
- bb `yahoo-finance/quote` 走境外网络，本次 25 秒；雪球其他命令（`search`、`hot`、`hot-stock`；`feed`、`watchlist` 要登录）没测 [UNKNOWN]。
- 三个来源的 AAPL（341.07）和茅台（1237 / -14.24）数字互相一致。

## CVE
### 命令
```json
{"query": "CVE-2024-3094", "domain": "security", "sub_domain": "security.vuln",
 "sub_domain_params": {"type": "cve", "value": "CVE-2024-3094"}}
```
`type`（必填）：`cve` / `commit` / `package`；`value`（必填）：CVE 编号 / 40 位 commit hash / `ecosystem:name@version`，逗号分隔可批量 [旧测]。
### 返回什么
1 条 osv.dev 记录：发布日期、描述、GHSA 等别名、CVSS 向量、受影响版本、分类好的参考链接。
### 坑
- `commit`、`package` 两种查法没测 [UNKNOWN]。
- 绝不调 `security.scan`（会把 IOC 提交给第三方）。

## 临床试验
### 命令
```json
{"query": "tirzepatide obesity phase 3", "domain": "health", "sub_domain": "health.trial", "max_results": 5}
```
### 返回什么
clinicaltrials.gov 记录：`NCT ID, Official Title, Status, Phase, Sponsor, Sex, Minimum/Maximum Age, Conditions`，以及研究中心和完整入排标准。
### 坑
- 没有任何参数，分期、状态、地区都没法过滤：query 写了 phase 3，第 1 条却是另一种药的 Phase 2 试验。拿到后按 `Phase`、`Status` 字段自己筛。
- 单条很长（全部研究中心 + 入排标准），`max_results` 设小。

## 药品
### 命令
```json
{"query": "metformin hydrochloride tablets", "domain": "health", "sub_domain": "health.drug",
 "sub_domain_params": {"type": "name"}, "max_results": 3}
```
`type`（必填）：`name`（药名）/ `ndc`（NDC 编码）/ `upc`（条码）。
### 返回什么
美国 FDA 体系的数据，同一次结果里混着几种记录 [实测]：
- DailyMed 说明书：适应症、用法用量、不良反应、相互作用、禁忌、黑框警告，单条可达 1.5 万字。
- NDC 记录：品牌名、通用名、厂家、剂型、规格、包装、药理分类。
- RxNav 条目：只有 RxCUI 和名字。
- FDA 不良事件汇总（FAERS）：报告总数和前 20 种不良反应及例数。
约 1 秒。
### 坑
- 中文药名不认：查"二甲双胍"返回的是 Uritact、Lastacaft 两种无关的药，不报错 [实测]。一律用英文通用名。
- 只写成分名会先返回复方药：查 "metformin"，第 1 条是西格列汀二甲双胍复方片（ZITUVIMET）的整份说明书 [实测]。要单方药就写全通用名加剂型，比如 "metformin hydrochloride tablets"，并核对结果标题。
- 说明书单条很长，`max_results` 设 2-3。
- 数据是美国的（DailyMed、NDC、FAERS），中国上市药品的覆盖 [UNKNOWN]。

## 专利
### 命令
```json
{"query": "solid-state battery sulfide electrolyte", "domain": "ip", "sub_domain": "ip.global",
 "sub_domain_params": {"type": "GlobalPatent", "keyword": "solid-state battery sulfide electrolyte", "date_start": "2024"},
 "max_results": 2}
```
其他参数：`applicant`（申请人）、`ipc`（如 `H01L`、`G06N`）；`date_start` 写 `2024` 或 `20240101`。
### 返回什么
题录（标题、申请人、发明人、公开号、公开日、申请号、申请日、CPC）、摘要、法律状态（`legal_status` + `legal_date`）、同族专利（各国公开号、类型、日期、`total`）、权利要求、说明书全文。
### 坑
- 单条几千字（同族 + 权利要求 + 说明书），`max_results` 2-3。
- 同一批结果有两种格式：第 1 条是完整题录但没有 URL，第 2 条来自 espacenet、字段名不同。
- `applicant` 过滤不生效 [旧测]；`date_start` 是按公开日还是申请日过滤 [UNKNOWN]（本次第 1 条申请日 2023、公开日 2025）。

## 空气质量
### 命令
```json
{"query": "Beijing air quality", "domain": "environment", "sub_domain": "environment.aqi",
 "sub_domain_params": {"type": "GlobalAirQuality", "location": "Beijing"}}
```
`location`：邮编 / 经纬度（`38.9,-77.0`）/ 城市名，中文城市名（"上海"）也能用 [实测]。
### 返回什么
aqicn.org：每条一个站点，第 1 条是城市总体，后面是附近监测站。字段有 AQI、等级（中文）、健康建议、坐标、更新时间。约 0.6–1 秒 [实测]。
### 坑
- 更新时间是站点当地时间，不是 UTC：北京、上海显示 `2026-09-26 21:00:00`，调用时是 UTC 13 点左右，也就是北京时间 21 点，说明数据是实时的 [实测]。
- 只有 AQI 总值，没有 PM2.5、PM10 分项（描述里提到了分项，本次结果里没有）[实测]。

## 法律
### 命令
```json
{"query": "中华人民共和国个人信息保护法 第二十四条 自动化决策", "domain": "legal", "sub_domain": "legal.statute",
 "sub_domain_params": {"jurisdiction": "CN"}}
```
### 返回什么
中国法律：普通网页结果，第 1 条是 cac.gov.cn 官方全文（摘要就是命中的条款原文），其余是 npcobserver PDF、律所解读、维基、Scribd。
### 坑
- `legal.statute` 查中国法律就是通用搜索，不按条款结构化；直接用通用搜索效果一样，拿到官方原文链接再读全文。
- 国家法律法规数据库 flk.npc.gov.cn 用 neo 查是否更好 [UNKNOWN]。
- 结构化参数只对境外源有意义：`collection`（FR / CFR / USCODE / BILLS / PLAW …）、`doc_type`（EUR-Lex、UK legislation、Federal Register 各有取值）、`agency`、`date_from` / `date_to`；`legal.case` 走 CanLII / ECHR / CourtListener；`legal.legislation` 只管美国国会。全部没测 [UNKNOWN]。

## 本次验证
- anysearch `get_sub_domains` 开头连续 3 次 `fetch failed`；finance / security / health.trial / legal 于是按 09-24 记录的参数直接跑；后来一次成功，确认 health / ip / environment 参数没变。
- `finance.quote` AAPL → 8 条，1.3 秒，第 1 条正确，价格 341.07。
- `finance.quote` 600519.SH period=7d → 4 条日线，4.9 秒，最新 09-24 收盘 1237。
- `security.vuln` CVE-2024-3094 → 1 条 osv.dev，0.3 秒，好。
- `health.trial` "tirzepatide obesity phase 3" → 10 条，0.4 秒，数据全但不按分期过滤。
- `legal.statute` CN 个人信息保护法 → 10 条，2.2 秒，通用网页，确认退回。
- `ip.global` 固态电池硫化物电解质 date_start=2024 → 2 条，3.0 秒，同族 9 件、法律状态齐全。这个 batch 前 2 次 `fetch failed`，第 3 次成功。
- `health.drug`、`environment.aqi` → 上午所在 batch 两次 `fetch failed`，没拿到结果。下午网络恢复后重跑：
  - `get_sub_domains(code, health, environment)` → 一次成功，参数没变。
  - `health.drug` "metformin" → 2 条，1.0 秒：第 1 条是复方药 ZITUVIMET 的整份说明书，第 2 条是 RxNav 条目。
  - `health.drug` "二甲双胍" → 2 条，0.5 秒，Uritact、Lastacaft，全部无关。
  - `health.drug` "metformin hydrochloride tablets" → 3 条，1.1 秒：NDC 记录、RxNav、FAERS 汇总（57,013 份报告），全部对。
  - `environment.aqi` Beijing → 3 条，1.1 秒，AQI 40；"上海" → 2 条，0.6 秒，AQI 57。
- bb `xueqiu/stock SH600519` → 成功，0.33 秒（含开 tab 共 5 秒）。
- bb `eastmoney/stock 600519` → 两次 `Failed to fetch`，失败。
- bb `yahoo-finance/quote AAPL` → 成功，24.9 秒。
