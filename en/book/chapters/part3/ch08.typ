// Auto-generated from 08_interrupts_and_time_travel.ipynb
// Do not edit manually -- regenerate with nb2typ.py
#import "../../template.typ": *
#import "../../metadata.typ": *

#chapter(8, "Interrupts and Time Travel", subtitle: "Execute interrupt, Acknowledge, Rewind")

== Learning Objectives

Execute with `interrupt()`, interrupt, and resume with `Command(resume=...)`. Time travel back to the previous state.

- Human-in-the-loop pattern can be implemented
- Interrupt can also be used in Functional API
- You can perform time travel using checkpoint history.
- state can be modified externally with `update_state()`

== 8.1 Environment Setup

#code-block(`````python
from dotenv import load_dotenv
load_dotenv(override=True)
from langchain_openai import ChatOpenAI

model = ChatOpenAI(model="gpt-4.1")
print("Model is ready")
`````)

== 8.2 interrupt() — executes interrupt and waits for human input

- `interrupt(value)`: Save the current state to the checkpoint and execute interrupt
- `Command(resume=value)`: Passes the value at interrupt point and resume

This pattern is used to obtain human approval or input additional information before performing sensitive tasks.

== 8.3 Command(resume=...) — interrupt executes resume

Using `Command(resume=value)` causes execution to resume at the point where `interrupt()` is called. The value passed to `resume` becomes the return value of `interrupt()`.

== 8.4 Interrupt in Functional API

You can also use `interrupt()` in the Functional API (`@entrypoint`, `@task`).

== 8.5 Time Travel — Go back to a previous checkpoint

The checkpoint system in LangGraph stores all executions of state. You can view previous checkpoints with `get_state_history()` and go back to a specific point in time.

== 8.6 update_state() — Time travel + state fix

`update_state()` allows you to directly modify the state of a graph from the outside. This is useful for debugging, testing, or when manual intervention is required.

== 8.7 Summary

Summarize the key functions learned in this Note book.

#table(
  columns: 3,
  align: left,
  stroke: 0.5pt + luma(200),
  inset: 8pt,
  fill: (_, row) => if row == 0 { rgb("#E0F2F3") } else if calc.odd(row) { luma(248) } else { white },
  text(weight: "bold")[Features],
  text(weight: "bold")[API],
  text(weight: "bold")[Description],
  [`interrupt(value)`],
  [Both sides],
  [run interrupt, pass value],
  [`Command(resume=value)`],
  [Both sides],
  [resume at point interrupt],
  [`get_state_history()`],
  [Graph],
  [Checkpoint history inquiry],
  [`update_state()`],
  [Graph],
  [Modify state externally],
)

_interrupts and time travel_ are key features in production AI applications:
- _interrupt_: Get human approval before sensitive operations
- _Time Travel_: You can go back to the previous state and explore different routes
- _update_state_: You can adjust the execution flow by modifying state externally.

=== Next Steps
→ _#link("./09_subgraphs.ipynb")[09_subgraphs.ipynb]_: Learn subgraphs.
