"""search-master 的路由测试：description 改动前后，让评判子 agent 判断每条用户消息会先调哪个 skill。

  python route_eval.py prompt [候选 description 文件] > prompt.txt   # 不给文件就读 SKILL.md 当前的 description
  python route_eval.py score <评判交回的表格文件>                    # 对照 cases.json 的 expect，列出不符的条目

skills.txt 是 2026-09-27 本机的竞争 skill 列表快照（search-master 那行是占位符）；
装了新的、和搜索沾边的 skill（读网页、调研、收藏之类）时要补进去。
"""
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
SKILL_MD = HERE.parent.parent / "SKILL.md"
PLACEHOLDER = "{{SEARCH_MASTER_DESCRIPTION}}"

PROMPT = """You are acting as a routing judge. Do NOT call any tools; answer from the text below only.

Setting: you are Claude Code (CLI) running on Windows, working directory is a TypeScript web-app git repository. The user's global CLAUDE.md contains, among other things:
- 代码检索：查相关代码、可复用实现和调用链时，语义检索用 semble MCP，精确匹配用 Grep。
- 知识获取（强制）：遇到不熟悉的知识必须联网搜索，严禁猜测。通用搜索：mcp__exa__web_search_exa、anysearch；库文档：context7 -> query-docs；开源项目：deepwiki。
- Use Context7 MCP to fetch current documentation whenever the user asks about a library, framework, SDK, API, CLI tool, or cloud service.

Tools available: Bash, Read, Grep, Glob, Edit, Write, WebSearch, WebFetch, Agent (sub-agents), Skill, and MCP tools (exa, anysearch, context7, deepwiki, semble, browseros-neo).

Skill tool rule: "A skill is a packaged set of instructions the user has set up for a particular kind of task. When the task at hand is one a listed skill covers, call this tool first — the skill's instructions load into the turn for you to follow in place of your default approach."

Available skills (name: description):
{skills}

For EACH user message below, imagine it is the first message of a fresh session. Decide what your first action would be: the exact skill name you would invoke via the Skill tool, or NONE if you would proceed without any skill (use tools directly or answer directly). Judge each message independently. Be honest about what you would actually do, not what seems ideal.

Messages:
{messages}

Output ONLY a markdown table with columns: id | choice | reason (under 15 words). One row per message, all {count} rows."""


def load_cases() -> list[dict]:
    return json.loads((HERE / "cases.json").read_text(encoding="utf-8"))


def current_description() -> str:
    text = SKILL_MD.read_text(encoding="utf-8")
    match = re.search(r"^description: (.*)$", text, re.M)
    if not match:
        sys.exit(f"no description line in {SKILL_MD}")
    return match.group(1).strip()


def build_prompt(description: str) -> str:
    if ": " in description:
        sys.exit("description contains ': ' — YAML frontmatter will fail to parse; rewrite it first")
    skills = (HERE / "skills.txt").read_text(encoding="utf-8").replace(PLACEHOLDER, description)
    cases = load_cases()
    messages = "\n".join(f"{c['id']}. {c['text']}" for c in cases)
    return PROMPT.format(skills=skills.rstrip(), messages=messages, count=len(cases))


def score(table_file: Path) -> None:
    expected = {c["id"]: c for c in load_cases()}
    got = {}
    for line in table_file.read_text(encoding="utf-8").splitlines():
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if len(cells) >= 2 and cells[0].isdigit():
            got[int(cells[0])] = cells[1].strip("`")
    wrong = []
    for case_id, case in expected.items():
        choice = got.get(case_id, "<missing>")
        if choice not in case["expect"].split("|"):
            wrong.append(f"  {case_id}. {case['text']}\n     expect {case['expect']}, got {choice}")
    print(f"{len(expected) - len(wrong)}/{len(expected)} match")
    print("\n".join(wrong))


def main() -> None:
    if len(sys.argv) >= 2 and sys.argv[1] == "prompt":
        desc = Path(sys.argv[2]).read_text(encoding="utf-8").strip() if len(sys.argv) > 2 else current_description()
        sys.stdout.reconfigure(encoding="utf-8")
        print(build_prompt(desc))
    elif len(sys.argv) == 3 and sys.argv[1] == "score":
        sys.stdout.reconfigure(encoding="utf-8")
        score(Path(sys.argv[2]))
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
