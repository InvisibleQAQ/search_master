"""用 Server酱 往用户手机推一条提醒（要用户动手时用：在 neo 里登录、过验证、启动 neo）。

用法：
    python notify.py "<标题>" ["<正文，支持 Markdown>"]

SendKey 从 %USERPROFILE%\\.codex\\serverchan-notifier.env 读，格式是一行
SERVERCHAN_SENDKEY=<key>（不带引号）。key 不进仓库，也不打印。

限制：标题最多 32 字、正文最多 32KB，超出的部分截掉；免费版每天只能推 5 条，
所以一批要处理的网址合成一条推送，不要一个网址推一次。
输出：stdout 一行 JSON {"ok", "code", "message"}；推送成功退出码 0，否则 1。
"""
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

ENV_FILE = os.path.join(os.path.expanduser("~"), ".codex", "serverchan-notifier.env")
TITLE_MAX = 32
DESP_MAX_BYTES = 32 * 1024
RETRIES = 2  # 只对网络错误重试；服务端已经回了结果就不重试（失败也算额度）


def read_sendkey():
    with open(ENV_FILE, encoding="utf-8") as f:
        for line in f:
            name, sep, value = line.partition("=")
            if sep and name.strip() == "SERVERCHAN_SENDKEY":
                return value.strip().strip("\"'")
    raise ValueError("SERVERCHAN_SENDKEY not found in " + ENV_FILE)


def send(title, desp):
    url = "https://sctapi.ftqq.com/%s.send?%s" % (
        read_sendkey(),
        urllib.parse.urlencode({"title": title, "desp": desp}),
    )
    for attempt in range(RETRIES + 1):
        try:
            with urllib.request.urlopen(url, timeout=15) as resp:
                return json.load(resp)
        except urllib.error.HTTPError as e:  # 服务端回了错误，body 里有 code 和 message
            return json.load(e)
        except (urllib.error.URLError, TimeoutError) as e:
            if attempt == RETRIES:
                return {"code": -1, "message": "network: %s" % getattr(e, "reason", e)}


def main():
    if len(sys.argv) < 2 or not sys.argv[1].strip():
        print('usage: python notify.py "<title>" ["<desp>"]', file=sys.stderr)
        return 2
    title = sys.argv[1].strip()[:TITLE_MAX]
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
