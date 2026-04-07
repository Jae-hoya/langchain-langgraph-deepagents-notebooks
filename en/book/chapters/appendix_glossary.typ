// appendix_glossary.typ — English glossary appendix
#import "../template.typ": *
#import "../metadata.typ": *

#pagebreak(weak: true)

#heading(level: 1)[Appendix A. Glossary]

#let glossary-item(term, desc) = [
  #text(weight: "bold", fill: color-secondary)[#term]
  #h(6pt)
  #desc
  #v(8pt)
]

#grid(
  columns: (auto, 1fr),
  column-gutter: 14pt,
  align: (right + bottom, left + bottom),
  text(
    size: 48pt,
    weight: "bold",
    fill: luma(220),
    font: font-body,
  )[A],
  {
    text(size: 22pt, weight: "bold", fill: color-secondary, tracking: 0.3pt)[Appendix A. Glossary]
    v(2pt)
    text(size: 11pt, fill: luma(130), style: "italic")[Core terms that appear throughout the handbook]
  },
)
#v(8pt)
#line(length: 100%, stroke: 0.5pt + luma(220))
#v(16pt)

This appendix collects the key terms that appear repeatedly throughout the handbook so you can review them in one place. You do not need to memorize everything at once; revisit this section whenever you encounter an unfamiliar term.

#note-box[The goal of this glossary is not to replace the official API documentation, but to let you quickly confirm the concepts that appear often while reading the handbook. For implementation details, refer to the relevant chapter and reference documents.]

== Frameworks and Products

#glossary-item([LangChain], [A high-level framework for quickly building agents and LLM applications by combining models, tools, prompts, and middleware.])
#glossary-item([LangGraph], [A runtime and framework for orchestrating complex workflows and long-running agents with state, nodes, edges, and checkpointers.])
#glossary-item([Deep Agents], [An all-in-one agent SDK built on top of LangGraph that adds planning, filesystem tooling, subagents, memory, and sandbox capabilities.])
#glossary-item([LangSmith], [An observability and quality platform for tracing, evaluation, dataset management, and debugging.])
#glossary-item([Langfuse], [An open-source-style observability tool for collecting traces and runtime telemetry.])
#glossary-item([MCP], [Short for Model Context Protocol, a protocol that connects external tools and resources to models and agents in a standard way.])
#glossary-item([ACP], [Short for Agent Client Protocol, a communication protocol for connecting agents to clients such as editors and IDEs.])

== Agents and Execution Model

#glossary-item([Agent], [An execution unit in which an LLM uses tools, observes results, and keeps acting until the task is complete.])
#glossary-item([ReAct], [Short for Reasoning + Acting, a common agent pattern in which the model alternates between reasoning and tool use.])
#glossary-item([Workflow], [An execution flow whose steps and order are relatively well-defined. It is usually more deterministic than a free-form agent loop.])
#glossary-item([Orchestrator], [A higher-level controller that coordinates several steps or several workers and manages the overall flow.])
#glossary-item([Worker], [An execution unit that performs a specific task delegated by an orchestrator.])
#glossary-item([Subagent], [A helper agent called by a main agent to handle a more focused sub-task, often with its own context.])
#glossary-item([Handoff], [A pattern in which control is transferred to another role or agent depending on the current step or state.])
#glossary-item([Router], [A pattern that classifies the input or current state and sends it to the most appropriate path or specialist agent.])
#glossary-item([Human-in-the-Loop], [A safety mechanism that inserts human approval, edits, or rejection at sensitive execution steps or important branch points.])
#glossary-item([Interrupt], [A mechanism that pauses graph or agent execution in the middle and waits for external input.])
#glossary-item([Resume], [The action of continuing a paused execution from its prior state. This usually requires the same `thread_id` and a checkpointer.])
#glossary-item([Durable Execution], [An execution style that stores progress so the system can restart from the last successful point after an interruption or failure.])
#glossary-item([Pregel], [A message-passing computation model that influences LangGraph's internal runtime, where nodes run in supersteps.])
#glossary-item([Superstep], [A parallel computation round in the Pregel model during which several nodes run together.])

== State and Memory

#glossary-item([State], [The collection of current task information that an agent or graph maintains and updates while it runs.])
#glossary-item([AgentState], [The default state schema used in LangChain agent execution. It includes reserved fields such as `messages`.])
#glossary-item([MessagesState], [A convenient LangGraph state type centered on a list of messages.])
#glossary-item([Checkpointer], [A component that stores and restores execution state. It is essential for multi-turn conversations, interrupt/resume flows, and durable execution.])
#glossary-item([Thread ID], [A unique identifier for a conversation or execution flow. You must reuse the same `thread_id` to continue from a previous state.])
#glossary-item([Runtime Context], [Context such as metadata, permissions, or user information that is injected only at execution time.])
#glossary-item([`context_schema`], [A schema that defines the structure of static context that does not change during execution.])
#glossary-item([`state_schema`], [A schema that defines the structure of dynamic state that can keep changing during execution.])
#glossary-item([Short-term memory], [Memory that is kept only within a single thread or conversation, usually the recent message history and work state.])
#glossary-item([Long-term memory], [Memory that persists after a conversation ends and can be reused in later threads, such as preferences or learned facts.])
#glossary-item([Store], [A storage layer that saves and retrieves data outside a single thread.])
#glossary-item([InMemoryStore], [A simple in-memory store implementation. It is convenient for development and testing, but data disappears on restart.])
#glossary-item([Semantic memory], [Long-term memory that stores meaning-based information such as facts, preferences, and concepts.])
#glossary-item([Episodic memory], [Memory whose time order matters, such as specific events or interaction history.])
#glossary-item([Procedural memory], [Memory that captures rules, procedures, or behavior patterns the agent should follow.])

