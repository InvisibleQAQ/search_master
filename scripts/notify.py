"""用 Server酱 往用户手机推一条提醒（要用户动手时用：在 neo 里登录、过验证、启动 neo）。

用法：
    python notify.py "<标题>" ["<正文，支持 Markdown>"]

SendKey 从 %USERPROFILE%\\.codex\\serverchan-notifier.env 读，格式是一行
SERVERCHAN_SENDKEY=<key>（不带引号；UTF-8，带不带 BOM 都行）。key 不进仓库，也不打印。

限制：标题最多 32 字、正文最多 32KB，超出的部分截掉。用户是会员，每天 1000 条，
额度够用；但一批要处理的网址仍合成一条推送，不要一个网址推一次，免得刷屏。
输出：stdout 一行 JSON {"ok", "code", "message"}；推送成功退出码 0，否则 1。
"""
import http.client
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

ENV_FILE = os.path.join(os.path.expanduser("~"), ".codex", "serverchan-notifier.env")
TITLE_MAX = 32
DESP_MAX_BYTES = 32 * 1024
# 只对网络错误重试（连不上、超时、读响应时断开）；服务端已经回了结果就不重试。
# 读响应时断开，服务端可能已经推送了，重试最坏是重复一条，好过漏推。
RETRIES = 2


def read_sendkey():
    # utf-8-sig：Windows PowerShell 5.1 写的 UTF-8 文件带 BOM，用 utf-8 读第一行 key 名会对不上
    with open(ENV_FILE, encoding="utf-8-sig") as f:
        for line in f:
            name, sep, value = line.partition("=")
            if sep and name.strip() == "SERVERCHAN_SENDKEY":
                return value.strip().strip("\"'")
    raise ValueError("SERVERCHAN_SENDKEY not found in " + ENV_FILE)


def send(title, desp):
    # 用 POST 表单：放在 GET 的 URL 里，正文十几 KB 起服务端就崩（2026-09-26 实测）
    url = "https://sctapi.ftqq.com/%s.send" % read_sendkey()
    data = urllib.parse.urlencode({"title": title, "desp": desp}).encode()
    for attempt in range(RETRIES + 1):
        try:
            with urllib.request.urlopen(url, data=data, timeout=15) as resp:
                return json.load(resp)
        except urllib.error.HTTPError as e:  # 服务端回了错误，body 里有 code 和 message
            return json.load(e)
        # URLError、TimeoutError、ConnectionResetError 都是 OSError；IncompleteRead 是 HTTPException
        except (OSError, http.client.HTTPException) as e:
            if attempt == RETRIES:
                return {"code": -1, "message": "network: %s" % getattr(e, "reason", e)}


def main():
    if len(sys.argv) < 2 or not sys.argv[1].strip():
        print('usage: python notify.py "<title>" ["<desp>"]', file=sys.stderr)
        return 2
    title = " ".join(sys.argv[1].split())[:TITLE_MAX]  # 标题不能带换行
    desp = sys.argv[2] if len(sys.argv) > 2 else ""
    desp = desp.encode("utf-8")[:DESP_MAX_BYTES].decode("utf-8", "ignore")
    try:
        r = send(title, desp)
    except (OSError, ValueError) as e:  # env 文件不存在或没有 key
        r = {"code": -1, "message": str(e)}
    ok = r.get("code") == 0
    print(json.dumps({"ok": ok, "code": r.get("code"), "message": r.get("message")}))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
