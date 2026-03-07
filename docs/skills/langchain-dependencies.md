# LangChain Dependencies

패키지 버전 및 의존성 관리 가이드.

## 요구사항

- Python 3.10+
- Node.js 20+ (TypeScript 사용 시)

## 핵심 패키지

| 패키지 | 용도 | 비고 |
|--------|------|------|
| `langchain` | 코어 프레임워크 | 1.0+ (LTS), ~~0.3 레거시~~ |
| `langchain-core` | 기본 추상화 | langchain에 포함 |
| `langsmith` | 관측성 | 선택사항 |
| `langchain-openai` | OpenAI 통합 | 전용 패키지 권장 |
| `langchain-anthropic` | Anthropic 통합 | 전용 패키지 권장 |
| `langchain-community` | 커뮤니티 통합 | 보수적 버전 고정 |

## 설치

```bash
# uv (권장)
uv add langchain langchain-openai

# pip
pip install langchain langchain-openai
```

## 버전 관리 원칙

1. **LangChain 1.0+ 사용** — 0.3은 레거시
2. **전용 통합 패키지 우선** — `langchain-openai` > `langchain-community`의 OpenAI
3. **langchain-community는 보수적 고정** — 빈번한 변경 가능성
4. **langchain-core 직접 설치 불필요** — langchain에 포함
