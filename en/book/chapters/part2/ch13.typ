// Auto-generated from 13_guardrails.ipynb
// Do not edit manually -- regenerate with nb2typ.py
#import "../../template.typ": *
#import "../../metadata.typ": *

#chapter(13, "Guardrails")


== Learning Objectives

Learn how to configure guardrails that validate and filter agent input and output.

This notebook covers:
- Understanding the concept of guardrails and why they are needed
- Comparing deterministic guardrails and model-based guardrails
- Configuring PII detection middleware
- Building human-in-the-loop guardrails
- Writing custom `before_agent` and `after_agent` guardrails


== 13.1 Environment Setup


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

== 13.2 Guardrail Concepts

_Guardrails_ are safety mechanisms that validate and filter content during agent execution.

=== Why do we need guardrails?

- Prevent leakage of personally identifiable information (PII)
- Block prompt-injection attacks
- Prevent harmful or inappropriate content
- Enforce business rules and compliance requirements
- Validate output quality and correctness

=== Two approaches

#table(
  columns: 4,
  align: left,
  stroke: 0.5pt + luma(200),
  inset: 8pt,
  fill: (_, row) => if row == 0 { rgb("#E0F2F3") } else if calc.odd(row) { luma(248) } else { white },
  text(weight: "bold")[Approach],
  text(weight: "bold")[Mechanism],
  text(weight: "bold")[Strengths],
  text(weight: "bold")[Weaknesses],
  [_Deterministic_],
  [Regex, keyword matching, explicit rules],
  [Fast, predictable, cost-efficient],
  [May miss subtle violations],
  [_Model-based_],
  [Use an LLM or classifier to analyze meaning],
  [Can catch subtle issues],
  [Slower and more expensive],
)

=== When guardrails are applied

#code-block(`````python
User input → [input guardrail] → agent execution → [output guardrail] → response
                  ↑                                    ↑
            before_agent                          after_agent
