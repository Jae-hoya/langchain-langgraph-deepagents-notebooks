// Auto-generated from 06_sql_agent.ipynb
// Do not edit manually -- regenerate with nb2typ.py
#import "../../template.typ": *
#import "../../metadata.typ": *

#chapter(6, "SQL Agent Advanced", subtitle: "- LangChain & LangGraph")

We build agents that convert natural language into SQL queries in two ways: LangChain `create_agent` + `SQLDatabaseToolkit` (simple version) and LangGraph `StateGraph` (custom version). Covers Human-in-the-Loop, `interrupt()`, and `Command(resume=...)` patterns.

== Learning Objectives

- Understand the 8-step workflow of SQL Agent
- Utilizes 4 tool of `SQLDatabase` and `SQLDatabaseToolkit`
- Implement ReAct-based SQL Agent with LangChain `create_agent`
- Add approval before query execution with `HumanInTheLoopMiddleware`
- Build a custom SQL Agent with LangGraph `StateGraph`
- Force tool calling with `bind_tools` and `tool_choice`
- Implement query review with `interrupt()` and `Command(resume=...)`

== 6.1 Environment Setup (SQLite + Chinook DB)

#code-block(`````python
# %pip install langchain langchain-openai langchain-community langgraph sqlalchemy python-dotenv

from dotenv import load_dotenv
load_dotenv(override=True)

from langchain_openai import ChatOpenAI
from langchain_community.utilities import SQLDatabase

llm = ChatOpenAI(model="gpt-4.1")
db = SQLDatabase.from_uri("sqlite:///Chinook.db")
print(f"Dialect: {db.dialect}")
`````)

== 6.2 SQL Agent Overview

SQL Agent follows an _8-step_ process to convert natural language questions into SQL queries:

#code-block(`````python
1. 질문 수신 -> 2. 테이블 목록 -> 3. 관련 테이블 스키마
-> 4. SQL 쿼리 생성 -> 5. 쿼리 검증 -> 6. (선택) 사람 리뷰
-> 7. 쿼리 실행 -> 8. 결과 해석
`````)

=== 왜 에이전트가 필요한가?

단순 text-to-SQL과 달리 에이전트 방식은 _스키마 탐색 → 쿼리 생성 → 검증 → 실행_의 반복 루프를 수행합니다. 잘못된 쿼리가 생성되면 에이전트가 오류를 분석하고 쿼리를 재작성할 수 있어 정확도가 크게 향상됩니다. 또한 에이전트는 필요한 테이블의 스키마만 선택적으로 로드하므로 _컨텍스트 윈도우를 효율적으로_ 사용합니다.

=== 에이전트 실행 트레이스 예시

#code-block(`````python
User: "지난달 매출 상위 5개 제품은?"

Agent -> sql_db_list_tables()
      <- "customers, orders, order_items, products, categories"

Agent -> sql_db_schema("orders, order_items, products")
      <- CREATE TABLE orders (id INT, order_date DATE, ...)
         CREATE TABLE order_items (order_id INT, product_id INT, quantity INT, price DECIMAL, ...)

Agent -> sql_db_query_checker("SELECT p.name, SUM(oi.quantity * oi.price) ...")
      <- "The query looks correct."

Agent -> sql_db_query(validated_query)
      <- [("Widget Pro", 45230.00), ("Gadget X", 38100.00), ...]
