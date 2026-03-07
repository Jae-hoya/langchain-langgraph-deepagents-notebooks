# Deep Agents Memory

백엔드 시스템, StoreBackend, FilesystemMiddleware.

## 백엔드 종류

| 백엔드 | 특성 | 용도 |
|--------|------|------|
| `StateBackend` | 임시, 단일 스레드 | 테스트 |
| `StoreBackend` | 영구, 크로스 세션 | 프로덕션 |
| `CompositeBackend` | 하이브리드 라우팅 | 복합 시나리오 |
| `FilesystemBackend` | 파일시스템 기반 | 로컬 개발 |

## FilesystemBackend

```python
from deepagents.backends import FilesystemBackend

backend = FilesystemBackend(
    root_dir="./output",
    virtual_mode=True,  # 보안: 실제 파일 시스템 접근 차단
)
```

**`virtual_mode=True` 필수** — 웹 서버에 `FilesystemBackend`를 절대 직접 배포하지 말 것.

## FilesystemMiddleware 도구

| 도구 | 기능 |
|------|------|
| `ls` | 디렉토리 목록 |
| `read_file` | 파일 읽기 |
| `write_file` | 파일 쓰기 |
| `edit_file` | 파일 수정 |
| `glob` | 패턴 매칭 |
| `grep` | 내용 검색 |

## StoreBackend

```python
from langgraph.store.memory import InMemoryStore
from deepagents.backends import StoreBackend

store = InMemoryStore()  # 테스트용
backend = StoreBackend(store=store)
```

**프로덕션**: `InMemoryStore` → `PostgresStore` 사용.

## CompositeBackend

경로 매칭으로 여러 백엔드를 조합:

```python
from deepagents.backends import CompositeBackend

backend = CompositeBackend(
    backends={
        "/tmp/": StateBackend(),
        "/data/": StoreBackend(store=store),
    }
)
```

경로 매칭은 **longest-prefix-first** 규칙.

## 보안 원칙

1. `FilesystemBackend`는 `virtual_mode=True` 사용
2. 웹 서버에 직접 배포 금지
3. 프로덕션에서는 `PostgresStore` 사용
