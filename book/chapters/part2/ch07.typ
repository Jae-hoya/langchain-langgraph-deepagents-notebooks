// Auto-generated from 07_hitl_and_runtime.ipynb
// Do not edit manually -- regenerate with nb2typ.py
#import "../../template.typ": *
#import "../../metadata.typ": *

#chapter(7, "사람 개입(HITL)과 런타임")

자율적으로 동작하는 에이전트가 항상 바람직한 것은 아닙니다. 결제 처리, 데이터 삭제, 외부 API 호출 같은 되돌리기 어려운 작업은 실행 전에 사람의 승인이 필요합니다. 이 장에서는 에이전트 실행을 일시 중지하고, 사람의 판단을 받은 후 재개하는 Human-in-the-Loop 패턴과, 런타임에 도구와 프롬프트를 동적으로 제어하는 기법을 다룹니다.

앞 장에서 미들웨어로 에이전트의 파이프라인을 제어하는 방법을 배웠습니다. 이 장은 그 연장선에서, 에이전트의 자율성과 안전성 사이의 균형을 잡는 실전 패턴을 다룹니다. HITL은 "위험한 도구 호출 전에 잠깐 멈추기"라는 단순한 개념이지만, 이를 구현하려면 `interrupt()`로 상태를 저장하고 `Command(resume=value)`로 재개하는 메커니즘이 필요합니다. 체크포인터(`InMemorySaver`)가 이 과정에서 중단된 상태를 보존하는 핵심 역할을 합니다.

#learning-header()
도구 실행 전 사람의 승인을 받고, 런타임 컨텍스트를 주입합니다.

이 노트북에서 다루는 내용:
- _Human-in-the-Loop (HITL)_: 에이전트가 위험한 도구를 실행하기 전에 사람의 승인을 받는 패턴
- _ToolRuntime_: 도구 실행 시 런타임 컨텍스트(사용자 정보 등)를 주입하는 방법
- _컨텍스트 엔지니어링_: 동적으로 프롬프트와 도구를 제어하는 기법
- _MCP (Model Context Protocol)_: 도구 서버를 표준 프로토콜로 연결하는 방식

== 7.1 환경 설정

#code-block(`````python
from dotenv import load_dotenv
import os
load_dotenv(override=True)

from langchain_openai import ChatOpenAI

model = ChatOpenAI(
    model="gpt-4.1",
)

print("모델 준비 완료:", model.model_name)
`````)
#output-block(`````
모델 준비 완료: gpt-4.1
`````)

== 7.2 Human-in-the-Loop 개념

모델이 준비되었으니, HITL의 개념과 필요성부터 이해합니다. 에이전트가 도구를 호출하기 전에 사람의 승인을 요청합니다.

=== 왜 필요한가?

자율적으로 동작하는 에이전트는 강력하지만, 이메일 전송, 파일 삭제, 결제 처리 같은 _되돌릴 수 없는 작업_에서는 사람의 확인이 필수적입니다. 에이전트가 의도와 다른 도구 호출을 시도하는 경우(hallucinated tool call)도 있으므로, 고위험 작업에는 반드시 검증 단계를 두는 것이 좋습니다.

=== 워크플로

#code-block(`````python
에이전트 → 도구 호출 제안 → [중단(interrupt)] → 사람 승인/거부 → 도구 실행 → 결과 반환
`````)

LangChain v1에서는 `HumanInTheLoopMiddleware`와 `InMemorySaver`(체크포인터)를 결합하여 이 패턴을 구현합니다. 체크포인터는 에이전트의 상태를 저장하여 중단 후 재개할 수 있게 합니다.

== 7.3 HumanInTheLoopMiddleware

HITL의 개념을 이해했으니, 실제 구현을 살펴봅니다. `HumanInTheLoopMiddleware`는 도구 호출 시 자동으로 실행을 중단하고, 사람의 승인을 기다리는 미들웨어입니다. `InMemorySaver` 체크포인터와 함께 사용하여 중단된 상태를 보존합니다. 내부적으로 LangGraph의 `interrupt()` 함수를 호출하여 그래프 실행을 일시 정지시킵니다.

#code-block(`````python
from langchain.agents import create_agent
from langchain.tools import tool
from langchain.agents.middleware import HumanInTheLoopMiddleware
from langgraph.checkpoint.memory import InMemorySaver

@tool
def send_email(to: str, subject: str, body: str) -> str:
    """지정된 수신자에게 이메일을 보냅니다."""
    return f"{to}에게 이메일 전송 완료: {subject}"

@tool
def delete_file(path: str) -> str:
    """지정된 경로의 파일을 삭제합니다."""
    return f"파일 삭제 완료: {path}"

