// Auto-generated from 04_tools_and_structured_output.ipynb
// Do not edit manually -- regenerate with nb2typ.py
#import "../../template.typ": *
#import "../../metadata.typ": *

#chapter(4, "도구와 구조화된 출력")

도구는 에이전트가 외부 세계와 상호작용하는 유일한 수단입니다. 이 장에서는 `@tool` 데코레이터의 고급 기능 — Pydantic 스키마, `ToolRuntime`을 통한 런타임 컨텍스트 접근, 동적 도구 등록 — 과 함께, `with_structured_output()`으로 모델의 응답을 Pydantic 모델이나 JSON 스키마에 맞게 강제하는 방법을 학습합니다.

앞 장에서 메시지 시스템을 통해 모델과 대화하는 방법을 배웠습니다. 하지만 모델이 텍스트만 생성한다면 진정한 에이전트라 할 수 없습니다. 에이전트의 핵심은 _도구 호출_을 통해 계산, 검색, API 호출 등 실질적인 작업을 수행하는 데 있습니다. 이 장에서는 도구 정의부터 에이전트 연결, 런타임 컨텍스트 주입, 출력 구조화까지 도구 시스템의 전체를 다룹니다.

#learning-header()
#learning-objectives([`@tool` 데코레이터로 도구를 만들고 스키마를 확인합니다], [Pydantic 모델을 사용하여 복잡한 입력 스키마를 정의합니다], [`create_agent()`에 도구를 연결하여 에이전트를 구성합니다], [`ToolRuntime`을 통해 도구에서 런타임 컨텍스트에 접근합니다], [`with_structured_output()`으로 구조화된 출력을 설정합니다], [`ToolStrategy`와 `ProviderStrategy`의 차이를 이해합니다])

== 4.1 환경 설정

API 키를 로드하고 OpenAI 모델을 초기화합니다.

#code-block(`````python
import os
from dotenv import load_dotenv
from langchain_openai import ChatOpenAI

load_dotenv(override=True)

# OpenAI를 통한 모델 초기화
model = ChatOpenAI(
    model="gpt-4.1",
)

print("모델 초기화 완료:", model.model_name)
`````)
#output-block(`````
모델 초기화 완료: gpt-4.1
`````)

== 4.2 \@tool 데코레이터 기본

모델이 준비되었으니, 에이전트에게 능력을 부여할 도구를 만들어 봅니다. `@tool` 데코레이터는 일반 Python 함수를 LangChain 도구 객체로 변환합니다.

함수에 `@tool`을 붙이면 에이전트가 사용할 수 있는 도구가 됩니다.
LangChain은 함수의 이름, docstring, 타입 힌트를 자동으로 파싱하여 도구 스키마를 생성합니다.

`@tool` 데코레이터에 인자를 전달하여 도구의 이름과 설명을 커스터마이즈할 수도 있습니다. `@tool("custom_name")`은 도구 이름을 변경하고, `@tool("custom_name", description="...")`은 이름과 설명 모두를 직접 지정합니다. 함수명과 다른 이름을 사용하고 싶거나, docstring보다 더 상세한 설명이 필요할 때 유용합니다.

#warning-box[도구 함수의 매개변수 이름으로 `config`와 `runtime`은 _예약어_이므로 사용할 수 없습니다. 이 이름들은 LangChain 내부에서 런타임 컨텍스트 주입에 사용됩니다.]

#code-block(`````python
from langchain.tools import tool

@tool
def my_tool(param: str) -> str:
    """Tool description for the LLM."""
    return result
`````)

#code-block(`````python
from langchain.tools import tool

@tool
def get_weather(city: str) -> str:
    """도시의 현재 날씨를 조회합니다."""
    weather_data = {
        "Seoul": "맑음, 15\u00b0C",
        "Tokyo": "흐림, 12\u00b0C",
        "New York": "비, 8\u00b0C",
    }
    return weather_data.get(city, f"날씨 데이터를 사용할 수 없습니다: {city}")

