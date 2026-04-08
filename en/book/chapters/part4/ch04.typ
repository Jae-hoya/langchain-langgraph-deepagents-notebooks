// Auto-generated from 04_backends.ipynb
// Do not edit manually -- regenerate with nb2typ.py
#import "../../template.typ": *
#import "../../metadata.typ": *

#chapter(4, "Storage Backends")

== Learning Objectives
- Understand how backends implement the agent's filesystem
- Learn the characteristics and use cases of the five built-in backends
- Configure path-based routing with `CompositeBackend`
- Implement a custom backend with `BackendProtocol`


#code-block(`````python
# Environment setup
from dotenv import load_dotenv
import os

load_dotenv()
assert os.environ.get("OPENAI_API_KEY"), "OPENAI_API_KEY is not set!"
print("Environment setup complete")

from langchain_openai import ChatOpenAI

model = ChatOpenAI(model="gpt-4.1")

`````)

#line(length: 100%, stroke: 0.5pt + luma(200))
== 1. What Is a Backend?

Deep Agents' built-in file tools (`ls`, `read_file`, `write_file`, `edit_file`, `glob`, `grep`) all operate through a _backend_.

A backend abstracts the _storage layer_ that the agent uses to read and write files.

#image("../../../../book/assets/diagrams/png/backend_abstraction.png")

=== Available Backends

#table(
  columns: 4,
  align: left,
  stroke: 0.5pt + luma(200),
  inset: 8pt,
  fill: (_, row) => if row == 0 { rgb("#E0F2F3") } else if calc.odd(row) { luma(248) } else { white },
  text(weight: "bold")[Backend],
  text(weight: "bold")[Storage Location],
  text(weight: "bold")[Persistence],
  text(weight: "bold")[Use Case],
  [`StateBackend`],
  [Agent state (memory)],
  [Within a thread],
  [Scratch work, temporary tasks (default)],
  [`FilesystemBackend`],
  [Local disk],
  [Persistent],
  [Local file access, coding agents],
  [`StoreBackend`],
  [LangGraph Store],
  [Cross-thread],
  [Long-term memory, user preferences],
  [`CompositeBackend`],
  [Path-based routing],
  [Mixed],
  [Persistent memory + temporary files],
  [`LocalShellBackend`],
  [Disk + shell],
  [Persistent],
  [Development environments (security caution)],
)


#code-block(`````python
# Verify backend imports
from deepagents.backends import (
    StateBackend,
    FilesystemBackend,
    StoreBackend,
    CompositeBackend,
)
from deepagents.backends.protocol import BackendProtocol

print("All backend classes imported successfully!")

`````)

#line(length: 100%, stroke: 0.5pt + luma(200))
== 2. `StateBackend` (Default)

`StateBackend` stores files in agent state (LangGraph state).
It is _ephemeral_: files live only inside the current conversation thread.

=== Characteristics
- Used automatically when you do not pass `backend` to `create_deep_agent()`
- Files survive across agent turns through checkpoints
- Files disappear when the thread ends
- No external storage required


#line(length: 100%, stroke: 0.5pt + luma(200))
== 3. `FilesystemBackend` — Accessing the Local Disk

`FilesystemBackend` lets the agent access the _real local filesystem_.

=== Key Options
- `root_dir` — the root directory the agent can access (default: current directory)
- `virtual_mode=True` — limits paths and blocks escapes such as `..` and `~`
- `max_file_size_mb` — maximum readable file size

=== ⚠️ Security Considerations
#tip-box[`FilesystemBackend` gives the agent access to the real filesystem. In production, use `virtual_mode=True` or consider a sandbox backend instead.]


#line(length: 100%, stroke: 0.5pt + luma(200))
== 4. `StoreBackend` — Cross-Thread Persistent Storage

`StoreBackend` uses LangGraph's `BaseStore` to persist files _across conversation threads_.

=== Characteristics
- The same files can be accessed from different threads
- Supports different store implementations such as Redis and PostgreSQL
- Can be provisioned automatically in LangSmith deployments
- Uses assistant-level namespacing to isolate agents


#code-block(`````python
from langgraph.store.memory import InMemoryStore
from langgraph.checkpoint.memory import MemorySaver

# InMemoryStore is useful for development (use PostgresStore or similar in production)
store = InMemoryStore()
checkpointer = MemorySaver()

# StoreBackend must be passed as a backend factory
store_agent = create_deep_agent(
    model=model,
    system_prompt="You are an assistant that manages notes. Respond in English.",
    backend=lambda runtime: StoreBackend(runtime),
    store=store,
    checkpointer=checkpointer,
)

print("StoreBackend agent created!")

