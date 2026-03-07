# LangChain Fundamentals

`create_agent()`, `@tool` 데코레이터, 미들웨어 패턴, 구조화된 출력.

## create_agent()

에이전트를 만드는 권장 방법:

```python
from langchain.chat_models import init_chat_model
from langchain.agents import create_agent

model = init_chat_model("openai:gpt-4.1")
agent = create_agent(model, tools=[...], prompt="...")
result = agent.invoke(
    {"messages": [{"role": "user", "content": "질문"}]},
    config={"configurable": {"thread_id": "1"}},
)
print(result["messages"][-1].content)
```

## @tool 데코레이터

```python
from langchain_core.tools import tool

@tool
def search(query: str) -> str:
    """Search the web for information."""
    return tavily.search(query)
```

도구 설명(docstring)이 에이전트의 도구 선택에 직접적 영향을 미친다. 명확하고 구체적으로 작성.

## 구조화된 출력

```python
from pydantic import BaseModel

class Answer(BaseModel):
    reasoning: str
    answer: str

structured_model = model.with_structured_output(Answer)
```

## 흔한 실수

| 실수 | 올바른 방법 |
|------|------------|
| 체크포인터 누락 | `create_agent(..., checkpointer=MemorySaver())` |
| thread_id 누락 | `config={"configurable": {"thread_id": "1"}}` |
| 모호한 도구 설명 | 구체적 docstring 작성 |
| `result.content` 접근 | `result["messages"][-1].content` |
| recursion_limit 미설정 | `config={"recursion_limit": 25}` |
