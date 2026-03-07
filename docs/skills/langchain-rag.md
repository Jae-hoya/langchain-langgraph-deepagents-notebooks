# LangChain RAG

RAG(Retrieval-Augmented Generation) 파이프라인 구축 가이드.

## 파이프라인 구성

```
문서 로드 → 청킹 → 임베딩 → 벡터 저장소 → 검색 → 생성
```

## 문서 로더

```python
from langchain_community.document_loaders import (
    PyPDFLoader,       # PDF
    WebBaseLoader,     # 웹 페이지
    DirectoryLoader,   # 디렉토리
)
```

## 텍스트 분할

```python
from langchain_text_splitters import RecursiveCharacterTextSplitter

splitter = RecursiveCharacterTextSplitter(
    chunk_size=1000,
    chunk_overlap=200,
)
docs = splitter.split_documents(documents)
```

권장: chunk 500–1500자, overlap 10–20%.

## 벡터 저장소

| 저장소 | 용도 |
|--------|------|
| `InMemoryVectorStore` | 테스트 |
| `FAISS` | 로컬 개발 |
| `Chroma` | 개발/프로토타입 |
| `Pinecone` | 프로덕션 |

```python
from langchain_openai import OpenAIEmbeddings
from langchain_community.vectorstores import FAISS

embeddings = OpenAIEmbeddings()
vectorstore = FAISS.from_documents(docs, embeddings)
retriever = vectorstore.as_retriever(
    search_type="mmr",  # 또는 "similarity"
    search_kwargs={"k": 5},
)
```

## 에이전트 통합

```python
from langchain_core.tools import tool

@tool
def search_docs(query: str) -> str:
    """Search the knowledge base for relevant information."""
    docs = retriever.invoke(query)
    return "\n\n".join(d.page_content for d in docs)
```

## 모범 사례

- 청크 크기는 콘텐츠 유형에 맞게 조정
- MMR(Maximal Marginal Relevance)로 다양성 확보
- 메타데이터 필터링으로 검색 범위 제한
- 임베딩 모델은 일관되게 유지