# 도구의 스키마 확인
print("도구 이름:", get_weather.name)
print("도구 설명:", get_weather.description)
print("입력 스키마:", get_weather.args_schema.model_json_schema())
`````)
#output-block(`````
도구 이름: get_weather
도구 설명: 도시의 현재 날씨를 조회합니다.
입력 스키마: {'description': '도시의 현재 날씨를 조회합니다.', 'properties': {'city': {'title': 'City', 'type': 'string'}}, 'required': ['city'], 'title': 'get_weather', 'type': 'object'}
`````)

== 4.3 Pydantic 복잡한 스키마

단순한 함수 시그니처만으로는 표현하기 어려운 복잡한 입력 구조가 필요할 때가 있습니다. 예를 들어, 검색 쿼리에 필터 조건, 정렬 옵션, 페이지네이션 등 여러 매개변수가 필요한 경우입니다. Pydantic `BaseModel`을 사용하면 각 필드에 상세한 설명과 제약 조건을 추가할 수 있습니다.

더 복잡한 입력 구조가 필요한 경우, Pydantic `BaseModel`을 사용하여 스키마를 정의합니다.
`@tool(args_schema=MySchema)` 형태로 전달하면, LLM이 정확한 파라미터 구조를 이해할 수 있습니다.

- `Field(description=...)`: 각 필드에 대한 설명을 LLM에 전달. 이 설명이 구체적일수록 모델이 올바른 값을 생성할 확률이 높아집니다.
- `Field(default=...)`: 기본값 설정

#code-block(`````python
from pydantic import BaseModel, Field

class SearchQuery(BaseModel):
    """데이터베이스 쿼리용 검색 파라미터입니다."""
    query: str = Field(description="검색 쿼리 문자열")
    max_results: int = Field(default=5, description="반환할 최대 결과 수")
    category: str = Field(default="all", description="검색 카테고리: all, tech, science, news")

@tool(args_schema=SearchQuery)
def search_database(query: str, max_results: int = 5, category: str = "all") -> str:
    """고급 필터링 옵션으로 데이터베이스를 검색합니다."""
    return f"'{category}' 카테고리에서 '{query}'에 대한 {max_results}개의 결과를 찾았습니다"

print("복합 스키마:", search_database.args_schema.model_json_schema())
`````)
#output-block(`````
복합 스키마: {'description': '데이터베이스 쿼리용 검색 파라미터입니다.', 'properties': {'query': {'description': '검색 쿼리 문자열', 'title': 'Query', 'type': 'string'}, 'max_results': {'default': 5, 'description': '반환할 최대 결과 수', 'title': 'Max Results', 'type': 'integer'}, 'category': {'default': 'all', 'description': '검색 카테고리: all, tech, science, news', 'title': 'Category', 'type': 'string'}}, 'required': ['query'], 'title': 'SearchQuery', 'type': 'object'}
`````)

== 4.4 도구를 에이전트에 연결

도구를 정의했으면, 이제 에이전트에 연결합니다. `create_agent()`에 도구 리스트를 전달하면, 에이전트가 상황에 맞는 도구를 자동으로 선택하여 실행합니다. 내부적으로 `model.bind_tools(tools)`가 호출되어 모델에 도구 스키마가 바인딩됩니다.

#code-block(`````python
from langchain.agents import create_agent

agent = create_agent(
    model=model,
    tools=[tool1, tool2],
    system_prompt="...",
)
`````)

#note-box[_참고:_ LangChain v1에서는 `create_react_agent`가 제거되었습니다. 반드시 `create_agent`를 사용하세요.]

== 4.5 ToolRuntime

에이전트에 도구를 연결하는 방법을 배웠으니, 한 단계 더 나아가 도구가 _실행 환경의 정보_에 접근하는 방법을 살펴봅니다. 예를 들어, 현재 로그인한 사용자의 ID에 따라 다른 데이터를 반환하거나, 데이터베이스 커넥션을 주입받아야 하는 경우입니다.

`ToolRuntime`을 사용하면 도구 함수 내에서 현재 대화 상태(state)에 접근할 수 있습니다.
이를 통해 메시지 이력, 설정값, 사용자 정보, DB 커넥션 등 런타임 컨텍스트를 활용하는 도구를 만들 수 있습니다. `ToolRuntime`은 LLM에게는 노출되지 않는 _숨겨진 매개변수_로, 모델이 이 값을 생성할 필요가 없습니다.

#tip-box[`ToolRuntime`의 상세 활용법은 7장(HITL과 런타임)에서 `context_schema`와 함께 더 깊이 다룹니다.]

#code-block(`````python
@tool
def my_tool(runtime: ToolRuntime) -> str:
    messages = runtime.state["messages"]
    # ...
