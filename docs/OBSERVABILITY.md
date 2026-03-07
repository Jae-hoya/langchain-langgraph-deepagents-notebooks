# Observability (관측성)

모든 노트북은 `.env` 파일만으로 두 가지 관측성 서비스를 지원합니다.

## LangSmith

환경 변수만 설정하면 **코드 수정 없이** 자동 트레이싱이 활성화됩니다.

```bash
# .env
LANGSMITH_API_KEY=lsv2-...
LANGSMITH_TRACING=true
LANGSMITH_PROJECT=agent-notebooks
```

LangChain/LangGraph의 모든 `invoke()`, `stream()` 호출이 자동으로 LangSmith에 기록됩니다.

## Langfuse

Langfuse는 `CallbackHandler`를 생성하여 `config`로 전달하는 방식입니다.

```python
from langfuse.langchain import CallbackHandler

langfuse_handler = CallbackHandler()

# invoke/stream 호출 시 config에 콜백 전달
result = agent.invoke(
    {"messages": [...]},
    config={"callbacks": [langfuse_handler]},
)
```

```bash
# .env
LANGFUSE_SECRET_KEY=sk-lf-...
LANGFUSE_PUBLIC_KEY=pk-lf-...
LANGFUSE_HOST=https://cloud.langfuse.com
```

각 노트북 상단의 Observability 셀에서 두 서비스 모두 자동으로 초기화됩니다.
