# Framework Selection

LangChain, LangGraph, Deep Agents 세 프레임워크의 비교 및 선택 기준.

## 계층 아키텍처

```
Deep Agents (최상위)
  ├── 계획, 메모리, 스킬, 파일 관리
  ├── 내장 미들웨어: TodoList, Filesystem, SubAgent, Skills, Memory, HITL
  │
LangGraph (오케스트레이션)
  ├── 그래프, 노드, 엣지, 상태 관리
  │
LangChain (기반)
  └── 모델, 도구, 프롬프트, RAG
```

## 선택 기준

| 기준 | LangChain | LangGraph | Deep Agents |
|------|-----------|-----------|-------------|
| 복잡도 | 낮음 | 중간 | 높음 (자동화) |
| 제어 수준 | ReAct 자동 | 노드 단위 | 미들웨어 기반 |
| 상태 관리 | 메모리 | 체크포인터 | 백엔드 |
| 멀티에이전트 | 핸드오프 | 서브그래프 | 서브에이전트 |
| 파일 I/O | 수동 | 수동 | 내장 |
| 계획 수립 | 수동 | 수동 | `write_todos` 내장 |

## 언제 무엇을 선택하는가

- **LangChain**: 단일 에이전트, 간단한 도구 호출, RAG
- **LangGraph**: 복잡한 워크플로, 조건부 분기, 사람 개입
- **Deep Agents**: 파일 기반 작업, 자율 계획, 서브에이전트 오케스트레이션

## 프레임워크 혼합

Deep Agents 내부에서 LangChain 도구와 LangGraph 그래프를 모두 사용할 수 있다:

```python
from deepagents import create_deep_agent
from langchain_openai import ChatOpenAI

# LangChain 도구 + Deep Agents 하네스
agent = create_deep_agent(
    model=ChatOpenAI(model="gpt-4.1"),
    tools=[langchain_tool_1, langchain_tool_2],
)
```
