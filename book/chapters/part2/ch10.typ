// Auto-generated from 10_production.ipynb
// Do not edit manually -- regenerate with nb2typ.py
#import "../../template.typ": *
#import "../../metadata.typ": *

#chapter(10, "프로덕션")

에이전트를 개발하는 것과 프로덕션에 배포하는 것은 완전히 다른 문제입니다. 비결정적인 LLM의 동작을 테스트하고, 웹 서비스로 배포하고, 실행을 모니터링하고, 비용을 관리해야 합니다. 이 장에서는 LangSmith Studio를 사용한 로컬 개발부터, 결정론적 테스트, Agent Chat UI, LangGraph Platform 배포까지 에이전트의 전체 프로덕션 라이프사이클을 다룹니다.

전통적인 소프트웨어는 같은 입력에 항상 같은 출력을 반환하므로 단위 테스트로 충분히 검증할 수 있습니다. 그러나 에이전트는 LLM의 비결정적 특성과 도구 호출의 부수 효과가 결합되어, "어떤 도구를 어떤 순서로 호출했는가"를 검증하는 _트라젝토리 테스트_와, 실시간으로 에이전트 동작을 추적하는 _관측성(Observability)_ 인프라가 필수적입니다.

#learning-header()
에이전트를 테스트, 배포, 모니터링하는 방법을 알아봅니다.

이 노트북에서 다루는 내용:
- LangSmith Studio를 사용한 로컬 개발 및 디버깅
- `GenericFakeChatModel`로 결정론적 에이전트 테스트
- 트라젝토리 기반 테스트로 도구 호출 순서 검증
- Agent Chat UI로 웹 기반 대화
- LangGraph Platform 및 자체 서버 배포
- LangSmith를 활용한 관측성(Observability)

== 10.1 환경 설정

#code-block(`````python
from dotenv import load_dotenv
import os
load_dotenv(override=True)

from langchain_openai import ChatOpenAI

model = ChatOpenAI(
    model="gpt-4.1",
)

from langchain.agents import create_agent
from langchain.tools import tool

print("환경 준비 완료.")
`````)
#output-block(`````
환경 준비 완료.
`````)

== 10.2 LangSmith Studio

로컬에서 에이전트를 개발하고 디버깅합니다.

LangSmith Studio는 에이전트의 실행 과정을 _트레이스(trace)_ 단위로 시각화하는 개발 도구입니다. 각 트레이스는 모델 호출, 도구 실행, 노드 전환 등의 단계를 트리 구조로 보여주며, 각 단계의 입력/출력 데이터, 소요 시간, 토큰 사용량을 한눈에 확인할 수 있습니다. `langgraph dev` 명령어로 로컬 개발 서버를 실행하면 별도의 배포 없이도 Studio UI에서 에이전트를 인터랙티브하게 테스트할 수 있습니다.

Studio를 사용하려면 다음이 필요합니다:
- `langgraph.json` 설정 파일
- `langgraph dev` 명령어로 로컬 서버 실행
- Studio UI에서 에이전트를 인터랙티브하게 테스트

#code-block(`````python
# langgraph.json 설정 예시
import json

langgraph_config = {
    "dependencies": ["."],
    "graphs": {
        "agent": "./agent.py:agent"
    },
    "env": ".env"
}

print("langgraph.json 설정 예시:")
print(json.dumps(langgraph_config, indent=2))
print("\n실행 방법:")
print("  $ langgraph dev")
print("  → http://localhost:2024 에서 Studio UI 접근")
`````)
#output-block(`````
langgraph.json 설정 예시:
{
  "dependencies": [
    "."
  ],
  "graphs": {
    "agent": "./agent.py:agent"
  },
  "env": ".env"
}

실행 방법:
  $ langgraph dev
  → http://localhost:2024 에서 Studio UI 접근
