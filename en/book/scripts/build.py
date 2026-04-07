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
    cmd = [typst, "compile", str(BOOK_DIR / "main.typ"), str(OUTPUT_PDF), "--font-path", str(BOOK_DIR / "fonts")]
    result = subprocess.run(cmd, cwd=str(BOOK_DIR))
    return result.returncode

if __name__ == "__main__":
    raise SystemExit(main())