`````)

#line(length: 100%, stroke: 0.5pt + luma(200))
== 5. `CompositeBackend` — Path-Based Routing

`CompositeBackend` routes different filesystem paths to different backends.
A common pattern is to persist `/memories/*` while keeping everything else ephemeral.

#image("../../../../book/assets/diagrams/png/composite_backend.png")


#code-block(`````python
# CompositeBackend factory function
def create_composite_backend(runtime):
    """Create a backend with path-based routing."""
    return CompositeBackend(
        default=StateBackend(runtime),
        routes={
            "/memories/": StoreBackend(runtime),
        },
    )


composite_store = InMemoryStore()
composite_checkpointer = MemorySaver()

composite_agent = create_deep_agent(
    model=model,
    system_prompt="""You are a memory-management assistant.
- Save notes that need to persist under /memories/.
- Save temporary work files under the root path /.
Respond in English.""",
    backend=create_composite_backend,
    store=composite_store,
    checkpointer=composite_checkpointer,
)

print("CompositeBackend agent created!")

`````)

#note-box[_Note_: `CompositeBackend` removes the route prefix before storing the file internally. Example: `/memories/preferences.txt` → stored internally as `/preferences.txt` But the agent always accesses it with the full path (`/memories/preferences.txt`).]


#line(length: 100%, stroke: 0.5pt + luma(200))
== 6. `LocalShellBackend` — Shell Execution

`LocalShellBackend` extends `FilesystemBackend` by adding shell command execution through the `execute` tool.

=== ⚠️ Security Warning
#tip-box[Commands run directly on the host system _with your user permissions_. Use this only in development environments. In production, prefer a _sandbox backend_.]

#code-block(`````python
from deepagents.backends import LocalShellBackend

# ⚠️ Development only!
agent = create_deep_agent(
    model=model,
    backend=LocalShellBackend(root_dir="./workspace", virtual_mode=True),
    interrupt_on={"execute": True},  # require approval before shell commands
)
`````)

#note-box[For safety, this notebook does _not_ run `LocalShellBackend` directly.]


#line(length: 100%, stroke: 0.5pt + luma(200))
== 7. Implementing a Custom Backend

If you implement `BackendProtocol`, you can build your own backend.

=== Required Methods

#table(
  columns: 2,
  align: left,
  stroke: 0.5pt + luma(200),
  inset: 8pt,
  fill: (_, row) => if row == 0 { rgb("#E0F2F3") } else if calc.odd(row) { luma(248) } else { white },
  text(weight: "bold")[Method],
  text(weight: "bold")[Description],
  [`ls_info(path)`],
  [List directory contents],
  [`read(file_path, offset, limit)`],
  [Read a file with line numbers],
  [`write(file_path, content)`],
  [Create a new file],
  [`edit(file_path, old_string, new_string)`],
  [Replace text],
  [`grep_raw(pattern, path, glob)`],
  [Search file contents by pattern],
  [`glob_info(pattern, path)`],
  [Search files by glob pattern],
)


#code-block(`````python
# Simple example: read-only dictionary-backed backend
from deepagents.backends.protocol import FileInfo, GrepMatch, WriteResult, EditResult


class ReadOnlyDictBackend:
    """Example of a read-only backend backed by a Python dictionary."""

    def __init__(self, files: dict[str, str]):
        self._files = files

    def ls_info(self, path: str = "/") -> list[FileInfo]:
        return [
            {"path": p, "is_dir": False, "size": len(c), "modified_at": None}
            for p, c in self._files.items()
            if p.startswith(path)
        ]

    def read(self, file_path: str, offset: int = 0, limit: int = 2000) -> str:
        content = self._files.get(file_path, "")
        lines = content.splitlines()
        selected = lines[offset:offset + limit]
        return "\n".join(f"{i + offset + 1}\t{line}" for i, line in enumerate(selected))

    def write(self, file_path: str, content: str) -> WriteResult:
        return WriteResult(error="This backend is read-only.", path=None, files_update=None)

    def edit(self, file_path: str, old_string: str, new_string: str, replace_all: bool = False) -> EditResult:
        return EditResult(error="This backend is read-only.", path=None, files_update=None, occurrences=None)

    def grep_raw(self, pattern: str, path: str | None = None, glob: str | None = None) -> list[GrepMatch]:
        import re
        results = []
        for fpath, content in self._files.items():
            for i, line in enumerate(content.splitlines(), 1):
                if re.search(pattern, line):
                    results.append({"path": fpath, "line": i, "text": line})
        return results

    def glob_info(self, pattern: str, path: str = "/") -> list[FileInfo]:
        import fnmatch
        return [
            {"path": p, "is_dir": False, "size": len(c), "modified_at": None}
            for p, c in self._files.items()
            if fnmatch.fnmatch(p, pattern)
        ]


custom_backend = ReadOnlyDictBackend({
    "/docs/guide.md": "# Guide\nThis is a guide document.\n## Installation\npip install deepagents",
    "/docs/faq.md": "# FAQ\nQ: Which models are supported?\nA: Anthropic, OpenAI, and more.",
})

print("File list:", custom_backend.ls_info("/"))
print()
print("File contents:")
print(custom_backend.read("/docs/guide.md"))
print()
print("Search results:", custom_backend.grep_raw("Installation"))

`````)

#line(length: 100%, stroke: 0.5pt + luma(200))
== Backend Selection Guide

#image("../../../../book/assets/diagrams/png/backend_decision_tree.png")


#line(length: 100%, stroke: 0.5pt + luma(200))
== Summary

#table(
  columns: 3,
  align: left,
  stroke: 0.5pt + luma(200),
  inset: 8pt,
  fill: (_, row) => if row == 0 { rgb("#E0F2F3") } else if calc.odd(row) { luma(248) } else { white },
  text(weight: "bold")[Backend],
  text(weight: "bold")[Characteristics],
  text(weight: "bold")[Parameters],
  [`StateBackend`],
  [Ephemeral, default],
  [Used automatically when `backend` is omitted],
  [`FilesystemBackend`],
  [Local disk access],
  [`root_dir`, `virtual_mode`],
  [`StoreBackend`],
  [Cross-thread persistence],
  [requires `store` + `checkpointer`],
  [`CompositeBackend`],
  [Path-based routing],
  [`default` + `routes`],
  [`LocalShellBackend`],
  [Disk + shell execution],
  [`root_dir` (security caution)],
)

== Next Steps
→ _#link("./05_subagents.ipynb")[05_subagents.ipynb]_: learn how to delegate work with subagents.