`````)

Studio에서 인터랙티브하게 동작을 확인했다면, 다음 단계는 자동화된 테스트를 작성하여 에이전트의 동작을 _반복 가능한_ 방식으로 검증하는 것입니다.

== 10.3 에이전트 테스트

`GenericFakeChatModel`을 사용하면 실제 API 호출 없이 결정론적으로 에이전트를 테스트할 수 있습니다. 이 가짜 모델은 미리 정의된 응답 시퀀스를 순서대로 반환하므로, LLM의 비결정적 동작을 제거하고 에이전트의 _로직_(도구 선택, 분기, 종료 조건 등)만을 독립적으로 검증할 수 있습니다.

이 방법의 장점:
- API 비용 없이 테스트 가능
- 항상 동일한 결과를 반환하므로 CI/CD 파이프라인에 적합
- 에이전트의 로직(도구 호출, 분기 등)을 독립적으로 검증

#tip-box[`GenericFakeChatModel`에 tool call이 포함된 `AIMessage`를 응답으로 설정하면, 에이전트가 특정 도구를 호출하는 시나리오도 결정론적으로 테스트할 수 있습니다. 이를 통해 "모델이 올바른 도구를 선택했는가"가 아닌 "도구 호출 후 에이전트가 올바르게 동작하는가"를 검증합니다.]

#code-block(`````python
from langchain_core.language_models import GenericFakeChatModel
from langchain.messages import AIMessage
from langchain.agents import create_agent
from langchain.tools import tool

@tool
def get_capital(country: str) -> str:
    """국가의 수도를 반환합니다."""
    capitals = {"Korea": "Seoul", "Japan": "Tokyo", "France": "Paris"}
    return capitals.get(country, "알 수 없음")

# 가짜 모델로 결정론적 테스트
fake_model = GenericFakeChatModel(
    messages=iter([
        AIMessage(content="대한민국의 수도는 서울입니다.")
    ])
)

# 테스트 에이전트
test_agent = create_agent(
    model=fake_model,
    tools=[get_capital],
    system_prompt="당신은 지리 전문가입니다.",
)

print("GenericFakeChatModel 테스트:")
print("  → 결정론적 응답으로 에이전트 동작을 테스트합니다")
print("  → CI/CD 파이프라인에서 API 호출 없이 테스트 가능")
`````)
#output-block(`````
GenericFakeChatModel 테스트:
  → 결정론적 응답으로 에이전트 동작을 테스트합니다
  → CI/CD 파이프라인에서 API 호출 없이 테스트 가능
`````)

== 10.4 트라젝토리 기반 테스트

에이전트의 도구 호출 순서를 검증합니다. 트라젝토리 테스트는 에이전트의 최종 출력만 검증하는 것이 아니라, _중간 과정_ — 어떤 도구를 어떤 순서로 호출했는지, 각 도구에 어떤 인자를 전달했는지 — 을 검사합니다. 이 접근법이 중요한 이유는 에이전트가 올바른 최종 답변을 내놓더라도 불필요한 도구 호출이나 위험한 작업을 수행했을 수 있기 때문입니다.

#code-block(`````python
# 트라젝토리 테스트 예시
def test_agent_trajectory():
    """에이전트가 예상된 순서로 도구를 호출하는지 테스트합니다."""
    result = test_agent.invoke(
        {"messages": [{"role": "user", "content": "대한민국의 수도는 어디인가요?"}]}
    )
    
    messages = result["messages"]
    
    # 검증: 메시지가 존재하는지
    assert len(messages) > 0, "에이전트가 응답하지 않았습니다"
    
    # 검증: 마지막 메시지가 AI 응답인지
    last_msg = messages[-1]
    assert hasattr(last_msg, 'content'), "마지막 메시지에 content가 없습니다"
    
    print("✓ 트라젝토리 테스트 통과")
    print(f"  메시지 수: {len(messages)}")
    print(f"  최종 응답: {last_msg.content[:100]}")

try:
    test_agent_trajectory()
except Exception as e:
    print(f"테스트 참고: {e}")
