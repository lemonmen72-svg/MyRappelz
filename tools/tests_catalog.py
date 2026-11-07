#!/usr/bin/env python3
"""Каталог автотестов (tests/catalog.gd, фаза 6 Кардинала): сверка с папкой tests/, docs/TESTS.md и
tests/tests_index.txt.

  python3 -I tools/tests_catalog.py            — сверить и записать docs/TESTS.md, tests/tests_index.txt
  python3 -I tools/tests_catalog.py --check    — только сверить (выход 1, если файлы устарели или каталог неполон)
  python3 -I tools/tests_catalog.py --sync     — ещё перенести секунды из .github/scripts/smoke_weights.txt в каталог

Каталог — GDScript-литерал (строки, списки, числа): читается как Python (ast.literal_eval). Режимы тест-бота —
bot/bot_scenario.gd MODE_GROUPS / MODES (true/false → True/False).
"""
import ast
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CATALOG = os.path.join(ROOT, "tests", "catalog.gd")
SCENARIO = os.path.join(ROOT, "bot", "bot_scenario.gd")
WEIGHTS = os.path.join(ROOT, ".github", "scripts", "smoke_weights.txt")
DOC = os.path.join(ROOT, "docs", "TESTS.md")
INDEX = os.path.join(ROOT, "tests", "tests_index.txt")
INDEX_HEAD = ("# Список автотестов для режима бота «Автотесты на телефоне» (если папку не перечислить). "
              "Пишет tools/tests_catalog.py по tests/catalog.gd; сверка — tests/test_bot.gd, tests/test_catalog.gd.")
FLAGS = ("quick", "pack")


def _block(text, name, opener, closer):
    """Литерал const name := <opener> … <closer> (по балансу скобок вне строк)."""
    m = re.search(r"^const %s\s*:=\s*\%s" % (re.escape(name), opener), text, re.M)
    if not m:
        raise SystemExit("нет const %s в каталоге" % name)
    i = m.end() - 1
    depth = 0
    in_str = False
    j = i
    while j < len(text):
        ch = text[j]
        if in_str:
            if ch == "\\":
                j += 2
                continue
            if ch == '"':
                in_str = False
        elif ch == '"':
            in_str = True
        elif ch == "#":
            j = text.index("\n", j)
            continue
        elif ch in "[{":
            depth += 1
        elif ch in "]}":
            depth -= 1
            if depth == 0:
                return text[i:j + 1]
        j += 1
    raise SystemExit("не закрыт const %s" % name)


def load_catalog():
    text = open(CATALOG, encoding="utf-8").read()
    groups = ast.literal_eval(_block(text, "GROUPS", "[", "]"))
    tests = ast.literal_eval(_block(text, "TESTS", "{", "}"))
    not_tests = ast.literal_eval(_block(text, "NOT_TESTS", "[", "]"))
    return text, groups, tests, not_tests


def load_modes():
    text = open(SCENARIO, encoding="utf-8").read()
    def lit(name, o, c):
        s = _block(text, name, o, c)
        s = re.sub(r"\btrue\b", "True", s)
        s = re.sub(r"\bfalse\b", "False", s)
        return ast.literal_eval(s)
    return lit("MODE_GROUPS", "[", "]"), lit("MODES", "[", "]")


def test_files(not_tests):
    out = []
    for f in os.listdir(os.path.join(ROOT, "tests")):
        if not f.endswith(".gd"):
            continue
        base = f[:-3]
        if base in not_tests:
            continue
        if base == "smoke_test" or base.startswith("test_"):
            out.append(base)
    return out


def index_order(names):
    """Порядок, как у BotScenarioAutotests.scan_tests: по алфавиту, smoke_test первым."""
    out = sorted(names)
    if "smoke_test" in out:
        out.remove("smoke_test")
        out.insert(0, "smoke_test")
    return out


def check(groups, tests, files):
    errors = []
    gids = [g[0] for g in groups]
    for n in sorted(set(files) - set(tests)):
        errors.append("тест %s есть в tests/, но не описан в tests/catalog.gd" % n)
    for n in sorted(set(tests) - set(files)):
        errors.append("в каталоге %s, а файла tests/%s.gd нет" % (n, n))
    for n, e in tests.items():
        if not (isinstance(e, list) and len(e) == 5):
            errors.append("%s: строка — [группа, название, что проверяет, флаги, секунды]" % n)
            continue
        g, title, what, flags, secs = e
        if g not in gids:
            errors.append("%s: группы %s нет в GROUPS" % (n, g))
        if not title or not what:
            errors.append("%s: пустое название или описание" % n)
        for f in flags:
            if f not in FLAGS and not (f.startswith("ci:") and len(f) > 3):
                errors.append("%s: неизвестный флаг %s" % (n, f))
        if not isinstance(secs, (int, float)) or secs <= 0:
            errors.append("%s: секунды — число > 0" % n)
    for g in gids:
        if not any(e[0] == g for e in tests.values() if isinstance(e, list) and e):
            errors.append("в группе %s нет тестов" % g)
    return errors


def where(flags):
    ci = [f[3:] for f in flags if f.startswith("ci:")]
    if ci:
        return "только CI: " + ci[0]
    s = "CI и телефон"
    if "quick" in flags:
        s += " (в «быстрых»)"
    if "pack" in flags:
        s += "; на телефоне — с пакетом ресурсов"
    return s


