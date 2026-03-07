# LangGraph Persistence

체크포인터, thread_id, 상태 히스토리, 타임 트래블.

## 체크포인터

| 종류 | 용도 |
|------|------|
| `InMemorySaver` | 개발/테스트 |
| `SqliteSaver` | 로컬 지속성 |
| `PostgresSaver` | 프로덕션 |

```python
from langgraph.checkpoint.memory import MemorySaver

checkpointer = MemorySaver()
app = graph.compile(checkpointer=checkpointer)

# 실행 시 thread_id 필수
result = app.invoke(
    {"messages": [...]},
    config={"configurable": {"thread_id": "session-1"}},
)
```

## 단기 메모리 vs 장기 메모리

| 구분 | 단기 (Short-term) | 장기 (Long-term) |
|------|-------------------|------------------|
| 범위 | 스레드 내 | 스레드 간 |
| 메커니즘 | 체크포인터 | Store |
| 수명 | 대화 세션 | 영구 |

## 상태 히스토리 & 타임 트래블

```python
# 히스토리 조회
for state in app.get_state_history(config):
    print(state.values, state.config)

# 특정 시점으로 되돌리기
old_config = state.config  # 원하는 시점
result = app.invoke(None, config=old_config)
```

## update_state

```python
from langgraph.types import Overwrite

# 리듀서 우회하여 상태 직접 덮어쓰기
app.update_state(
    config,
    {"messages": Overwrite([new_message])},
)
```

## 서브그래프 체크포인터 모드

| 값 | 동작 |
|----|------|
| `False` | 체크포인트 안 함 |
| `None` | 부모와 같은 체크포인터 사용 |
| `True` | 독립 체크포인터 |

## 프로덕션 팁

- `InMemoryStore`는 테스트 전용 → `PostgresStore` 사용
- thread_id는 사용자 세션과 매핑
- 체크포인터 없이 interrupt 사용 불가
