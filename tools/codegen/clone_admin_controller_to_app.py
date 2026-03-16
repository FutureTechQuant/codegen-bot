#!/usr/bin/env python3
import argparse
import os
import re
from pathlib import Path

TAG_FROM = '管理后台 - '
TAG_TO = '用户 App - '

DEFAULT_KEEP_HTTP = {"GET"}

def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--generated-dir", required=True)
    return p.parse_args()

def getenv_set(name, default=None):
    raw = os.getenv(name, "")
    if not raw.strip():
        return set(default or [])
    return {x.strip() for x in raw.split(",") if x.strip()}

KEEP_HTTP_METHODS = getenv_set("APP_KEEP_HTTP_METHODS", DEFAULT_KEEP_HTTP)
KEEP_METHOD_NAMES = getenv_set("APP_KEEP_METHOD_NAMES", set())

ANN_HTTP = {
    "@GetMapping(": "GET",
    "@PostMapping(": "POST",
    "@PutMapping(": "PUT",
    "@DeleteMapping(": "DELETE",
    "@PatchMapping(": "PATCH",
}

def transform_header(text: str) -> str:
    text = text.replace(".controller.admin.", ".controller.app.")
    text = re.sub(r'public\s+class\s+([A-Z]\w*)Controller\b',
                  r'public class App\1Controller', text, count=1)
    text = text.replace(TAG_FROM, TAG_TO)
    text = re.sub(r'^\s*import\s+org\.springframework\.security\.access\.prepost\.PreAuthorize;\s*$',
                  '', text, flags=re.M)
    return text

def split_header_and_body(text: str):
    m = re.search(r'\bpublic\s+class\s+\w+\s*\{', text)
    if not m:
        return text, ""
    brace_pos = text.find("{", m.start())
    return text[:brace_pos + 1], text[brace_pos + 1:]

def extract_top_level_blocks(body: str):
    blocks = []
    buf = []
    level = 0
    i = 0
    while i < len(body):
        ch = body[i]
        buf.append(ch)
        if ch == "{":
            level += 1
        elif ch == "}":
            level -= 1
            if level < 0:
                blocks.append("".join(buf[:-1]))
                return blocks, "}"
        elif ch == "\n" and level == 0:
            s = "".join(buf)
            if s.strip():
                blocks.append(s)
            buf = []
        i += 1
    if buf and "".join(buf).strip():
        blocks.append("".join(buf))
    return blocks, ""

def looks_like_method(block: str) -> bool:
    return "public " in block and "(" in block and ")" in block and "{" in block

def detect_http(block: str):
    for k, v in ANN_HTTP.items():
        if k in block:
            return v
    return None

def detect_method_name(block: str):
    m = re.search(r'public\s+[<>\w\[\], ?]+\s+(\w+)\s*\(', block)
    return m.group(1) if m else None

def should_keep_method(block: str) -> bool:
    name = detect_method_name(block)
    if name in KEEP_METHOD_NAMES:
        return True
    if "@PreAuthorize(" in block:
        return False
    http = detect_http(block)
    if http and http not in KEEP_HTTP_METHODS:
        return False
    return http in KEEP_HTTP_METHODS

def cleanup(text: str) -> str:
    text = re.sub(r'\n{3,}', '\n\n', text)
    text = re.sub(r'[ \t]+\n', '\n', text)
    return text.strip() + "\n"

def convert_one_file(src: Path, dst: Path):
    text = src.read_text(encoding="utf-8")
    text = transform_header(text)

    header, body = split_header_and_body(text)
    blocks, tail = extract_top_level_blocks(body)

    kept = []
    for block in blocks:
        if looks_like_method(block):
            if should_keep_method(block):
                block = re.sub(r'^\s*@PreAuthorize\(.*?\)\s*$\n?', '', block, flags=re.M)
                kept.append(block)
        else:
            kept.append(block)

    result = header + "".join(kept) + "\n" + tail
    result = cleanup(result)

    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_text(result, encoding="utf-8")

def main():
    args = parse_args()
    root = Path(args.generated_dir)
    java_files = list(root.rglob("*.java"))

    count = 0
    for src in java_files:
        path_str = str(src).replace("\\", "/")
        if "/controller/admin/" not in path_str:
            continue

        rel = src.relative_to(root)
        dst_rel = Path(str(rel).replace("/controller/admin/", "/controller/app/"))
        dst = root / dst_rel

        convert_one_file(src, dst)
        count += 1

    print(f"generated app controllers: {count}")

if __name__ == "__main__":
    main()
