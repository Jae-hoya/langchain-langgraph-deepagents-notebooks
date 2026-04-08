# English Handbook Worktree

This directory contains the English Typst handbook worktree.

## Current state

- `metadata.typ`, `template.typ`, frontmatter, and glossary are prepared.
- English chapter `.typ` files have been generated under `chapters/part*/` from the translated notebooks.
- English handbook chapters reuse shared diagram/logo assets from `../../book/assets/` to avoid duplicate copies inside `en/book/`.
- `agent-handbook-en.pdf` is now generated from a **full compile** in `main.typ` that includes the translated chapter sources.

## Key files

- `main.typ` — current English handbook entry point
- `agent-handbook-en.pdf` — final compiled English handbook PDF
- Shared fonts are loaded from `../../book/fonts/` during compilation.
- `scripts/config.yaml` — English notebook-to-Typst mapping
- `chapters/` — generated English chapter sources