# 위험한 도구에만 승인 요구
hitl = HumanInTheLoopMiddleware(interrupt_on={
    "send_email": True,
    "delete_file": True,
})

agent = create_agent(
    model=model,
    tools=[send_email, delete_file],
    system_prompt="당신은 이메일을 보내고 파일을 관리할 수 있는 어시스턴트입니다.",
    middleware=[hitl],
    checkpointer=InMemorySaver(),
)

print("HITL 에이전트 생성 완료")
print("  -> 도구 호출 시 사람의 승인을 위해 중단됩니다")
`````)
#output-block(`````
HITL 에이전트 생성 완료
  -> 도구 호출 시 사람의 승인을 위해 중단됩니다
`````)

== 7.4 interrupt와 Command(resume=...) 패턴

미들웨어로 HITL 에이전트를 만들었으니, 실제로 중단과 재개가 어떻게 동작하는지 살펴봅니다. HITL 에이전트는 2단계로 동작합니다:

+ _1단계 (invoke)_: 에이전트가 도구 호출을 제안하면 자동으로 _중단(interrupt)_됩니다. 이때 `interrupt()` 함수가 호출되며, 체크포인터가 현재 그래프 상태를 저장합니다.
+ _2단계 (Command(resume=True))_: 사람이 승인하면 `Command(resume=True)`로 실행을 _재개_합니다. 체크포인터에서 저장된 상태를 복원하고, 중단된 지점부터 실행을 이어갑니다.

거부할 경우 `Command(resume=False)`를 사용하거나, `Command(resume="다른 작업을 해주세요")`처럼 문자열을 전달하여 에이전트에게 새로운 지시를 줄 수도 있습니다.

#warning-box[HITL 패턴은 반드시 체크포인터와 함께 사용해야 합니다. 체크포인터 없이 `interrupt()`를 호출하면, 중단된 상태를 복원할 수 없어 재개가 불가능합니다.]

== 7.5 ToolRuntime -- 도구에서 런타임 정보에 접근합니다

HITL로 안전성을 확보했다면, 이제 도구가 _실행 환경의 정보_에 접근하는 방법을 다룹니다. 4장에서 `ToolRuntime`을 간단히 소개했는데, 여기서는 `context_schema`를 활용한 본격적인 사용법을 살펴봅니다.

`ToolRuntime`은 도구가 실행될 때 런타임 컨텍스트(현재 사용자 정보, 세션 데이터, DB 커넥션 등)에 접근할 수 있게 해주는 메커니즘입니다. 중요한 점은, `ToolRuntime` 매개변수는 LLM에게 _노출되지 않는다_는 것입니다. 모델은 이 매개변수의 존재를 모르며, 값을 생성하지도 않습니다. 런타임이 자동으로 주입합니다.

=== 핵심 아이디어
- 도구 함수에 `runtime: ToolRuntime[T]` 파라미터를 추가합니다.
- `T`는 개발자가 정의하는 컨텍스트 데이터 클래스입니다. (예: 사용자 ID, 권한 레벨, DB 커넥션)
- 에이전트 생성 시 `context_schema=T`를 지정하고, 호출 시 `context=T(...)`로 값을 전달합니다.

== 7.6 컨텍스트 엔지니어링 -- 동적으로 프롬프트와 도구를 제어합니다

`ToolRuntime`으로 도구에 런타임 정보를 주입하는 방법을 배웠으니, 한 단계 더 나아가 에이전트의 _전체 컨텍스트_를 동적으로 제어하는 기법을 살펴봅니다.

컨텍스트 엔지니어링은 에이전트에게 전달되는 _프롬프트_, _도구_, _메시지 히스토리_를 동적으로 조작하는 기법입니다. 6장에서 배운 `@dynamic_prompt`가 프롬프트를 런타임에 변경한다면, `@dynamic_tools`는 사용 가능한 _도구 목록 자체_를 런타임에 필터링합니다.

=== 주요 활용 사례
- 사용자 역할에 따라 다른 시스템 프롬프트 제공 (`@dynamic_prompt`)
- 상황이나 권한에 따라 사용 가능한 도구 필터링 (`@dynamic_tools`)
- 긴 대화 히스토리 요약 및 정리 (`SummarizationMiddleware`)

`dynamic_prompt` 미들웨어를 사용하면 매 요청마다 프롬프트를 커스터마이즈할 수 있습니다. `@dynamic_tools`는 런타임 컨텍스트(예: 사용자 권한)에 따라 에이전트가 접근할 수 있는 도구를 동적으로 결정합니다. 예를 들어, 관리자에게만 `delete_file` 도구를 제공하고 일반 사용자에게는 읽기 전용 도구만 제공하는 식입니다.

== 7.7 MCP (Model Context Protocol) 연동 개요

지금까지는 Python 함수로 직접 도구를 정의했습니다. 하지만 도구가 다른 언어로 작성되어 있거나, 별도의 서버에서 실행되어야 하는 경우가 있습니다. MCP는 이런 상황을 위한 _표준화된 도구 프로토콜_입니다.

_MCP_는 도구 서버를 표준 프로토콜로 연결하는 방식입니다.

=== MCP의 핵심 개념
- _MCP 서버_: 도구(Tool)를 제공하는 서버. _stdio_(로컬 프로세스 간 통신) 또는 _SSE_(HTTP 기반 스트리밍) 두 가지 전송 방식을 지원합니다.
- _MCP 클라이언트_: 에이전트가 MCP 서버에 연결하여 도구를 _자동으로 발견(discover)_하고 호출합니다.
- _표준화_: 어떤 언어/프레임워크로 만든 도구든 MCP 프로토콜을 따르면 연결 가능합니다. Python, TypeScript, Go 등으로 작성된 도구를 동일한 방식으로 사용할 수 있습니다.

=== LangChain v1에서의 MCP 지원
- `langchain-mcp-adapters` 패키지의 `load_mcp_tools()`로 MCP 서버의 도구를 자동으로 로드할 수 있습니다.
- 로드된 도구는 일반 LangChain 도구와 _완전히 동일한 인터페이스_를 가지므로, `create_agent()`의 `tools` 매개변수에 그대로 전달할 수 있습니다.

#tip-box[MCP 생태계에는 이미 파일 시스템, 데이터베이스, GitHub, Slack 등 수백 개의 사전 구축된 서버가 있습니다. 직접 도구를 구현하기 전에 기존 MCP 서버가 있는지 확인해 보세요.]

#code-block(`````python
# MCP 연동 개념 (실행하려면 MCP 서버가 필요합니다)
print("MCP (Model Context Protocol) 연동:")
print("=" * 50)
print("""
# MCP 서버를 도구로 연결하는 예시:

from langchain_mcp_adapters.tools import load_mcp_tools

# MCP 서버에서 도구 로드
tools = load_mcp_tools("http://localhost:8080/mcp")

# 에이전트에 MCP 도구 연결
agent = create_agent(
    model=model,
    tools=tools,
    system_prompt="MCP 도구를 사용할 수 있습니다.",
)
""")
print("-> MCP는 표준화된 도구 탐색 및 호출을 가능하게 합니다.")
`````)
#output-block(`````
MCP (Model Context Protocol) 연동:
==================================================

