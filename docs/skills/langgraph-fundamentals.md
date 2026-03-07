# LangGraph Fundamentals

StateGraph, 노드, 엣지, 상태 리듀서, 스트리밍.

## 설계 방법론

1. 플로차트로 단계 정의
2. 상태 구조 설계 (TypedDict)
3. 노드 함수 작성 (부분 업데이트 반환)
4. 엣지로 연결

## StateGraph 기본

```python
from langgraph.graph import StateGraph, START, END
from typing import TypedDict, Annotated
import operator

class State(TypedDict):
    messages: Annotated[list, operator.add]
    count: int

def node_a(state: State) -> dict:
    return {"messages": ["hello"], "count": state["count"] + 1}

graph = StateGraph(State)
graph.add_node("a", node_a)
graph.add_edge(START, "a")
graph.add_edge("a", END)
app = graph.compile()
```

## 리듀서

- `Annotated[list, operator.add]`: 리스트 누적
- `Annotated[list, add_messages]`: 메시지 ID 기반 병합
- 리듀서 없음: 값 덮어쓰기

## 조건부 엣지

```python
def router(state: State) -> str:
    if state["count"] > 3:
        return "end"
    return "continue"

graph.add_conditional_edges("a", router, {
    "end": END,
    "continue": "a",
})
```

## Command (상태 업데이트 + 라우팅)

```python
from langgraph.types import Command

def node(state):
    return Command(
        update={"messages": ["done"]},
        goto="next_node",
    )
```

## Send (팬아웃 병렬)

```python
from langgraph.types import Send

def fan_out(state):
    return [Send("worker", {"task": t}) for t in state["tasks"]]
```

## 스트리밍 모드

| 모드 | 설명 |
|------|------|
| `"values"` | 전체 상태 스냅샷 |
| `"updates"` | 노드별 업데이트만 |
| `"messages"` | LLM 토큰 스트리밍 |
| `"custom"` | `get_stream_writer()` 사용 |

## 에러 처리

- `RetryPolicy`: 재시도 정책
- `ToolNode`: 도구 에러 자동 처리
- `interrupt`: 사람 개입 요청
