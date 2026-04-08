#!/usr/bin/env python3
from pathlib import Path
import shutil
import subprocess

BOOK_DIR = Path(__file__).resolve().parent.parent
OUTPUT_PDF = BOOK_DIR / "agent-handbook-en.pdf"

def main() -> int:
    typst = shutil.which("typst")
    if not typst:
        print("typst is not installed")
        return 1
    repo_root = BOOK_DIR.parent.parent
    shared_fonts = repo_root / "book" / "fonts"
    cmd = [
        typst,
        "compile",
        str(BOOK_DIR / "main.typ"),
        str(OUTPUT_PDF),
        "--root",
        str(repo_root),
        "--font-path",
        str(shared_fonts),
    ]
    result = subprocess.run(cmd, cwd=str(BOOK_DIR))
    return result.returncode

if __name__ == "__main__":
    raise SystemExit(main())
