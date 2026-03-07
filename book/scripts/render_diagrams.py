#!/usr/bin/env python3
"""render_diagrams.py — Render Mermaid .mmd files to SVG using mmdc."""

import subprocess
import sys
from pathlib import Path


def render_all(mmd_dir: str = None, svg_dir: str = None) -> int:
    """Render all .mmd files to .svg."""
    base = Path(__file__).parent.parent
    mmd_path = Path(mmd_dir) if mmd_dir else base / "diagrams" / "mmd"
    svg_path = Path(svg_dir) if svg_dir else base / "diagrams" / "svg"
    svg_path.mkdir(parents=True, exist_ok=True)

    mmd_files = sorted(mmd_path.glob("*.mmd"))
    if not mmd_files:
        print("No .mmd files found")
        return 0

    print(f"Rendering {len(mmd_files)} diagrams...")
    errors = 0

    for mmd_file in mmd_files:
        svg_file = svg_path / f"{mmd_file.stem}.svg"
        print(f"  {mmd_file.name} → {svg_file.name} ... ", end="")

        try:
            result = subprocess.run(
                [
                    "mmdc",
                    "-i", str(mmd_file),
                    "-o", str(svg_file),
                    "-t", "neutral",
                    "--width", "1200",
                ],
                capture_output=True,
                text=True,
                timeout=30,
            )
            if result.returncode == 0:
                print("✓")
            else:
                print(f"✗ ({result.stderr.strip()[:80]})")
                errors += 1
        except FileNotFoundError:
            print("✗ (mmdc not found — install @mermaid-js/mermaid-cli)")
            errors += 1
            break
        except subprocess.TimeoutExpired:
            print("✗ (timeout)")
            errors += 1

    print(f"\nDone: {len(mmd_files) - errors}/{len(mmd_files)} rendered successfully")
    return errors


if __name__ == "__main__":
    mmd = sys.argv[1] if len(sys.argv) > 1 else None
    svg = sys.argv[2] if len(sys.argv) > 2 else None
    sys.exit(render_all(mmd, svg))
