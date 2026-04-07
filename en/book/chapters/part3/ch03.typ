// Auto-generated from 03_functional_api.ipynb
// Do not edit manually -- regenerate with nb2typ.py
#import "../../template.typ": *
#import "../../metadata.typ": *

#chapter(3, "Functional API", subtitle: "Creating workflow with @entrypoint and @task")

== Learning Objectives

Understand the `@entrypoint`, `@task` patterns and short-term memory of the Functional API.

== 3.1 Environment Setup

#code-block(`````python
from dotenv import load_dotenv
load_dotenv(override=True)

from langchain_openai import ChatOpenAI
model = ChatOpenAI(model="gpt-4.1")
`````)

== 3.2 \@task — Asynchronous unit of work

- Checkpointing is possible by wrapping it with the `@task` decorator.
- Returns Future object immediately when called, waits with `.result()`

== 3.3 Parallel `\@task` execution

Running multiple `@task` simultaneously.

== 3.4 previous — short-term memory (accessing previous execution results)

== 3.5 entrypoint.final — Separate return and checkpoint saved values

== 3.6 Determinism Requirements

Non-deterministic operations must be wrapped in `@task`.

== 3.7 LLM agent (Functional API)

Implementing ReAct agent with while loop

== 3.8 Summary

#table(
  columns: 2,
  align: left,
  stroke: 0.5pt + luma(200),
  inset: 8pt,
  fill: (_, row) => if row == 0 { rgb("#E0F2F3") } else if calc.odd(row) { luma(248) } else { white },
  text(weight: "bold")[Features],
  text(weight: "bold")[Description],
  [`\@task`],
  [Asynchronous operations, checkpointing, parallel execution],
  [`\@entrypoint`],
  [workflow Entry point, execution management],
  [`.result()`],
  [Future Result Synchronous Waiting],
  [`previous`],
  [Access previous execution results (short-term memory)],
  [`entrypoint.final`],
  [Separate return value ≠ stored value],
)

=== Next Steps
→ _#link("./04_workflows.ipynb")[04_workflows.ipynb]_: Learn the workflow pattern.