`````)

== 4.6 구조화된 출력

도구 정의를 마쳤으니, 이제 반대 방향 --- 모델의 _출력_을 제어하는 방법을 살펴봅니다. 자유 형식의 텍스트 대신, 정해진 스키마에 맞는 구조화된 데이터를 받고 싶을 때 `with_structured_output()`을 사용합니다.

`with_structured_output()`을 사용하면 모델의 응답을 Pydantic 모델이나 dataclass 형태로 직접 받을 수 있습니다.
이 방법은 에이전트 없이 모델에서 직접 사용합니다. 반환값은 지정한 Pydantic 모델의 인스턴스이므로, 별도의 파싱 없이 바로 `result.field_name` 형태로 접근할 수 있습니다.

#code-block(`````python
structured_model = model.with_structured_output(MySchema)
result = structured_model.invoke("...")
# result는 MySchema 인스턴스
`````)

== 4.7 ToolStrategy vs ProviderStrategy

`with_structured_output()`은 모델 수준에서 동작합니다. 에이전트 수준에서 최종 응답을 구조화하려면 `create_agent()`의 `response_format` 매개변수를 사용하며, 이때 두 가지 전략 중 하나를 선택할 수 있습니다:

에이전트에서 구조화된 출력을 사용하는 두 가지 전략이 있습니다:

#table(
  columns: 3,
  align: left,
  stroke: 0.5pt + luma(200),
  inset: 8pt,
  fill: (_, row) => if row == 0 { rgb("#E0F2F3") } else if calc.odd(row) { luma(248) } else { white },
  text(weight: "bold")[전략],
  text(weight: "bold")[설명],
  text(weight: "bold")[장점],
  [`ToolStrategy`],
  [도구 호출 메커니즘을 활용하여 구조화된 출력 생성],
  [모든 모델에서 동작, 안정적],
  [`ProviderStrategy`],
  [프로바이더의 네이티브 구조화 출력 기능 사용],
  [더 빠르고 정확 (지원 모델 한정)],
)

`response_format` 파라미터에 전략을 지정하여 에이전트의 최종 응답을 구조화할 수 있습니다. `ToolStrategy`는 내부적으로 응답 스키마를 하나의 "도구"로 변환하여 모델에게 호출하도록 유도하는 방식이고, `ProviderStrategy`는 OpenAI의 `response_format` 같은 프로바이더 네이티브 JSON 모드를 활용하는 방식입니다. `ToolStrategy`가 더 넓은 호환성을 제공하지만, `ProviderStrategy`는 지원 모델에서 더 빠르고 정확한 결과를 보여줍니다.

#chapter-summary-header()

이 노트북에서 학습한 핵심 내용을 정리합니다.

#table(
  columns: 2,
  align: left,
  stroke: 0.5pt + luma(200),
  inset: 8pt,
  fill: (_, row) => if row == 0 { rgb("#E0F2F3") } else if calc.odd(row) { luma(248) } else { white },
  text(weight: "bold")[항목],
  text(weight: "bold")[설명],
  [`\@tool` 데코레이터],
  [함수를 에이전트용 도구로 변환],
  [`args_schema`],
  [Pydantic 모델로 복잡한 입력 스키마 정의],
  [`create_agent()`],
  [모델과 도구를 연결하여 에이전트 생성],
  [`ToolRuntime`],
  [도구 내에서 런타임 상태(대화 이력 등) 접근],
  [`with_structured_output()`],
  [모델 응답을 Pydantic/dataclass로 구조화],
  [`ToolStrategy`],
  [도구 호출 방식의 구조화된 에이전트 출력],
  [`ProviderStrategy`],
  [프로바이더 네이티브 구조화 출력],
)

이 장에서는 도구의 정의·연결·런타임 주입과 출력 구조화까지, 에이전트의 "입출력 인터페이스"를 완성했습니다. 다음 장에서는 에이전트가 대화를 _기억_하고 응답을 _실시간으로 전달_하는 방법 --- 단기/장기 메모리 아키텍처와 5가지 스트리밍 모드 --- 를 다룹니다.

