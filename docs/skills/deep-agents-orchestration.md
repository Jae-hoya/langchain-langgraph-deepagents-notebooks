# Deep Agents Orchestration

SubAgentMiddleware, TodoListMiddleware, HumanInTheLoopMiddleware.

## SubAgentMiddleware

`task` 도구로 서브에이전트에 작업을 위임한다.

```python
from deepagents import create_deep_agent

sub = {
    "name": "researcher",
    "description": "Researches topics using web search",
    "model": model,
    "system_prompt": "You are a research assistant.",
    "tools": [web_search],
}

agent = create_deep_agent(
    model=model,
    subagents=[sub],
)
```

### 서브에이전트 특성

- **Stateless**: 호출 간 상태 유지 안 함
- **부모 스킬 미상속**: 일반 서브에이전트는 부모의 스킬을 받지 않음
- 예외: `general-purpose` 서브에이전트는 일부 스킬 상속

## TodoListMiddleware

`write_todos` 도구로 계획을 수립한다.

```python
# 에이전트가 자동으로 write_todos를 사용
# 복잡한 작업 시 단계별 계획을 파일로 저장
agent.invoke({
    "messages": [{"role": "user", "content": "복잡한 분석 수행"}]
})
```

## HumanInTheLoopMiddleware

`interrupt_on` 설정으로 특정 도구 실행 전 사람 승인을 요청한다.

```python
agent = create_deep_agent(
    model=model,
    tools=[dangerous_tool],
    interrupt_on=["dangerous_tool"],
    checkpointer=MemorySaver(),
)
```

### 결정 유형

| 유형 | 설명 |
|------|------|
| Approve | 도구 호출 승인 |
| Reject | 도구 호출 거부 |
| Edit | 도구 호출 파라미터 수정 |

### 필수 요구사항

- **체크포인터 필수**: interrupt는 체크포인터 없이 작동하지 않음
- **thread_id 필수**: 재개 시 동일 thread_id 사용
- **인터럽트 타이밍**: `invoke()` 호출 사이에 발생