# MCP 서버를 도구로 연결하는 예시:

from langchain_mcp_adapters.tools import load_mcp_tools

# MCP 서버에서 도구 로드
tools = load_mcp_tools("http://localhost:8080/mcp")

# 에이전트에 MCP 도구 연결
agent = create_agent(
    model=model,
    tools=tools,
    system_prompt="MCP 도구를 사용할 수 있습니다.",
)

-> MCP는 표준화된 도구 탐색 및 호출을 가능하게 합니다.
`````)

#chapter-summary-header()

이 노트북에서 학습한 핵심 내용:

#table(
  columns: 3,
  align: left,
  stroke: 0.5pt + luma(200),
  inset: 8pt,
  fill: (_, row) => if row == 0 { rgb("#E0F2F3") } else if calc.odd(row) { luma(248) } else { white },
  text(weight: "bold")[개념],
  text(weight: "bold")[설명],
  text(weight: "bold")[핵심 API],
  [_HITL_],
  [도구 실행 전 사람의 승인 요청],
  [`HumanInTheLoopMiddleware`, `Command(resume=...)`],
  [_ToolRuntime_],
  [도구에서 런타임 컨텍스트 접근],
  [`ToolRuntime[T]`, `context_schema`],
  [_컨텍스트 엔지니어링_],
  [동적 프롬프트/도구 제어],
  [`dynamic_prompt` 미들웨어],
  [_MCP_],
  [표준화된 도구 프로토콜],
  [`load_mcp_tools() (langchain-mcp-adapters 패키지)`],
)

이 장으로 Part 2(LangChain)의 핵심 개념을 모두 다뤘습니다. 에이전트 생성(`create_agent`), 모델과 메시지, 도구와 구조화된 출력, 메모리와 스트리밍, 미들웨어와 가드레일, 그리고 HITL과 런타임 제어까지 --- 이 기반 위에 다음 Part에서는 LangGraph를 사용하여 _멀티 에이전트 워크플로_와 복잡한 상태 기계를 구축합니다.

