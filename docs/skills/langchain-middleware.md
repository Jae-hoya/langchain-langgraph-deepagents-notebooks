# LangChain Middleware

Human-in-the-Loop 승인, 커스텀 미들웨어, Command 재개 패턴.

## 핵심 요구사항

모든 HITL 워크플로에 **필수**:
- 체크포인터 (`MemorySaver()`)
- `thread_id` in config

## HumanInTheLoopMiddleware

```python
from langchain.agents import create_agent
from langchain.agents.middleware import HumanInTheLoopMiddleware
from langgraph.checkpoint.memory import MemorySaver

agent = create_agent(
    model,
    tools=[...],
    middleware=[HumanInTheLoopMiddleware()],
    checkpointer=MemorySaver(),
)
```

## 커스텀 미들웨어

```python
from langchain.agents.middleware import AgentMiddleware

class LoggingMiddleware(AgentMiddleware):
    async def before_model(self, state, config):
        print("Before model call")
        return state

    async def after_model(self, state, config):
        print("After model call")
        return state

    async def wrap_tool_call(self, tool_call, config):
        print(f"Tool: {tool_call['name']}")
        return tool_call
```

훅 종류:
- `before_model`: 모델 호출 전
- `after_model`: 모델 호출 후
- `wrap_tool_call`: 도구 실행 전/후

## Command 재개

```python
from langgraph.types import Command

# 승인 후 재개
result = agent.invoke(
    Command(resume="approved"),
    config={"configurable": {"thread_id": "1"}},
)
```

## 흔한 실수

| 실수 | 해결 |
|------|------|
| 체크포인터 누락 | `checkpointer=MemorySaver()` 필수 |
| thread_id 없음 | config에 반드시 포함 |
| 도구 실행 후 인터럽트 | 실행 전에 인터럽트해야 함 |
| `Command(update=...)` 혼동 | 재개는 `Command(resume=...)` |
