// Auto-generated from 05_memory_and_streaming.ipynb
// Do not edit manually -- regenerate with nb2typ.py
#import "../../template.typ": *
#import "../../metadata.typ": *

#chapter(5, "Memory and Streaming")

Learn about the _memory system_ and _streaming modes_ used by LangChain v1 agents.


== Learning Objectives

- _Short-term memory:_ understand how to preserve conversation state with `InMemorySaver` and `thread_id`
- _Long-term memory:_ use `InMemoryStore` to persist memory across conversations
- _Message trimming:_ learn how to keep long conversations within a token budget
- _Streaming modes:_ understand the differences between `values`, `updates`, `messages`, and `custom`


== 5.1 Environment Setup


#code-block(`````python
from dotenv import load_dotenv
import os
load_dotenv(override=True)

from langchain_openai import ChatOpenAI

model = ChatOpenAI(
    model="gpt-4.1",
)

print("Model ready:", model.model_name)
`````)

== 5.2 Short-Term Memory: `InMemorySaver`

Short-term memory is the mechanism that remembers previous messages _within a single conversation session_.

- `InMemorySaver` acts as a checkpointer and stores agent state in memory.
- `thread_id` separates different conversation sessions.
- Reusing the same `thread_id` preserves previous conversation context.


== 5.3 Independent Conversations with Different `thread_id` Values

If you use a different `thread_id`, you create a completely _independent conversation session_. Context is not shared with the previous session.


== 5.4 Message Trimming

As a conversation grows, the token count increases and affects both cost and performance. _Message trimming_ keeps only the most relevant messages within a token budget.

- `trim_messages`: keeps only the most recent N messages or the messages that fit within the token budget
- `strategy="last"`: prioritizes the most recent messages
- `include_system=True`: always preserves the system message


== 5.5 Long-Term Memory: `InMemoryStore`

Long-term memory stores information that persists _across conversation sessions_.

- `InMemoryStore` is a key-value store for user preferences, settings, and similar data.
- Tools can access the store through the `ToolRuntime` parameter.
- The same data is available from every session, regardless of `thread_id`.

Differences between short-term and long-term memory:

#table(
  columns: 3,
  align: left,
  stroke: 0.5pt + luma(200),
  inset: 8pt,
  fill: (_, row) => if row == 0 { rgb("#E0F2F3") } else if calc.odd(row) { luma(248) } else { white },
  text(weight: "bold")[Type],
  text(weight: "bold")[Short-Term Memory (Checkpointer)],
  text(weight: "bold")[Long-Term Memory (Store)],
  [Scope],
  [Inside a single `thread_id`],
  [Across all sessions],
  [What it stores],
  [Conversation message history],
  [User preferences, learned data],
  [Lifetime],
  [Until the session ends (or persists)],
  [Until explicitly deleted],
  [Access],
  [Automatic (inside the agent)],
  [Explicit (through tools)],
)


== 5.6 Streaming Modes

LangChain provides streaming so you can _observe agent execution in real time_. Choose the mode that best fits your use case.


=== Streaming Mode Comparison

#table(
  columns: 3,
  align: left,
  stroke: 0.5pt + luma(200),
  inset: 8pt,
  fill: (_, row) => if row == 0 { rgb("#E0F2F3") } else if calc.odd(row) { luma(248) } else { white },
  text(weight: "bold")[Mode],
  text(weight: "bold")[Description],
  text(weight: "bold")[Use Case],
  [`values`],
  [Full state after each step],
  [Debugging, state inspection],
  [`updates`],
  [Only the updates from each node],
  [Progress displays],
  [`messages`],
  [Message tokens],
  [Chat UI],
  [`custom`],
  [Custom user-defined events],
  [Custom progress indicators],
)


=== A Note on `stream_mode="custom"`

`stream_mode="custom"` is for user-defined events. It is not directly supported by agents created with `create_agent`; instead, you must use the _lower-level LangGraph API_ (`StateGraph`) and emit custom events manually through a `StreamWriter`.

#code-block(`````python
# Example at the LangGraph StateGraph level (reference only)
from langgraph.graph import StateGraph

def my_node(state, writer):  # StreamWriter is injected
    writer("progress", {"step": 1, "status": "processing"})
    # ... work ...
    writer("progress", {"step": 2, "status": "done"})
    return state
`````)

If you are using `create_agent`, the recommended pattern for progress indicators is to combine `stream_mode="updates"` with middleware.


== 5.7 Summary

Here is a summary of what this notebook covered:

#table(
  columns: 3,
  align: left,
  stroke: 0.5pt + luma(200),
  inset: 8pt,
  fill: (_, row) => if row == 0 { rgb("#E0F2F3") } else if calc.odd(row) { luma(248) } else { white },
  text(weight: "bold")[Concept],
  text(weight: "bold")[Implementation],
  text(weight: "bold")[Description],
  [_Short-term memory_],
  [`InMemorySaver` + `thread_id`],
  [Keeps context inside one conversation session],
  [_Session isolation_],
  [Different `thread_id` values],
  [Manages independent conversation sessions],
  [_Message trimming_],
  [`trim_messages` + middleware],
  [Limits messages to stay within the token budget],
  [_Long-term memory_],
  [`InMemoryStore` + `ToolRuntime`],
  [Stores user data that persists across conversations],
  [_Streaming (values)_],
  [`stream_mode="values"`],
  [Full state snapshot at each step],
  [_Streaming (updates)_],
  [`stream_mode="updates"`],
  [Node-by-node updates],
  [_Streaming (messages)_],
  [`stream_mode="messages"`],
  [Real-time token output],
  [_Streaming (custom)_],
  [`stream_mode="custom"`],
  [Only available at the LangGraph `StateGraph` level],
)

_Key points:_
- Short-term memory is isolated by `thread_id` and preserves context only within the same session.
- Long-term memory is shared across sessions through `InMemoryStore`.
- `stream_mode="values"` is useful for debugging because it returns the full state at every step.
- `stream_mode="custom"` cannot be used directly with `create_agent`; it requires LangGraph's `StateGraph` API.
- Choosing the right streaming mode can significantly improve user experience.

=== Next Steps
→ _#link("./06_middleware.ipynb")[06_middleware.ipynb]_: Learn about middleware and guardrails.