def clock(sec):
    sec = int(round(sec))
    return "%d:%02d" % (sec // 60, sec % 60) if sec >= 60 else "%d с" % sec


def doc_text(groups, tests, mode_groups, modes):
    L = []
    L.append("# Проверки Dark Pact — что какой тест проверяет")
    L.append("")
    L.append("Файл пишет `tools/tests_catalog.py` по каталогу `tests/catalog.gd` — править описания там, затем "
             "`python3 -I tools/tests_catalog.py`.")
    L.append("")
    L.append("Проверки бывают двух видов:")
    L.append("")
    L.append("- **Автотесты** (`tests/*.gd`) — проверки кода без экрана. Идут в CI на каждый пуш (workflow «Проверка "
             "кода») и на телефоне в режимах тест-бота «Автотесты».")
    L.append("- **Режимы тест-бота** — на телефоне, админ-панель → «Тест-бот»: бот сам играет тестовым героем, меряет "
             "и пишет отчёт. История отчётов, сравнение запусков и экспорт — вкладка «Отчёты», что посмотреть по "
             "итогам — «Предложения» (только просмотр).")
    L.append("")
    L.append("## Режимы тест-бота")
    L.append("")
    for g in mode_groups:
        L.append("### %s" % g[1])
        L.append("")
        L.append(g[2])
        L.append("")
        L.append("| Режим | Что проверяет | Когда запускать | Время |")
        L.append("|---|---|---|---|")
        for m in modes:
            if m.get("group") != g[0]:
                continue
            L.append("| %s | %s | %s | до %d мин |" % (m["name"], m.get("about", ""), m.get("when", ""),
                                                      int(m.get("minutes", 0))))
        L.append("")
    n_ci = sum(1 for e in tests.values() if any(f.startswith("ci:") for f in e[3]))
    n_quick = sum(1 for e in tests.values() if "quick" in e[3])
    L.append("## Автотесты по группам")
    L.append("")
    L.append("Всего %d: в «быстрых» на телефоне %d, только в CI %d. Время — в CI, на телефоне примерно столько же."
             % (len(tests), n_quick, n_ci))
    L.append("")
    for gid, gname, gabout in groups:
        names = [n for n, e in tests.items() if e[0] == gid]
        total = sum(tests[n][4] for n in names)
        L.append("### %s — %d, ≈ %s" % (gname, len(names), clock(total)))
        L.append("")
        L.append(gabout[0].upper() + gabout[1:] + ".")
        L.append("")
        L.append("| Тест | Что проверяет | Где идёт | ≈ время |")
        L.append("|---|---|---|---|")
        for n in names:
            g, title, what, flags, secs = tests[n]
            L.append("| **%s** `%s` | %s | %s | %s |" % (title, n, what, where(flags), clock(secs)))
        L.append("")
    return "\n".join(L)


def index_text(tests):
    return INDEX_HEAD + "\n" + "\n".join(index_order(list(tests))) + "\n"


def sync_secs(text, tests):
    weights = {}
    for line in open(WEIGHTS, encoding="utf-8"):
        p = line.split()
        if len(p) == 2 and not line.startswith("#"):
            weights[p[0]] = int(p[1])
    out = []
    changed = 0
    for line in text.split("\n"):
        m = re.match(r'^(\t"(\w+)": \[.*, )(\d+(?:\.\d+)?)(\],?)$', line)
        if m and m.group(2) in weights and float(m.group(3)) != weights[m.group(2)]:
            line = m.group(1) + str(weights[m.group(2)]) + m.group(4)
            changed += 1
        out.append(line)
    return "\n".join(out), changed


def main():
    args = sys.argv[1:]
    text, groups, tests, not_tests = load_catalog()
    if "--sync" in args:
        text2, changed = sync_secs(text, tests)
        if changed:
            open(CATALOG, "w", encoding="utf-8").write(text2)
            text, groups, tests, not_tests = load_catalog()
        print("секунды из smoke_weights.txt: обновлено %d" % changed)
    files = test_files(not_tests)
    errors = check(groups, tests, files)
    for e in errors:
        print("ОШИБКА: " + e)
    mode_groups, modes = load_modes()
    for m in modes:
        if not m.get("group") or not m.get("about") or not m.get("when"):
            errors.append("режим %s: нет group / about / when" % m.get("id"))
            print("ОШИБКА: " + errors[-1])
    want = {DOC: doc_text(groups, tests, mode_groups, modes) + "\n", INDEX: index_text(tests)}
    stale = []
    for path, body in want.items():
        old = open(path, encoding="utf-8").read() if os.path.exists(path) else ""
        if old != body:
            stale.append(os.path.relpath(path, ROOT))
            if "--check" not in args and not errors:
                open(path, "w", encoding="utf-8").write(body)
    if "--check" in args:
        for s in stale:
            print("УСТАРЕЛ: %s — запустите python3 -I tools/tests_catalog.py" % s)
        sys.exit(1 if errors or stale else 0)
    if errors:
        sys.exit(1)
    print("каталог: тестов %d, групп %d; записано: %s" % (len(tests), len(groups), ", ".join(stale) if stale else "без изменений"))


if __name__ == "__main__":
    main()