== Tools and Interfaces

#glossary-item([Tool], [A function or external action interface that an agent can call, such as search, calculation, file I/O, or an API request.])
#glossary-item([ToolRuntime], [A runtime object that gives tools access to the current state, context, store, and other execution-time resources.])
#glossary-item([`create_agent()`], [The main LangChain API for quickly creating a default agent.])
#glossary-item([`create_deep_agent()`], [The Deep Agents API for creating a harness-style agent with planning, files, and subagents.])
#glossary-item([`StateGraph`], [The LangGraph builder class used to define state-based graph workflows.])
#glossary-item([Graph API], [The LangGraph programming style in which you explicitly declare nodes and edges and assemble the graph structure.])
#glossary-item([Functional API], [The LangGraph programming style in which you describe workflows with Python functions, `@entrypoint`, and `@task`.])
#glossary-item([`@entrypoint`], [A decorator in the Functional API that defines the starting function of a workflow.])
#glossary-item([`@task`], [A Functional API decorator that wraps a unit of work that should have durability guarantees.])
#glossary-item([`Send`], [A LangGraph API used to fan out work dynamically to multiple workers.])
#glossary-item([`Command`], [A LangGraph control object that can express state updates, resume signals, and parent-graph transitions.])
#glossary-item([Structured output], [An output style that forces the model's answer into an explicit schema such as a Pydantic model or another structured format.])

== Backends and Execution Environments

#glossary-item([Backend], [The storage and execution layer in Deep Agents that abstracts file access and execution environments.])
#glossary-item([StateBackend], [An ephemeral file backend whose contents are kept only within a conversation thread.])
#glossary-item([FilesystemBackend], [A backend that accesses the local disk. In practice it is often used with `virtual_mode=True` to restrict paths.])
#glossary-item([StoreBackend], [A backend that provides persistent cross-thread storage through a LangGraph store.])
#glossary-item([CompositeBackend], [A mixed backend that routes requests to different backends depending on the path.])
#glossary-item([LocalShellBackend], [A powerful but risky backend that adds shell command execution on top of local file access.])
#glossary-item([Sandbox], [An execution environment that isolates code execution and file operations from the host system.])
#glossary-item([Modal], [A sandbox and serverless execution provider that is especially strong for GPU and AI/ML workloads.])
#glossary-item([Daytona], [A sandbox provider well suited to fast devbox provisioning and development-environment workflows.])
#glossary-item([Runloop], [A sandbox provider designed for disposable devboxes and isolated execution.])

== Retrieval, Streaming, and Quality

#glossary-item([RAG], [Short for Retrieval-Augmented Generation, a pattern in which external knowledge is retrieved and injected into the model's response process.])
#glossary-item([Retriever], [A component that searches for and returns documents or chunks relevant to a query.])
#glossary-item([Embedding], [A representation that turns text into vectors in semantic space so similarity search becomes possible.])
#glossary-item([Vector store], [A database or storage layer that saves embeddings and performs similarity search.])
#glossary-item([Chunking], [The process of splitting a long document into smaller units suited for retrieval and context injection.])
#glossary-item([SQL Agent], [An agent that translates natural-language questions into SQL queries and interprets the results.])
#glossary-item([Streaming], [A delivery style in which a model response or execution state is sent incrementally before the run is fully complete.])
#glossary-item([StreamEvent], [An event unit emitted during streaming, such as token output, tool start/end, or a state change.])
#glossary-item([TTFT], [Short for Time to First Token, the time it takes for the model to emit its first token.])
#glossary-item([TTFA], [Short for Time to First Audio, the time it takes for a voice agent to emit its first audio output.])
#glossary-item([Tracing], [An observability technique that records model calls, tool executions, state transitions, and errors so you can inspect the execution flow.])
#glossary-item([Evaluation], [The process of measuring the quality of an agent's output or execution trajectory.])
#glossary-item([LLM-as-Judge], [An evaluation method in which another LLM acts as a scorer for response quality or execution outcomes.])
#glossary-item([Trajectory], [The full path of tool calls, intermediate reasoning, and state changes that leads to the agent's final answer.])
#glossary-item([Guardrail], [A control mechanism that checks safety, policy compliance, or quality at the input, tool, or output stage.])
#glossary-item([PII], [Short for Personally Identifiable Information, sensitive data that can identify a person, such as an email address, phone number, or national ID number.])