`````)

=== 안전 수칙

#table(
  columns: 2,
  align: left,
  stroke: 0.5pt + luma(200),
  inset: 8pt,
  fill: (_, row) => if row == 0 { rgb("#E0F2F3") } else if calc.odd(row) { luma(248) } else { white },
  text(weight: "bold")[우려사항],
  text(weight: "bold")[대응],
  [SQL Injection],
  [파라미터화된 쿼리 사용, Toolkit이 자동 처리],
  [DML 실행],
  [시스템 프롬프트에서 INSERT/UPDATE/DELETE 금지, DB 레벨 읽기 전용 권한 설정],
  [비용 높은 쿼리],
  [LIMIT 강제, Human-in-the-Loop으로 실행 전 승인],
  [민감 데이터],
  [`include_tables`/`exclude_tables`로 접근 가능 테이블 제한, 컬럼 레벨 권한 설정],
  [데이터 노출],
  [데이터베이스 뷰(view) 또는 제한된 사용자 권한 활용],
)

=== 접근 가능 테이블 제한

프로덕션에서는 에이전트가 접근할 수 있는 테이블을 명시적으로 제한하는 것이 좋습니다:

#code-block(`````python
db = SQLDatabase.from_uri(
    "sqlite:///company.db",
    include_tables=["products", "orders", "order_items"],  # 허용 목록
    # exclude_tables=["users", "credentials"],             # 또는 차단 목록
)
`````)

== 6.3 SQLDatabaseToolkit

Automatically generates 4 tool:

#table(
  columns: 2,
  align: left,
  stroke: 0.5pt + luma(200),
  inset: 8pt,
  fill: (_, row) => if row == 0 { rgb("#E0F2F3") } else if calc.odd(row) { luma(248) } else { white },
  text(weight: "bold")[tool],
  text(weight: "bold")[Features],
  [`sql_db_list_tables`],
  [Return all table names in database],
  [`sql_db_schema`],
  [CREATE TABLE statement + return sample rows],
  [`sql_db_query`],
  [Execute a SQL query and return results],
  [`sql_db_query_checker`],
  [LLM pre-checks queries for errors],
)

#code-block(`````python
from langchain_community.agent_toolkits import SQLDatabaseToolkit

toolkit = SQLDatabaseToolkit(db=db, llm=llm)
tools = toolkit.get_tools()

for t in tools:
    print(f"  {t.name}: {t.description[:60]}...")
print(f"총 도구 수: {len(tools)}")
`````)

== 6.4 LangChain SQL Agent -- `create_agent` + ReAct

`create_agent` is LangChain's high-level API, which takes a model and tool and automatically constructs a _ReAct(Reasoning + Acting) loop_. The agent calls tool in order, following the workflow defined in the system prompt.

=== How ReAct loop works

+ LLM analyzes user questions and conversation history to determine _T16___ to call next
+ tool is executed and the results are added to the conversation history
+ LLM will check the results and return to step 1 if additional tool calling is needed
+ Return a text response when the final answer is ready

=== What the system prompt does

System prompts define the agent's instructions for action. In SQL Agent, you must specifically specify the following:
- _tool calling order_: Force order `list_tables` → `schema` → `query_checker` → `query`
- _Safety rules_: Use `LIMIT`, no DML, query only necessary columns
- _Error handling_: Directs rewriting when a query error occurs.
- _SQL dialect_: Specify the dialect of the current DB (SQLite, PostgreSQL, etc.)

#code-block(`````python
system_prompt = (
    "당신은 SQL 에이전트입니다. 단계:\n"
    "1. sql_db_list_tables\n2. sql_db_schema\n"
    "3. 쿼리 작성 + sql_db_query_checker\n"
    "4. sql_db_query\n5. 결과를 해석하세요.\n"
    f"규칙: LIMIT 10 사용. DML 금지. Dialect: {db.dialect}"
)
`````)

#code-block(`````python
from langchain.agents import create_agent

sql_agent = create_agent(
    model=llm, tools=tools, system_prompt=system_prompt,
)
print("LangChain SQL Agent created.")
`````)

== 6.5 Run test

== 6.6 HITL -- `HumanInTheLoopMiddleware`

In a production environment, human approval is required before executing SQL queries. This is because agent-generated queries can be expensive, access unexpected tables, or return results that are different from what you intended.

`HumanInTheLoopMiddleware` intercepts the specified tool(`sql_db_query`) call and suspends execution, allowing human review.

=== 3 review options

When an agent attempts to call `sql_db_query`, execution is suspended and the human chooses one of the following:

#table(
  columns: 3,
  align: left,
  stroke: 0.5pt + luma(200),
  inset: 8pt,
  fill: (_, row) => if row == 0 { rgb("#E0F2F3") } else if calc.odd(row) { luma(248) } else { white },
  text(weight: "bold")[Options],
  text(weight: "bold")[`Command(resume=...)` value],
  text(weight: "bold")[Description],
  [_Approved_],
  [`"approve"`],
  [Execute the generated query as is],
  [_Edit_],
  [`{"type": "edit", "args": {"query": "..."}}`],
  [After modifying the query, run],
  [_Reject_],
  [`{"type": "reject", "reason": "..."}`],
  [Passing reason without executing query],
)

=== Why is HITL important?

- _Cost Control_: Avoid large table full scans without `LIMIT`.
- _Data Protection_: Pre-block access to sensitive columns
- _Accuracy Verification_: If the agent misinterpreted the intention of the question, correction is possible.
- _Audit Trail_: Maintains approval records for all executed queries

#code-block(`````python
from langchain.agents.middleware import HumanInTheLoopMiddleware