`````)


== 13.3 PII Detection Middleware

`PIIMiddleware` automatically detects and handles personal data such as email addresses, credit-card numbers, and IP addresses.

#table(
  columns: 2,
  align: left,
  stroke: 0.5pt + luma(200),
  inset: 8pt,
  fill: (_, row) => if row == 0 { rgb("#E0F2F3") } else if calc.odd(row) { luma(248) } else { white },
  text(weight: "bold")[Strategy],
  text(weight: "bold")[Result],
  [`redact`],
  [Replace with `[REDACTED_EMAIL]`],
  [`mask`],
  [Partial masking (for example, only the last 4 digits shown)],
  [`hash`],
  [Replace with a deterministic hash],
  [`block`],
  [Raise an exception when detected],
)


#code-block(`````python
# PII 감지 미들웨어 설정 예시
print("PII 감지 미들웨어 설정:")
print("=" * 50)
print("""
from langchain.agents import create_agent
from langchain.agents.middleware import PIIMiddleware

agent = create_agent(
    model="gpt-4.1",
    tools=[customer_service_tool, email_tool],
    middleware=[
        # 이메일 주소를 [REDACTED_EMAIL]로 대체
        PIIMiddleware("email",
            strategy="redact",
            apply_to_input=True),

        # 신용카드 번호를 부분 마스킹 (****-****-****-1234)
        PIIMiddleware("credit_card",
            strategy="mask",
            apply_to_input=True),

        # API 키 감지 시 차단 (커스텀 정규식)
        PIIMiddleware("api_key",
            detector=r"sk-[a-zA-Z0-9]{32}",
            strategy="block",
            apply_to_input=True),
    ],
)
""")
print("내장 PII 타입: email, credit_card, ip, mac_address, url")
print("커스텀 감지: detector 파라미터에 정규식 또는 함수 전달")
`````)

== 13.4 Human-in-the-Loop Guardrails

`HumanInTheLoopMiddleware` requires _human approval_ before risky actions are executed. This is essential for high-risk operations such as financial transactions, data deletion, or external communication.


#code-block(`````python
# Human-in-the-Loop 가드레일 예시
print("Human-in-the-Loop 가드레일:")
print("=" * 50)
print("""
from langchain.agents import create_agent
from langchain.agents.middleware import HumanInTheLoopMiddleware
from langgraph.checkpoint.memory import InMemorySaver
from langgraph.types import Command

agent = create_agent(
    model="gpt-4.1",
    tools=[search_tool, send_email_tool, delete_db_tool],
    middleware=[
        HumanInTheLoopMiddleware(
            interrupt_on={
                "send_email": True,       # 승인 필요
                "delete_db": True,         # 승인 필요
                "search": False,           # 자동 실행
            }
        ),
    ],
    checkpointer=InMemorySaver(),
)

config = {"configurable": {"thread_id": "review-123"}}

# 1단계: 에이전트 실행 → send_email에서 중단
result = agent.invoke(
    {"messages": [{"role": "user", "content": "팀에 이메일 보내"}]},
    config=config,
)
# → 중단됨: send_email 실행 전 승인 대기

# 2단계: 승인 후 재개
result = agent.invoke(
    Command(resume={"decisions": [{"type": "approve"}]}),
    config=config,
)
""")
print("핵심: checkpointer가 있어야 중단/재개가 가능합니다.")
print("거부 시: {\"type\": \"reject\"}로 도구 실행을 막을 수 있습니다.")
`````)

== 13.5 Custom Input Guardrails — `before_agent`

The `before_agent` hook validates requests _before the agent starts running_. It is useful for session-level authentication, rate limiting, and content filtering.


#code-block(`````python
# 커스텀 입력 가드레일 — ContentFilterMiddleware 클래스
print("커스텀 입력 가드레일 (클래스 방식):")
print("=" * 50)
print("""
from langchain.agents.middleware import (
    AgentMiddleware, AgentState, hook_config
)
from langgraph.runtime import Runtime
from typing import Any

class ContentFilterMiddleware(AgentMiddleware):
    \"\"\"결정론적 가드레일: 금지 키워드가 포함된 요청을 차단합니다.\"\"\"

    def __init__(self, banned_keywords: list[str]):
        super().__init__()
        self.banned_keywords = [kw.lower() for kw in banned_keywords]

    @hook_config(can_jump_to=["end"])
    def before_agent(
        self, state: AgentState, runtime: Runtime
    ) -> dict[str, Any] | None:
        if not state["messages"]:
            return None

        first_message = state["messages"][0]
        if first_message.type != "human":
            return None

        content = first_message.content.lower()
        for keyword in self.banned_keywords:
            if keyword in content:
                return {
                    "messages": [{
                        "role": "assistant",
                        "content": "부적절한 내용이 포함되어 있습니다."
                    }],
                    "jump_to": "end"
                }
        return None
""")
print("핵심: jump_to='end'로 에이전트 실행을 건너뛰고 즉시 응답합니다.")
print("None을 반환하면 다음 단계(에이전트 실행)로 진행합니다.")
`````)

== 13.6 Custom Output Guardrails — `after_agent`

The `after_agent` hook validates the final output _after agent execution is complete_. It is useful for model-based safety checks and quality validation.


#code-block(`````python
# 커스텀 출력 가드레일 — SafetyGuardrailMiddleware 클래스
print("커스텀 출력 가드레일 (클래스 방식):")
print("=" * 50)
print("""
from langchain.agents.middleware import (
    AgentMiddleware, AgentState, hook_config
)
from langgraph.runtime import Runtime
from langchain.messages import AIMessage
from langchain.chat_models import init_chat_model
from typing import Any

class SafetyGuardrailMiddleware(AgentMiddleware):
    \"\"\"모델 기반 가드레일: LLM으로 응답 안전성을 평가합니다.\"\"\"

    def __init__(self):
        super().__init__()
        self.safety_model = init_chat_model("gpt-4.1-mini")

    @hook_config(can_jump_to=["end"])
    def after_agent(
        self, state: AgentState, runtime: Runtime
    ) -> dict[str, Any] | None:
        if not state["messages"]:
            return None

        last_message = state["messages"][-1]
        if not isinstance(last_message, AIMessage):
            return None

        safety_prompt = f\"\"\"Evaluate if this response is safe.
        Respond with only 'SAFE' or 'UNSAFE'.

        Response: {last_message.content}\"\"\"

        result = self.safety_model.invoke(
            [{"role": "user", "content": safety_prompt}]
        )

        if "UNSAFE" in result.content:
            last_message.content = (
                "안전하지 않은 응답입니다. 다시 질문해주세요."
            )
        return None
""")
print("핵심: 별도의 경량 모델(gpt-4.1-mini)로 안전성을 평가합니다.")
print("UNSAFE 판정 시 응답 내용을 안전한 메시지로 교체합니다.")
`````)

== 13.7 Decorator-Based Guardrails

Instead of defining a class, you can build a concise guardrail with _decorators_.


#code-block(`````python
# 데코레이터 방식 가드레일
print("데코레이터 방식 가드레일:")
print("=" * 50)
print("""
from langchain.agents.middleware import (
    before_agent, after_agent, AgentState, hook_config
)
from langgraph.runtime import Runtime
from typing import Any

banned_keywords = ["hack", "exploit", "malware"]

# 입력 가드레일 — 데코레이터
@before_agent(can_jump_to=["end"])
def content_filter(
    state: AgentState, runtime: Runtime
) -> dict[str, Any] | None:
    \"\"\"금지 키워드를 차단합니다.\"\"\"
    if not state["messages"]:
        return None
    content = state["messages"][0].content.lower()
    for kw in banned_keywords:
        if kw in content:
            return {
                "messages": [{"role": "assistant",
                    "content": "부적절한 요청입니다."}],
                "jump_to": "end"
            }
    return None

# 출력 가드레일 — 데코레이터
@after_agent(can_jump_to=["end"])
def safety_check(
    state: AgentState, runtime: Runtime
) -> dict[str, Any] | None:
    \"\"\"응답에 민감한 내용이 없는지 확인합니다.\"\"\"
    last = state["messages"][-1]
    if hasattr(last, 'content') and '비밀번호' in last.content:
        last.content = "민감한 정보가 포함된 응답입니다."
    return None

# 에이전트에 적용
agent = create_agent(
    model="gpt-4.1",
    tools=[search_tool],
    middleware=[content_filter, safety_check],
)
""")
print("데코레이터 방식은 간단한 가드레일에 적합합니다.")
print("복잡한 로직(상태 관리, 초기화 등)은 클래스 방식을 사용하세요.")
`````)

== 13.8 Combining Multiple Guardrails

By adding several guardrails in order to the `middleware` list, you can build a _layered defense_ strategy.


#code-block(`````python
# 다중 가드레일 조합
print("다중 가드레일 조합 (다층 방어):")
print("=" * 50)
print("""
from langchain.agents import create_agent
from langchain.agents.middleware import (
    PIIMiddleware, HumanInTheLoopMiddleware
)

agent = create_agent(
    model="gpt-4.1",
    tools=[search_tool, send_email_tool],
    middleware=[
        # Layer 1: 결정론적 입력 필터
        ContentFilterMiddleware(
            banned_keywords=["hack", "exploit"]
        ),

        # Layer 2: PII 보호 (입력 + 출력)
        PIIMiddleware("email",
            strategy="redact", apply_to_input=True),
        PIIMiddleware("email",
            strategy="redact", apply_to_output=True),

        # Layer 3: 민감 도구 사람 승인
        HumanInTheLoopMiddleware(
            interrupt_on={"send_email": True}
        ),

        # Layer 4: 모델 기반 안전성 검사
        SafetyGuardrailMiddleware(),
    ],
)
""")
print("실행 순서:")
print("  입력 → [ContentFilter] → [PII 입력] → 에이전트 실행")
print("       → [HITL 승인] → [PII 출력] → [Safety] → 응답")
print()
print("팁: 빠른 결정론적 가드레일을 앞에, 느린 모델 기반을 뒤에 배치")
`````)

== 13.9 Production Guardrail Patterns

=== Best practices

#table(
  columns: 3,
  align: left,
  stroke: 0.5pt + luma(200),
  inset: 8pt,
  fill: (_, row) => if row == 0 { rgb("#E0F2F3") } else if calc.odd(row) { luma(248) } else { white },
  text(weight: "bold")[Pattern],
  text(weight: "bold")[Description],
  text(weight: "bold")[Implementation],
  [_Layered defense_],
  [Combine multiple guardrails to remove a single point of failure],
  [`middleware=[layer1, layer2, ...]`],
  [_Fail fast_],
  [Run deterministic checks first to reduce cost],
  [Deterministic → model-based order],
  [_Input/output separation_],
  [Use different guardrails for input and output],
  [`before_agent` + `after_agent`],
  [_Graceful rejection_],
  [Return a friendly message when blocking a request],
  [`jump_to="end"` + guidance message],
  [_Logging and monitoring_],
  [Record guardrail trigger events],
  [LangSmith tracing integration],
  [_Fallback strategy_],
  [Handle failure inside the guardrail system itself],
  [`try/except` + default policy],
  [_Testing_],
  [Validate guardrail behavior with unit tests],
  [`GenericFakeChatModel`],
)

=== Domain-specific examples

#table(
  columns: 2,
  align: left,
  stroke: 0.5pt + luma(200),
  inset: 8pt,
  fill: (_, row) => if row == 0 { rgb("#E0F2F3") } else if calc.odd(row) { luma(248) } else { white },
  text(weight: "bold")[Domain],
  text(weight: "bold")[Main guardrails],
  [_Healthcare_],
  [PII (patient data), medical-advice disclaimer, emergency detection],
  [_Finance_],
  [PII (account data), investment disclaimer, HITL for transaction approval],
  [_Customer service_],
  [Sentiment analysis, escalation detection, PII masking],
  [_Education_],
  [Age-appropriateness checks, academic integrity, content filtering],
)


== 13.10 Summary

This notebook covered:

#table(
  columns: 2,
  align: left,
  stroke: 0.5pt + luma(200),
  inset: 8pt,
  fill: (_, row) => if row == 0 { rgb("#E0F2F3") } else if calc.odd(row) { luma(248) } else { white },
  text(weight: "bold")[Topic],
  text(weight: "bold")[Key Idea],
  [_Guardrail concepts_],
  [Guardrails validate and filter content during agent execution],
  [_PII detection_],
  [`PIIMiddleware` automatically detects and handles email, credit-card numbers, and related data],
  [_HITL_],
  [`HumanInTheLoopMiddleware` requires human approval before risky tool calls],
  [_Custom input_],
  [`before_agent` validates requests before execution],
  [_Custom output_],
  [`after_agent` validates responses after execution],
  [_Decorators_],
  [`\@before_agent` and `\@after_agent` define concise guardrails],
  [_Layered defense_],
  [Multiple guardrails can be stacked in the `middleware` list],
)

=== Next Steps
→ Continue to the _#link("../03_langgraph/01_introduction.ipynb")[LangGraph intermediate track]_


#line(length: 100%, stroke: 0.5pt + luma(200))
_References:_
- #link("../docs/langchain/13-guardrails.md")[Guardrails]

