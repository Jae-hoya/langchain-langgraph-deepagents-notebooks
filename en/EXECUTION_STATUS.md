# English Notebook Execution Status

Final execution check performed with:
- `source ~/.zshrc`
- `uv run --python 3.12`
- `LANGFUSE_SECRET_KEY`, `LANGFUSE_PUBLIC_KEY`, and `LANGFUSE_HOST` unset during execution to avoid optional tracing interference
- `OPENAI_API_KEY` and `TAVILY_API_KEY` loaded from `~/.env`

## Result

- English notebooks discovered: **59**
- English notebooks executed successfully: **59 / 59**
- Detailed per-notebook results: [execution_results.tsv](execution_results.tsv)

## Notes

- The English notebooks pass JSON structure checks.
- The English notebook code cells pass Python AST parsing.
- Some notebooks require live API/network calls, so this successful execution depends on the currently configured API keys and network access.

## Handbook PDF Verification

Current English handbook PDF:
- `en/book/agent-handbook-en.pdf`

Verified with `pdfinfo` / `mdls`:
- Pages: **23**
- Page size: **A4**
- File size: **237,310 bytes**
- Title: **Agent Handbook with LangChain, LangGraph & Deep Agents**
- Author: **BAEUM.AI**

## Important handbook note

The current `en/book/main.typ` now supports a **full chapter compile**.

The full generated chapter `.typ` files under `en/book/chapters/` are included in the compiled handbook PDF, and the diagram/image assets used by the English handbook have been translated under `en/assets/` and copied into `en/book/assets/`.
