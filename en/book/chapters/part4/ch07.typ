// Auto-generated from 07_advanced.ipynb
// Do not edit manually -- regenerate with nb2typ.py
#import "../../template.typ": *
#import "../../metadata.typ": *

#chapter(7, "Advanced Features")

== Learning Objectives
- Implement a Human-in-the-Loop workflow
- Understand streaming modes and the namespace system
- Understand sandbox integrations such as Modal, Daytona, and Runloop
- Learn how ACP (Agent Client Protocol) connects agents to editors
- Learn how to use the Deep Agents CLI


#code-block(`````python
# Environment setup
from dotenv import load_dotenv
import os

load_dotenv()
assert os.environ.get("OPENAI_API_KEY"), "OPENAI_API_KEY is not set!"
print("Environment setup complete")

`````)

#code-block(`````python
from langchain_openai import ChatOpenAI

model = ChatOpenAI(model="gpt-4.1")

print(f"Model configured: {model.model_name}")

`````)

#line(length: 100%, stroke: 0.5pt + luma(200))
== 1. Human-in-the-Loop (HITL)

Human-in-the-Loop is a workflow in which the agent _requires human approval_ before calling sensitive tools.

=== How it Works

#image("../../assets/images/hitl_flow.png")

=== Required Condition
- _Checkpointer_: required to preserve the agent's state between interrupt and resume


#code-block(`````python
from deepagents import create_deep_agent
from langgraph.checkpoint.memory import MemorySaver

# Choose which tools require approval with interrupt_on
hitl_agent = create_deep_agent(
    model=model,
    system_prompt="You are a file management assistant. Respond in English.",
    checkpointer=MemorySaver(),  # required!
    interrupt_on={
        "write_file": True,
        "edit_file": True,
    },
)

print("Human-in-the-Loop agent created")
print("write_file and edit_file now require approval")

`````)

#line(length: 100%, stroke: 0.5pt + luma(200))
== 2. Advanced Streaming

Deep Agents runs on top of LangGraph's streaming infrastructure.

=== Stream Modes

#table(
  columns: 3,
  align: left,
  stroke: 0.5pt + luma(200),
  inset: 8pt,
  fill: (_, row) => if row == 0 { rgb("#E0F2F3") } else if calc.odd(row) { luma(248) } else { white },
  text(weight: "bold")[Mode],
  text(weight: "bold")[Description],
  text(weight: "bold")[Use Case],
  [`"updates"`],
  [State updates after each node finishes],
  [Progress tracking],
  [`"messages"`],
  [Token-level streaming],
  [Real-time text output],
  [`"custom"`],
  [Events emitted inside tools or nodes],
  [Custom progress reporting],
)

=== Namespace System

Events from subagents are separated by namespace:

#code-block(`````python
()                                # main agent
("tools:abc123",)                # subagent (tool call ID)
("tools:abc123", "model:def456")  # inner node inside a subagent
`````)


#code-block(`````python
from typing import Literal
from tavily import TavilyClient

tavily_client = TavilyClient(api_key=os.environ.get("TAVILY_API_KEY", ""))


def internet_search(
    query: str,
    max_results: int = 3,
    topic: Literal["general", "news"] = "general",
) -> dict:
    """Search the internet for information."""
    return tavily_client.search(query, max_results=max_results, topic=topic)


stream_agent = create_deep_agent(
    model=model,
    system_prompt="You are a research coordinator. Respond in English.",
    subagents=[
        {
            "name": "researcher",
            "description": "Uses internet search to investigate topics.",
            "system_prompt": "Search the internet, collect the requested information, and summarize it concisely.",
            "tools": [internet_search],
        }
    ],
)

print("Streaming demo agent created")

`````)

#line(length: 100%, stroke: 0.5pt + luma(200))
== 3. Sandboxes

A sandbox lets the agent run code in an _isolated environment_.
That prevents it from accessing the host machine's files, network, or credentials directly.

=== Supported Providers

#table(
  columns: 3,
  align: left,
  stroke: 0.5pt + luma(200),
  inset: 8pt,
  fill: (_, row) => if row == 0 { rgb("#E0F2F3") } else if calc.odd(row) { luma(248) } else { white },
  text(weight: "bold")[Provider],
  text(weight: "bold")[Characteristics],
  text(weight: "bold")[Best Fit],
  [_Modal_],
  [GPU support, ML workloads],
  [AI / ML tasks],
  [_Daytona_],
  [TypeScript / Python, fast cold starts],
  [Web development],
  [_Runloop_],
  [Disposable devboxes, isolated execution],
  [Code testing],
)

=== Architecture Pattern

_Use the sandbox as a tool_ (recommended)

#image("../../assets/images/sandbox_architecture.png")

=== ⚠️ Security Guidelines
- _Never put secrets inside the sandbox_ — the agent may leak them
- Manage credentials only through external tools
- Use Human-in-the-Loop approval for sensitive operations
- Block unnecessary network access


#code-block(`````python
# Sandbox integration example (reference only — requires provider-specific setup)

sandbox_example_code = """
# pip install deepagents-modal
from deepagents.backends.sandbox import ModalSandbox

agent = create_deep_agent(
    model="anthropic:claude-sonnet-4-6",
    backend=ModalSandbox(
        image="python:3.12-slim",
        gpu="T4",  # GPU support
    ),
)
"""

