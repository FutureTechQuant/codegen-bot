#!/usr/bin/env python3
import argparse
import re
from pathlib import Path

TAG_FROM = '管理后台 - '
TAG_TO = '用户 App - '

KEEP_ENDPOINTS = {"/create", "/update", "/delete", "/get", "/page"}


def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--generated-dir", required=True)
    return p.parse_args()


def transform_header(text: str) -> str:
    # 1) 只修改 package 行，不要全局替换，否则会误伤 import 的 admin.vo
    text = re.sub(
        r'^(package\s+.+?\.controller)\.admin(\..*;\s*)$',
        r'\1.app\2',
        text,
        count=1,
        flags=re.M
    )

    # 2) 类名改成 AppXXXController
    text = re.sub(
        r'public\s+class\s+([A-Z]\w*)Controller\b',
        r'public class App\1Controller',
        text,
        count=1
    )

    # 3) Tag 文案改掉
    text = text.replace(TAG_FROM, TAG_TO)

    # 4) 删除 PreAuthorize 的 import
    text = re.sub(
        r'^\s*import\s+org\.springframework\.security\.access\.prepost\.PreAuthorize;\s*$\n?',
        '',
        text,
        flags=re.M
    )

    # 5) 如果之前有误替换，兜底把 import 中的 controller.app.xxx.vo 改回 controller.admin.xxx.vo
    text = re.sub(
        r'(^\s*import\s+.+?\.controller)\.app(\..*\.vo\..*;\s*$)',
        r'\1.admin\2',
        text,
        flags=re.M
    )

    return text


def split_header_and_body(text: str):
    m = re.search(r'\bpublic\s+class\s+\w+\s*\{', text)
    if not m:
        return text, ""
    brace_pos = text.find("{", m.start())
    return text[:brace_pos + 1], text[brace_pos + 1:]


def extract_top_level_members(body: str):
    members = []
    buf = []
    level = 0
    i = 0
    n = len(body)

    while i < n:
        ch = body[i]

        # 到达 class 的结束大括号
        if level == 0 and ch == "}":
            if "".join(buf).strip():
                members.append("".join(buf))
            return members, body[i:]

        buf.append(ch)

        if ch == "{":
            level += 1
        elif ch == "}":
            level -= 1

        # 字段、注入成员等，以分号结束
        if ch == ";" and level == 0:
            i += 1
            while i < n and body[i] in " \t\r\n":
                buf.append(body[i])
                i += 1
            members.append("".join(buf))
            buf = []
            continue

        # 方法结束
        if ch == "}" and level == 0:
            i += 1
            while i < n and body[i] in " \t\r\n":
                buf.append(body[i])
                i += 1
            members.append("".join(buf))
            buf = []
            continue

        i += 1

    if "".join(buf).strip():
        members.append("".join(buf))
    return members, ""


def looks_like_method(block: str) -> bool:
    return re.search(
        r'\b(public|protected|private)\b[\s\S]*?\([^;\n{}]*\)\s*\{',
        block
    ) is not None


def detect_mapping_path(block: str):
    patterns = [
        r'@(Get|Post|Put|Delete|Patch)Mapping\s*\(\s*(?:value\s*=\s*)?"([^"]+)"',
        r'@(Get|Post|Put|Delete|Patch)Mapping\s*\(\s*(?:path\s*=\s*)?"([^"]+)"',
        r'@RequestMapping\s*\(\s*(?:value\s*=\s*)?"([^"]+)"',
        r'@RequestMapping\s*\(\s*(?:path\s*=\s*)?"([^"]+)"',
    ]
    for pattern in patterns:
        m = re.search(pattern, block)
        if m:
            return m.group(m.lastindex)
    return None


def should_keep_method(block: str) -> bool:
    path = detect_mapping_path(block)
    return path in KEEP_ENDPOINTS


def strip_security_annotations(block: str) -> str:
    return re.sub(
        r'^\s*@PreAuthorize\(.*?\)\s*$\n?',
        '',
        block,
        flags=re.M
    )


def cleanup(text: str) -> str:
    text = re.sub(r'\n{3,}', '\n\n', text)
    text = re.sub(r'[ \t]+\n', '\n', text)
    return text.strip() + "\n"


def build_dst_rel(rel: Path) -> Path:
    s = str(rel).replace("\\", "/")
    s = s.replace("/controller/admin/", "/controller/app/")
    dst = Path(s)

    # 文件名改成 AppXXXController.java
    if dst.name.endswith("Controller.java") and not dst.name.startswith("App"):
        dst = dst.with_name("App" + dst.name)

    return dst


def convert_one_file(src: Path, dst: Path):
    text = src.read_text(encoding="utf-8")
    text = transform_header(text)

    header, body = split_header_and_body(text)
    members, tail = extract_top_level_members(body)

    kept = []
    for block in members:
        if looks_like_method(block):
            if should_keep_method(block):
                kept.append(strip_security_annotations(block))
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
        if not src.name.endswith("Controller.java"):
            continue

        rel = src.relative_to(root)
        dst_rel = build_dst_rel(rel)
        dst = root / dst_rel

        convert_one_file(src, dst)
        count += 1

    print(f"generated app controllers: {count}")


if __name__ == "__main__":
    main()
