"""Проверяет имена свойств в Ui.new/Ui.label/Ui.button по определениям Roblox API.

Тип-чекер не видит эти свойства (они передаются таблицей Props = any), поэтому
опечатка в имени свойства иначе обнаружилась бы только при запуске в Studio.
Использование: python3 tools/check_ui_props.py <roblox.d.luau> <файлы...>
Файлы читаются в UTF-8 явно: на Windows кодировка по умолчанию — cp1251.
"""
import re, sys, pathlib

defs = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
members, parent = {}, {}
current = None
for line in defs.splitlines():
    m = re.match(r"declare extern type (\w+) extends (\w+) with", line)
    if m:
        current = m.group(1); parent[current] = m.group(2); members[current] = set(); continue
    if current:
        if line.strip() == "end":
            current = None; continue
        mm = re.match(r"\t(\w+)\s*:", line)
        if mm: members[current].add(mm.group(1))

def has(cls, prop):
    while cls:
        if prop in members.get(cls, ()): return True
        cls = parent.get(cls)
    return False

def props_at_depth1(src, start):
    depth, i, keys = 0, start, []
    while i < len(src):
        c = src[i]
        if c in "{(": depth += 1
        elif c in "})":
            depth -= 1
            if depth == 0: return keys
        elif c == '"':
            j = src.index('"', i + 1); i = j
        elif depth == 1:
            m = re.match(r"([A-Za-z_]\w*)\s*=(?!=)", src[i:])
            if m and (i == 0 or not (src[i-1].isalnum() or src[i-1] in "_.")):
                keys.append(m.group(1)); i += m.end() - 1
        i += 1
    return keys

problems = 0
for path in sys.argv[2:]:
    src = pathlib.Path(path).read_text(encoding="utf-8")
    for m in re.finditer(r'Ui\.new\("(\w+)",\s*\{|Ui\.(label|button)\(\{', src):
        cls = m.group(1) or {"label": "TextLabel", "button": "TextButton"}[m.group(2)]
        if cls not in members:
            print(f"{path}: неизвестный класс {cls}"); problems += 1; continue
        for key in props_at_depth1(src, m.end() - 1):
            if key == "Parent": continue
            if not has(cls, key):
                line = src[:m.start()].count("\n") + 1
                print(f"{path}:{line}: у {cls} нет свойства {key}"); problems += 1
print("проблем:", problems)
sys.exit(1 if problems else 0)