`````)
#output-block(`````
테스트 참고:
`````)

자동화된 테스트로 에이전트의 로직을 검증했다면, 실제 사용자의 관점에서 에이전트를 테스트해 볼 차례입니다. Agent Chat UI는 코드를 작성하지 않고도 브라우저에서 에이전트와 대화할 수 있는 인터페이스를 제공합니다.

== 10.5 Agent Chat UI

에이전트와 대화할 수 있는 웹 UI입니다. LangGraph 서버와 연결하여 브라우저에서 직접 에이전트를 테스트할 수 있습니다. `npx @anthropic-ai/agent-chat-ui` 명령어 하나로 설치 없이 바로 실행할 수 있으며, 로컬에서 실행 중인 LangGraph 서버(`http://localhost:2024`)에 자동으로 연결됩니다.

주요 기능:
- 실시간 스트리밍 채팅
- 도구 호출 시각화
- 대화 분기(branching)
- Human-in-the-loop 승인

#code-block(`````python
print("Agent Chat UI 설정:")
print("=" * 50)
print("""
# 1. Agent Chat UI 설치
$ npx @anthropic-ai/agent-chat-ui

# 2. LangGraph 서버 시작
$ langgraph dev

# 3. UI에서 http://localhost:2024 연결
#    → 웹 브라우저에서 에이전트와 대화
""")
print("주요 기능:")
print("  - 실시간 스트리밍 채팅")
print("  - 도구 호출 시각화")
print("  - 대화 분기(branching)")
print("  - Human-in-the-loop 승인")
`````)
#output-block(`````
Agent Chat UI 설정:
==================================================

# 1. Agent Chat UI 설치
$ npx @anthropic-ai/agent-chat-ui

# 2. LangGraph 서버 시작
$ langgraph dev

# 3. UI에서 http://localhost:2024 연결
#    → 웹 브라우저에서 에이전트와 대화

주요 기능:
  - 실시간 스트리밍 채팅
  - 도구 호출 시각화
  - 대화 분기(branching)
  - Human-in-the-loop 승인
`````)

테스트를 마쳤다면 에이전트를 프로덕션 환경에 배포할 차례입니다. LangGraph는 관리형 플랫폼부터 셀프 호스팅까지 다양한 배포 옵션을 제공합니다.

== 10.6 배포

LangGraph Platform(관리형) 또는 자체 서버로 에이전트를 배포할 수 있습니다. LangGraph Platform은 인프라 관리 없이 에이전트를 배포하고 스케일링할 수 있는 관리형 서비스이며, 셀프 호스팅은 `langgraph-api` Docker 이미지를 사용하여 자체 인프라에 배포하는 방식입니다. 프로덕션 환경에 맞는 옵션을 선택하세요.

#warning-box[FastAPI로 에이전트를 직접 래핑하는 경우, 스트리밍 응답(`StreamingResponse`), 체크포인팅, 스레드 관리 등을 직접 구현해야 합니다. LangGraph Platform이나 `langgraph-api` Docker 이미지를 사용하면 이러한 기능이 기본으로 제공됩니다.]

#code-block(`````python
print("배포 옵션:")
print("=" * 50)

print("""
# 옵션 1: LangGraph Platform (관리형)
$ langgraph deploy


# 옵션 2: 자체 Docker 배포
$ langgraph build -t my-agent
$ docker run -p 2024:2024 my-agent


# 옵션 3: FastAPI/Flask 래핑
from fastapi import FastAPI

app = FastAPI()


@app.post("/chat")
async def chat(message: str):
    result = agent.invoke(
        {
            "messages": [
                {
                    "role": "user",
                    "content": message
                }
            ]
        }
    )

    return {
        "response": result["messages"][-1].content
    }
""")
`````)
#output-block(`````
배포 옵션:
==================================================

# 옵션 1: LangGraph Platform (관리형)
$ langgraph deploy


# 옵션 2: 자체 Docker 배포
$ langgraph build -t my-agent
$ docker run -p 2024:2024 my-agent


