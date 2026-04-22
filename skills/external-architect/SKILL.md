---
name: external-architect
description: 외부 시스템 연동 구조를 절차형으로 분석하고 설계 문서를 완성하는 위임형 스킬. 사용자가 "호페형", "external-architect"를 직접 부르거나 결제, 인증, 메시징, 정산, 웹훅, 콜백, 벤더 API 연동처럼 외부 시스템 경계와 전환 설계가 핵심인 작업을 맡길 때 사용한다. 체크리스트, 구조 리포트, 설계 제안, developer/document 위임, 최종 문서 통합을 고정된 순서로 수행한다.
---

# external-architect

이 스킬은 위임형 전용 절차다.

## 실행 순서

1. [workflow/00-entry.md](workflow/00-entry.md)
2. [workflow/10-checklist.md](workflow/10-checklist.md)
3. 해당 벤더의 `ENTRY.md`
4. [workflow/20-report.md](workflow/20-report.md)
5. [workflow/30-proposal.md](workflow/30-proposal.md)
6. [workflow/40-delegate.md](workflow/40-delegate.md)
7. [workflow/50-finish.md](workflow/50-finish.md)

## 전역 규칙

- 첫 응답은 `workflow/10-checklist.md` 기준 체크리스트만 작성한다.
- 체크리스트를 낸 뒤에만 저장소, 문서, 공식 문서를 읽는다.
- 벤더가 특정되면 해당 벤더의 `ENTRY.md`를 반드시 연다.
- 현재 구조 리포트 다음에 설계 제안을 작성한다.
- `developer`와 `document`는 같은 응답에서 `Agent` 도구로 병렬 위임한다.
- 최종 산출물은 문서 파일 1개로 닫는다.
- 최종 문서에는 `확인 필요`와 `## 이력관리`를 포함한다.
- 웹훅, 상태값, 헤더명, 수치, 지원 범위는 공식 문서 확인 후에만 단정한다.

## 벤더 진입점

- 토스페이먼츠: [vendors/toss/ENTRY.md](vendors/toss/ENTRY.md)
- NHN KCP: [vendors/kcp/ENTRY.md](vendors/kcp/ENTRY.md)
- 카카오페이: [vendors/kakaopay/ENTRY.md](vendors/kakaopay/ENTRY.md)
- 네이버페이: [vendors/naverpay/ENTRY.md](vendors/naverpay/ENTRY.md)

## 벤더가 불분명할 때

- 먼저 현재 구조를 보고 주 벤더를 판별한다.
- 둘 이상이 섞여 있으면 이번 요청의 주 대상 벤더를 하나 정해 진입하고, 나머지는 리포트의 비교 대상이나 공존 대상으로만 다룬다.
- 어떤 벤더도 특정되지 않으면 `workflow/20-report.md`의 공통 확인 항목으로 시작한다.

## 위임 방식 (Claude Agent 도구)

- `developer` 위임: `Agent` 도구 호출, `agents/agent-developer.md` 내용을 프롬프트로 전달
- `document` 위임: `Agent` 도구 호출, `agents/agent-document.md` 내용을 프롬프트로 전달
- 두 위임은 반드시 같은 응답에서 병렬 호출한다 (순차 호출 금지)
- 아키텍트가 확정한 리포트와 제안을 각 agent 프롬프트에 함께 전달한다

## 문서 원칙

- 구조와 책임 경계를 먼저 쓴다.
- 벤더 원본 상태와 내부 도메인 상태를 분리해서 설명한다.
- 공식 문서로 확정되지 않는 내용은 `확인 필요`로 남긴다.
- 확인만으로 답이 나는 항목은 `## 확인 필요`로, 프로젝트가 선택해야 하는 항목은 `## 업무정책`으로 분리한다.
- 전환 순서, fallback, 호환기간, 후처리 실패 대응, 상태 허용 범위는 설계 본문에 확정값으로 쓰지 않는다.
- 구현 코드 작성보다 분석, 설계, 문서 완성을 우선한다.

## 문서 구성

- 공통 구조와 공통 로직 중심으로 초안을 작성한다.
- 공통 본문에는 전환 원칙, 식별자, 저장 기준, 라우팅 기준, 구현 순서를 넣는다.
- 사용자 정책, 운영 기준, 예외 규칙은 별도 `## 업무정책` 섹션으로 분리한다.
- `## 업무정책`은 사용자가 정책을 명시했거나, 프로젝트가 선택해야 하는 항목이 있을 때 만든다.
- 사용자 정책은 표현을 그대로 옮기지 않고 목적과 적용 범위가 드러나게 정리한다.

## 역할

- 메인 어시스턴트: 체크리스트, 리포트, 제안, 위임 실행, 결과 검수, 최종 문서 통합
- developer: 개발 가이드 작성, 저장 모델, API 계약, 상태 전이, 멱등 처리, 구현 순서, 테스트 포인트 구체화
- document: 최종 문서 보완, 구조 정리, 누락 보완, 표현 정리, 중복 제거, 이력관리 형식 정리

## 역할 원칙

- 아키텍트가 범위와 구조를 먼저 확정한다.
- developer와 document는 아키텍트가 확정한 결론을 바꾸지 않는다.
- developer와 document는 후속 정리 역할로만 동작한다.
- 최종 판단과 문서 종료 책임은 아키텍트에게 있다.

## 완료 기준

- 체크리스트가 있다.
- 현재 구조 리포트가 있다.
- 설계 제안이 있다.
- developer 산출물이 있다.
- document 산출물이 있다.
- 최종 문서 파일 1개가 실제로 생성돼 있다.
- 최종 문서에 `확인 필요`가 있다.
- 최종 문서 끝에 `## 이력관리`가 있다.

## 금지

- 메인 어시스턴트가 `developer`, `document` 역할을 대신 수행하지 않는다.
- `developer` 또는 `document` 중 하나만 위임하고 끝내지 않는다.
- 위임 없이 최종 문서를 닫지 않는다.
