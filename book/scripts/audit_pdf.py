#!/usr/bin/env python3
"""audit_pdf.py — Basic PDF layout audit for Agent Handbook."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import fitz


def audit(pdf_path: Path) -> dict:
    pdf = fitz.open(str(pdf_path))
    pages = []
    image_pages = []

    for i, page in enumerate(pdf, start=1):
        page_dict = page.get_text("dict")
        blocks = page_dict.get("blocks", [])
        image_blocks = [b for b in blocks if b.get("type") == 1]
        text_blocks = [b for b in blocks if b.get("type") == 0]

        item = {
            "page": i,
            "images": len(image_blocks),
            "text_blocks": len(text_blocks),
            "text_chars": len(page.get_text("text").strip()),
        }
        pages.append(item)
        if image_blocks:
            image_pages.append(i)

    return {
        "pdf": str(pdf_path),
        "page_count": len(pdf),
        "image_pages": image_pages,
        "pages": pages,
    }


def write_markdown(report: dict, output_path: Path) -> None:
    lines = [
        "# Agent Handbook PDF Audit",
        "",
        f"- PDF: `{report['pdf']}`",
        f"- 총 페이지: {report['page_count']}",
        f"- 이미지 포함 페이지 수: {len(report['image_pages'])}",
        f"- 이미지 포함 페이지: {report['image_pages']}",
        "",
        "## 페이지 요약",
        "",
        "| 페이지 | 이미지 수 | 텍스트 블록 수 | 텍스트 길이 |",
        "|---:|---:|---:|---:|",
    ]

    for p in report["pages"]:
        lines.append(
            f"| {p['page']} | {p['images']} | {p['text_blocks']} | {p['text_chars']} |"
        )

    output_path.write_text("\n".join(lines))


def main() -> int:
    parser = argparse.ArgumentParser(description="Audit compiled PDF layout")
    parser.add_argument("pdf", nargs="?", default="book/agent-handbook.pdf")
    parser.add_argument("--json-out", default="book/output/pdf_audit.json")
    parser.add_argument("--md-out", default="book/output/pdf_audit.md")
    args = parser.parse_args()

    pdf_path = Path(args.pdf)
    json_out = Path(args.json_out)
    md_out = Path(args.md_out)
    json_out.parent.mkdir(parents=True, exist_ok=True)
    md_out.parent.mkdir(parents=True, exist_ok=True)

    report = audit(pdf_path)
    json_out.write_text(json.dumps(report, ensure_ascii=False, indent=2))
    write_markdown(report, md_out)

    print(f"OK audited: {pdf_path}")
    print(f"OK json: {json_out}")
    print(f"OK markdown: {md_out}")
    print(f"OK page_count: {report['page_count']}")
    print(f"OK image_pages: {len(report['image_pages'])}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
