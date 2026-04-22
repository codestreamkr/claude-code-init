# 40-delegate

이 단계는 위임만 처리한다.

## 실행 규칙

1. `agents/agent-developer.md` 기준으로 developer 작업을 `Agent` 도구로 위임한다.
2. `agents/agent-document.md` 기준으로 document 작업을 같은 응답에서 `Agent` 도구로 병렬 위임한다.
3. 메인 어시스턴트는 두 위임이 모두 시작됐는지 확인한다.
4. developer 결과와 document 결과를 받은 뒤 메인 어시스턴트가 최종본 1개로 통합한다.
5. 아키텍트가 현재 구조 리포트와 목표 구조를 먼저 확정한다.
6. developer와 document에는 아키텍트가 확정한 범위와 구조를 같은 기준으로 전달한다.
7. developer는 개발 관점의 프레임 정보를 정리한다.
8. document는 최종 문서 구조와 표현을 정리한다.

## Agent 도구 호출 방식

- developer 위임: `Agent(description="developer 역할 - 개발 가이드 작성", prompt=agent-developer.md 내용 + 아키텍트 확정 리포트/제안)`
- document 위임: `Agent(description="document 역할 - 최종 문서 정리", prompt=agent-document.md 내용 + 아키텍트 확정 리포트/제안)`
- 두 `Agent` 호출을 반드시 같은 응답 안에서 동시에 실행한다.

## 금지

- `developer`만 위임하거나 `document`만 위임하지 않는다.
- 순차로 따로 위임하지 않는다.
- 메인 어시스턴트가 두 역할을 대신 수행하지 않는다.
- developer와 document는 구조 결론을 다시 정하지 않는다.
