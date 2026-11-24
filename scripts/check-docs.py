#!/usr/bin/env python3
import os
import re
import sys
import unicodedata

SKIP_DIRS = {"node_modules", ".git", "vendor", "dist", "build", ".next", "target", "__pycache__", ".venv", "venv", "coverage", "tmp", ".cache", ".dart_tool"}
FEATURE_DIR = os.path.join("docs", "feature")
FEATURE_TEMPLATE = os.path.join("docs", "templates", "feature.md")
LINK = re.compile(r"(?<!\!)\[[^\]]*\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")
HEADING = re.compile(r"^(#{1,6})\s+(.*?)\s*#*\s*$")
FENCE = re.compile(r"^\s*(```|~~~)")


def slug(text):
    text = re.sub(r"`([^`]*)`", r"\1", text)
    text = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", text)
    text = unicodedata.normalize("NFC", text).strip().lower()
    out = []
    for ch in text:
        cat = unicodedata.category(ch)
        if ch in (" ", "-"):
            out.append("-")
        elif ch == "_" or cat[0] in ("L", "N") or cat in ("Mn", "Mc"):
            out.append(ch)
    return "".join(out)


def anchors(path, cache):
    if path in cache:
        return cache[path]
    seen, result, in_fence = {}, set(), False
    with open(path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            if FENCE.match(line):
                in_fence = not in_fence
                continue
            if in_fence:
                continue
            m = HEADING.match(line)
            if not m:
                continue
            base = slug(m.group(2))
            n = seen.get(base, 0)
            seen[base] = n + 1
            result.add(base if n == 0 else f"{base}-{n}")
    cache[path] = result
    return result


def md_files(root):
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for f in filenames:
            if f.endswith(".md"):
                yield os.path.join(dirpath, f)


def links(path):
    in_fence = False
    with open(path, encoding="utf-8", errors="replace") as fh:
        for no, line in enumerate(fh, 1):
            if FENCE.match(line):
                in_fence = not in_fence
                continue
            if in_fence:
                continue
            for m in LINK.finditer(re.sub(r"`[^`]*`", "", line)):
                yield no, m.group(1)


def h2(path):
    in_fence, out = False, []
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            if FENCE.match(line):
                in_fence = not in_fence
            elif not in_fence and line.startswith("## "):
                out.append(line[3:].strip())
    return out


def feature_sections(root):
    template = os.path.join(root, FEATURE_TEMPLATE)
    folder = os.path.join(root, FEATURE_DIR)
    if not os.path.exists(template) or not os.path.isdir(folder):
        return []
    want = h2(template)
    errors = []
    for f in sorted(os.listdir(folder)):
        if f.endswith(".md"):
            got = h2(os.path.join(folder, f))
            if got != want:
                errors.append(f"{FEATURE_DIR}/{f}: mục ## phải đúng thứ tự {want}, đang có {got}")
    return errors


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else "."
    cache, count, files = {}, 0, 0
    broken = feature_sections(root)
    for f in sorted(md_files(root)):
        files += 1
        for no, target in links(f):
            if re.match(r"^[a-z][a-z0-9+.-]*:", target, re.I):
                continue
            count += 1
            path_part, _, frag = target.partition("#")
            dest = f if not path_part else os.path.normpath(os.path.join(os.path.dirname(f), path_part))
            if not os.path.exists(dest):
                broken.append(f"{f}:{no}: thiếu file → {target}")
                continue
            if frag and dest.endswith(".md") and frag.lower() not in anchors(dest, cache):
                broken.append(f"{f}:{no}: thiếu anchor #{frag} trong {os.path.relpath(dest, root)}")
    for b in broken:
        print(b)
    print(f"{files} file .md, {count} link nội bộ, {len(broken)} lỗi")
    sys.exit(1 if broken else 0)


if __name__ == "__main__":
    main()