hitl = HumanInTheLoopMiddleware(
    interrupt_on={"sql_db_query": True},
)
sql_agent_hitl = create_agent(
    model=llm, tools=tools,
    system_prompt=system_prompt, middleware=[hitl],
)
print("Created SQL Agent with HITL applied.")
`````)

== 6.7 LangGraph Custom SQL Agent -- StateGraph

LangChain `create_agent` can be used for quick prototyping, but if you need _fine-grained control at the node level_, use LangGraph `StateGraph`. By defining each step as an independent node, we can achieve:

- _Conditional Branch_: Route to regeneration node when query validation fails.
- _Force tool calling_: With `bind_tools(tool_choice=...)`, a specific tool calling must be installed on a specific node.
- _Fine-grained breakpoints_: Break execution exactly on the desired node with `interrupt()`
- _Custom Status_: Add query history, retry count, etc. to the status.

=== Graph structure

#code-block(`````python
START -> list_tables -> get_schema -> generate_query
      -> check_query -> execute_query -> END
`````)

각 노드는 공유 `State` 객체를 받아 메시지를 추가하며, 에이전트가 워크플로우를 진행하는 동안 대화 이력이 누적됩니다. `tools_condition`을 사용하면 `check_query` 결과에 따라 쿼리를 재생성하거나 실행으로 진행하는 조건부 분기를 구현할 수 있습니다.

=== LangChain `create_agent` 대비 장점

#table(
  columns: 3,
  align: left,
  stroke: 0.5pt + luma(200),
  inset: 8pt,
  fill: (_, row) => if row == 0 { rgb("#E0F2F3") } else if calc.odd(row) { luma(248) } else { white },
  text(weight: "bold")[측면],
  text(weight: "bold")[`create_agent`],
  text(weight: "bold")[`StateGraph`],
  [__T12__ 순서],
  [LLM 자율 결정],
  [그래프 엣지로 강제],
  [오류 시 재시도],
  [시스템 프롬프트에 의존],
  [조건부 엣지로 명시적 구현],
  [사람 리뷰],
  [미들웨어 기반],
  [`interrupt()` based, position free],
  [Debugging],
  [Black box],
  [Status of each node can be checked],
)

#code-block(`````python
from typing import Annotated
from typing_extensions import TypedDict
from langgraph.graph.message import add_messages

class SQLState(TypedDict):
    messages: Annotated[list, add_messages]

