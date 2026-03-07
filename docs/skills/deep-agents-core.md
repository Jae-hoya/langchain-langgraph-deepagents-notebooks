# Deep Agents Core

에이전트 아키텍처, 하네스 설정, SKILL.md 형식.

## 아키텍처

Deep Agents는 내장 미들웨어로 복잡한 작업을 자동화한다:

| 미들웨어 | 기능 |
|----------|------|
| `TodoList` | 계획 수립 (`write_todos`) |
| `Filesystem` | 파일 I/O (`ls`, `read_file`, `write_file`, `edit_file`, `glob`, `grep`) |
| `SubAgent` | 서브에이전트 위임 (`task`) |
| `Skills` | 스킬 로드 (progressive disclosure) |
| `Memory` | AGENTS.md → 시스템 프롬프트 |
| `HumanInTheLoop` | 승인 워크플로 |

## 에이전트 생성

```python
from deepagents import create_deep_agent
from langchain_openai import ChatOpenAI

agent = create_deep_agent(
    model=ChatOpenAI(model="gpt-4.1"),
    memory=["./AGENTS.md"],
    skills=["./skills/"],
    tools=[custom_tool_1, custom_tool_2],
    backend=FilesystemBackend(root_dir="./output"),
)
```

## SKILL.md 형식

```yaml
---
name: skill-name
description: Short description for progressive disclosure
---

# Skill Name

Detailed instructions loaded when the agent needs this skill.

## Workflow
1. Step one
2. Step two
```

YAML frontmatter의 `description`이 에이전트에게 항상 노출되고, 본문은 필요 시 로드된다.

## 내장 도구

| 도구 | 기능 |
|------|------|
| `write_todos` | 작업 계획 저장 |
| `ls` | 디렉토리 목록 |
| `read_file` | 파일 읽기 |
| `write_file` | 파일 쓰기 |
| `edit_file` | 파일 수정 |
| `glob` | 패턴 매칭 파일 검색 |
| `grep` | 파일 내용 검색 |
| `task` | 서브에이전트 호출 |

## 설정 경계

**커스터마이즈 가능:**
- 모델, 도구, 프롬프트, 백엔드, 스킬, 서브에이전트

**변경 불가:**
- 코어 미들웨어 제거
- 내장 도구 이름 변경