print("Sandbox integration example (reference only):")
print(sandbox_example_code)

`````)

#line(length: 100%, stroke: 0.5pt + luma(200))
== 4. ACP (Agent Client Protocol)

ACP standardizes communication _between coding agents and editors / IDEs_.

=== Supported Editors
- _Zed_ — native integration
- _JetBrains IDEs_ — built-in support
- _VS Code_ — `vscode-acp` plugin
- _Neovim_ — ACP-compatible plugins

=== MCP vs ACP
#table(
  columns: 2,
  align: left,
  stroke: 0.5pt + luma(200),
  inset: 8pt,
  fill: (_, row) => if row == 0 { rgb("#E0F2F3") } else if calc.odd(row) { luma(248) } else { white },
  text(weight: "bold")[Protocol],
  text(weight: "bold")[Purpose],
  [MCP (Model Context Protocol)],
  [External tool integration],
  [ACP (Agent Client Protocol)],
  [Editor ↔ agent integration],
)


#code-block(`````python
# ACP server implementation example (reference only)
acp_example_code = """
# pip install deepagents-acp
from deepagents import create_deep_agent
from deepagents_acp import AgentServerACP
from langgraph.checkpoint.memory import MemorySaver

# Create the agent
agent = create_deep_agent(
    model="anthropic:claude-sonnet-4-6",
    system_prompt="You are a coding assistant.",
    checkpointer=MemorySaver(),
)

# Run the ACP server (stdio mode)
server = AgentServerACP(agent)
server.run()
"""

print("ACP server implementation example (reference only):")
print(acp_example_code)

`````)

#line(length: 100%, stroke: 0.5pt + luma(200))
== 5. Deep Agents CLI

The Deep Agents CLI is a _terminal coding agent_ built on top of the SDK.

=== Installation and Execution
#code-block(`````bash
# Install
uv tool install deepagents-cli

# Run
deepagents-cli

# Run directly without installing
uvx deepagents-cli
`````)

=== Main Options

#table(
  columns: 2,
  align: left,
  stroke: 0.5pt + luma(200),
  inset: 8pt,
  fill: (_, row) => if row == 0 { rgb("#E0F2F3") } else if calc.odd(row) { luma(248) } else { white },
  text(weight: "bold")[Option],
  text(weight: "bold")[Description],
  [`-a/--agent AGENT`],
  [Specify the agent name],
  [`-M/--model MODEL`],
  [Choose the model],
  [`-n/--non-interactive`],
  [Non-interactive mode (single task execution)],
  [`--auto-approve`],
  [Skip human confirmation],
  [`--sandbox {none,modal,daytona,runloop}`],
  [Select a sandbox backend],
)

=== Interactive Commands

#table(
  columns: 2,
  align: left,
  stroke: 0.5pt + luma(200),
  inset: 8pt,
  fill: (_, row) => if row == 0 { rgb("#E0F2F3") } else if calc.odd(row) { luma(248) } else { white },
  text(weight: "bold")[Command],
  text(weight: "bold")[Description],
  [`/model`],
  [Change the model],
  [`/remember`],
  [Store information in memory],
  [`/tokens`],
  [Inspect token usage],
  [`!command`],
  [Run a shell command],
)

=== Memory System
- _Global_: `~/.deepagents/<agent_name>/memories/`
- _Project_: `.deepagents/AGENTS.md` (project root)


#code-block(`````python
# CLI non-interactive examples (run in the shell)
cli_examples = """
# Basic usage
deepagents-cli

# Non-interactive execution with a specific model
deepagents-cli -M claude-sonnet-4-6 -n "Write the README.md file for this project"

# Run inside a sandbox
deepagents-cli --sandbox modal "Run the test suite"

# Skill management
deepagents-cli skills list
deepagents-cli skills create my-skill
"""

print("CLI usage examples (run in the terminal):")
print(cli_examples)

`````)

#line(length: 100%, stroke: 0.5pt + luma(200))
== Full Track Summary

#table(
  columns: 3,
  align: left,
  stroke: 0.5pt + luma(200),
  inset: 8pt,
  fill: (_, row) => if row == 0 { rgb("#E0F2F3") } else if calc.odd(row) { luma(248) } else { white },
  text(weight: "bold")[Notebook],
  text(weight: "bold")[Topic],
  text(weight: "bold")[Key APIs],
  [_01_],
  [Introduction],
  [`deepagents.__version__`],
  [_02_],
  [Quickstart],
  [`create_deep_agent()`, `invoke()`, `stream()`],
  [_03_],
  [Customization],
  [`model`, `system_prompt`, `tools`, `response_format`],
  [_04_],
  [Backends],
  [`StateBackend`, `FilesystemBackend`, `StoreBackend`, `CompositeBackend`],
  [_05_],
  [Subagents],
  [`SubAgent`, `CompiledSubAgent`, `subagents`],
  [_06_],
  [Memory & Skills],
  [`memory`, `skills`, `AGENTS.md`, `SKILL.md`],
  [_07_],
  [Advanced Features],
  [`interrupt_on`, `stream_mode`, Sandbox, ACP, CLI],
)

=== Next Steps
→ Continue to _#link("./08_harness.ipynb")[08_harness.ipynb]_
→ Or jump to the _advanced track_ at _#link("../05_advanced/00_migration.ipynb")[../05_advanced/00_migration.ipynb]_