print(f"SQLState 키: {list(SQLState.__annotations__)}")
`````)

== 6.8 Dedicated nodes -- `list_tables`, `get_schema`, `generate_query`, `check_query`

Each node is responsible for one step of the SQL Agent workflow.

== 6.9 `bind_tools` with `tool_choice` -- Force tool calling

Set _Force_ a call to a specific tool with the `tool_choice` parameter.

== 6.10 Reviewing queries with `interrupt()`

LangGraph's `interrupt()` function _suspenses_ graph execution and waits for external input (a human review). Unlike `HumanInTheLoopMiddleware`, `interrupt()` is more flexible as it allows you to break at _an exact location in the code inside the node_.

=== How it works

+ Calling `interrupt(payload)` inside a node function will immediately halt graph execution
+ `payload` is passed to the client and displayed in the review UI (i.e. the generated SQL query)
+ When the client resumes the graph with `Command(resume=value)`, `interrupt()` returns `value`
+ The node function executes, modifies, or rejects the query based on the returned values.

=== `interrupt()` vs `HumanInTheLoopMiddleware`

#table(
  columns: 3,
  align: left,
  stroke: 0.5pt + luma(200),
  inset: 8pt,
  fill: (_, row) => if row == 0 { rgb("#E0F2F3") } else if calc.odd(row) { luma(248) } else { white },
  text(weight: "bold")[Characteristics],
  text(weight: "bold")[`interrupt()`],
  text(weight: "bold")[`HumanInTheLoopMiddleware`],
  [Scope of application],
  [Code level within node],
  [tool calling Level],
  [Flexibility],
  [Arbitrary logic can be implemented],
  [tool calling Interception only],
  [state access],
  [Entire State accessible],
  [Only tool arguments are accessible],
  [checkpointer],
  [Required (stateful required)],
  [optional],
)

== 6.11 `Command(resume=...)` pattern

To resume a graph stopped by `interrupt()`, use `Command(resume=...)`.

#code-block(`````python
from langgraph.graph import StateGraph, START, END
from langgraph.checkpoint.memory import InMemorySaver

builder = StateGraph(SQLState)
builder.add_node("list_tables", list_tables_node)
builder.add_node("get_schema", get_schema_node)
builder.add_node("generate_query", generate_query_node)
builder.add_node("check_query", check_query_node)
builder.add_node("execute_query", execute_query_node)
`````)

#code-block(`````python
builder.add_edge(START, "list_tables")
builder.add_edge("list_tables", "get_schema")
builder.add_edge("get_schema", "generate_query")
builder.add_edge("generate_query", "check_query")
builder.add_edge("check_query", "execute_query")
builder.add_edge("execute_query", END)

checkpointer = InMemorySaver()
sql_graph = builder.compile(checkpointer=checkpointer)
print("LangGraph SQL Agent compiled.")
`````)

== Summary

=== Comparison of two SQL Agents

#table(
  columns: 3,
  align: left,
  stroke: 0.5pt + luma(200),
  inset: 8pt,
  fill: (_, row) => if row == 0 { rgb("#E0F2F3") } else if calc.odd(row) { luma(248) } else { white },
  text(weight: "bold")[Characteristics],
  text(weight: "bold")[LangChain `create_agent`],
  text(weight: "bold")[LangGraph `StateGraph`],
  [Implementation Complexity],
  [Low (5 lines)],
  [High (dedicated node)],
  [control level],
  [ReAct Automatic],
  [Node-level customization],
  [HITL],
  [`HumanInTheLoopMiddleware`],
  [`interrupt()` + `Command(resume=...)`],
  [forced tool calling],
  [Not supported],
  [`bind_tools(tool_choice=...)`],
  [Suitable for],
  [Rapid Prototype],
  [Production, granular control],
)

=== HITL pattern

#table(
  columns: 2,
  align: left,
  stroke: 0.5pt + luma(200),
  inset: 8pt,
  fill: (_, row) => if row == 0 { rgb("#E0F2F3") } else if calc.odd(row) { luma(248) } else { white },
  text(weight: "bold")[action],
  text(weight: "bold")[`Command(resume=...)`],
  [Accept],
  [`{"action": "accept"}`],
  [Edit],
  [`{"action": "edit", "edited_query": "..."}`],
  [Reject],
  [`{"action": "reject", "reason": "..."}`],
)

=== 4 SQLDatabaseToolkits tool

#table(
  columns: 3,
  align: left,
  stroke: 0.5pt + luma(200),
  inset: 8pt,
  fill: (_, row) => if row == 0 { rgb("#E0F2F3") } else if calc.odd(row) { luma(248) } else { white },
  text(weight: "bold")[tool],
  text(weight: "bold")[steps],
  text(weight: "bold")[Use],
  [`sql_db_list_tables`],
  [2],
  [Check table list],
  [`sql_db_schema`],
  [3],
  [DDL + sample data query],
  [`sql_db_query_checker`],
  [5],
  [Query pre-validation],
  [`sql_db_query`],
  [7],
  [Run query],
)

=== Next Steps
→ _#link("./07_data_analysis.ipynb")[07_data_analysis.ipynb]_: Creates a data analysis agent.