# 옵션 3: FastAPI/Flask 래핑
from fastapi import FastAPI

app = FastAPI()


@app.post("/chat")
async def chat(message: str):
    result = agent.invoke(
        {
            "messages": [
                {
                    "role": "user",
                    "content": message
                }
            ]
        }
    )
... (truncated)
`````)

== 10.7 관측성

에이전트가 프로덕션에 배포되면 실시간 모니터링이 핵심이 됩니다. LangSmith로 에이전트 동작을 추적합니다. 트레이싱을 활성화하려면 환경 변수 `LANGSMITH_TRACING=true`를 설정하기만 하면 됩니다. 별도의 코드 변경 없이 에이전트의 모든 실행 단계가 자동으로 LangSmith에 기록됩니다.

LangSmith에서 확인할 수 있는 정보:
- 각 에이전트 호출의 전체 실행 흐름
- 모델 입/출력, 도구 호출, 토큰 사용량
- 지연 시간, 에러, 비용 추적

#tip-box[LangSmith의 트레이스를 프로젝트별로 분리하려면 `LANGSMITH_PROJECT` 환경 변수를 설정하세요. 예를 들어 개발/스테이징/프로덕션 환경별로 다른 프로젝트 이름을 사용하면 트레이스를 환경별로 구분하여 분석할 수 있습니다.]

== 10.8 프로덕션 체크리스트

에이전트를 프로덕션에 배포하기 전에 아래 항목을 확인하세요.

#table(
  columns: 3,
  align: left,
  stroke: 0.5pt + luma(200),
  inset: 8pt,
  fill: (_, row) => if row == 0 { rgb("#E0F2F3") } else if calc.odd(row) { luma(248) } else { white },
  text(weight: "bold")[항목],
  text(weight: "bold")[도구],
  text(weight: "bold")[상태],
  [단위 테스트],
  [`GenericFakeChatModel`, `pytest`],
  [],
  [트라젝토리 테스트],
  [커스텀 검증 함수],
  [],
  [관측성 설정],
  [LangSmith 트레이싱],
  [],
  [에러 처리],
  [`try/except`, 재시도 로직],
  [],
  [보안],
  [API 키 관리, 입력 검증, 가드레일],
  [],
  [배포 환경],
  [Docker, LangGraph Platform],
  [],
  [모니터링],
  [LangSmith 대시보드, 알림 설정],
  [],
  [문서화],
  [API 문서, 에이전트 동작 설명],
  [],
)

#chapter-summary-header()

이 노트북에서 배운 내용:

#table(
  columns: 2,
  align: left,
  stroke: 0.5pt + luma(200),
  inset: 8pt,
  fill: (_, row) => if row == 0 { rgb("#E0F2F3") } else if calc.odd(row) { luma(248) } else { white },
  text(weight: "bold")[주제],
  text(weight: "bold")[핵심 내용],
  [_LangSmith Studio_],
  [`langgraph dev`로 로컬에서 에이전트를 시각적으로 디버깅합니다],
  [_에이전트 테스트_],
  [`GenericFakeChatModel`로 API 호출 없이 결정론적 테스트를 수행합니다],
  [_트라젝토리 테스트_],
  [도구 호출 순서와 최종 응답을 검증합니다],
  [_Agent Chat UI_],
  [웹 브라우저에서 에이전트와 대화하고 도구 호출을 시각화합니다],
  [_배포_],
  [LangGraph Platform, Docker, FastAPI 등으로 배포합니다],
  [_관측성_],
  [LangSmith로 실행 흐름, 토큰 사용량, 비용을 추적합니다],
)

에이전트의 테스트, 배포, 모니터링 인프라를 갖추었다면, 다음 장에서는 에이전트의 도구 생태계를 확장하는 핵심 표준인 MCP(Model Context Protocol)를 학습합니다. MCP를 활용하면 직접 도구를 구현하지 않고도 외부 서비스의 기능을 에이전트에 통합할 수 있습니다.

