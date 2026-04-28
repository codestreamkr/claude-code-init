---
name: ct:calltree
description: Java 파일 호출 관계(Call Tree)를 분석하고 [TC:✅] 대상 여부를 판정해 callTree 문서를 생성한다. `$ct-calltree`, `ct-calltree`, `콜트리`, `호출 관계 분석`, `Call Tree 분석` 요청에 사용한다.
---

# Java Call Tree 분석

Java 파일(Controller/Service)의 메서드 호출 관계를 분석하여 Call Tree를 생성한다.
`[TC:✅]` 대상 여부를 최종 판정하는 것이 이 커맨드의 핵심 목적이다.

사용자 입력: $ARGUMENTS

## 분석 방식

### Controller 파일 입력 시
- 하위 호출만 분석: `Controller → Service → Mapper/DAO/외부연동` (기본 3depth)
- 최상위 레이어이므로 상위 호출 없음

### Service 파일 입력 시
- 상위 호출: 누가 이 Service를 호출하는지 검색
- 하위 호출: 메서드 본문에서 호출하는 Service/Mapper/DAO/외부연동 파싱

### 분석 대상 레이어
- Controller: @RestController, @Controller
- Service: @Service, Business Logic
- Util/Helper: 유틸리티, 헬퍼 클래스
- Mapper/DAO: 데이터 접근 계층

## 출력 표기 규칙

### Depth 규칙
- 기본 3depth. 전체 호출망의 full expansion은 하지 않는다.
- 각 `메서드별 호출 트리` 섹션은 루트 메서드를 depth1로 센다.
- depth2의 메서드는 본문을 열어 business-significant direct collaborator를 depth3으로 적는다.
- direct collaborator 범위: service/dao/mapper/helper/external 호출, 흐름에 영향을 주는 private helper
- 별도 노드로 늘리지 않는 것:
  - getter/setter, logging, 단순 컬렉션 add/filter
  - DTO 필드 세팅만 있는 구문, JDK/commons/gson 같은 범용 라이브러리 호출
- `[TC:✅]` depth2 메서드는 가능한 한 depth3을 채우되, 의미 있는 collaborator가 없으면 leaf로 두고 한 줄 요약만 남긴다.
- private helper가 depth2에 있으면 그 helper 안의 service/dao 호출도 같은 섹션에서 depth3으로 펼친다.
- 상세도는 섹션 안에서 맞춘다. 실제 메서드명과 설명문만의 혼합을 최소화한다.

### 선택적 심화
- 기본 3depth로 흐름 이해가 되면 거기서 멈춘다.
- 아래 중 하나면 특정 `[TC:✅]` 노드만 더 깊게 적을 수 있다:
  - private helper 체인이 2단계 이상 이어져 3depth만으로 의미가 끊기는 경우
  - 예외 삼킴, 후처리, 부수효과가 helper 안에 숨어 있는 경우
- 심화는 "그 노드의 테스트 경계가 보일 때까지"만 한다. 형제 노드까지 함께 펼치지 않는다.

### `[TC:✅]` 표기
- 테스트케이스 대상인 호출만 메서드명 앞에 `[TC:✅]` 접두사로 표기한다.
- 비대상 호출은 아무 표기도 하지 않는다. (`X`, `O` 문자 표기 금지)
- `[TC:✅]`는 후보가 아니라 최종 판정이다.
- `[TC:✅]`는 트리 본문 표기에서 끝나지 않는다. `[TC:✅] 노드 요약`에도 같은 호출을 구조화해서 남긴다.
- 예시:
  - `├─ [TC:✅] paymentService.findLimit()`
  - `├─ orderDao.insertOrderNormal()`

## `[TC:✅]` 판단 기준

### 대상 (`[TC:✅]`)
아래 중 하나라도 포함하면 대상 후보:
- 조건 분기 / 예외 처리 / 검증
- 데이터 가공 / 조합 / 반복
- 외부 연동 (API, MQ, 파일, 메일/SMS 등)
- 복수 컴포넌트 호출을 조합하는 오케스트레이션 로직
- 조회 후 후처리 (문자열 분해, DTO 필드 재구성, 합산/매핑)
- 예외를 삼키고 로그만 남기거나 기본값을 반환하는 메서드
- private helper라도 분기, DTO 조립, service 호출 제어를 담당하는 경우

### 비대상 (미표기)
아래에 **모두** 해당하면 제외:
- 내부 로직 없이 mapper/dao/service를 즉시 호출하고 반환
- 조건 분기, 데이터 변환/후처리, 예외 처리, 부수효과 없음

### 보정 규칙
1. **메서드 본문 기준으로 판단한다** — 호출자의 분기가 복잡해도 target 메서드 본문이 단순 위임이면 비대상일 수 있다.
2. **외부 조건과 내부 조건을 분리한다** — 외부 조건(호출 여부를 결정하는 상위 분기)이 복잡해도 본문이 단순하면 `[TC:✅]`는 상위 노드에 준다.
3. **단순 조회라도 후처리가 있으면 대상이다** — DAO 1회 호출이어도 결과를 분해/매핑/정규화하면 대상.
4. **애매하면 한 단계 더 추적한다** — 호출자/피호출자를 한 단계 더 보고 판단한다.

### 판정 체크리스트
1. 메서드 본문 안에 조건 분기/반복/예외 처리/외부연동/후처리가 있는가
2. 단순 조회/위임처럼 보여도 반환값 재가공이 있는가
3. 복잡성은 상위 호출자에만 있고 현재 메서드는 비어 있는가
4. 테스트를 만들었을 때 별도 가치가 있는가, 아니면 상위 흐름 테스트로 충분한가

→ 1, 2 중 하나가 명확하면 `[TC:✅]` 후보.
→ 3, 4가 모두 "상위에서만 의미 있음"이면 비대상.

### 자주 틀리는 오판
1. 상위 분기가 복잡하다는 이유만으로 하위 단순 조회 메서드를 `[TC:✅]`로 표시
2. 메서드가 실제로는 호출되는데 `NoCall` 성격의 테스트를 기준으로 대상 판단
3. 테스트 수를 맞추려고 단순 조회에 `[TC:✅]`를 부여
4. 단순 조회처럼 보여도 내부 후처리가 있는 것을 놓침
5. 예외를 잡고 무시하는 메서드를 단순 위임으로 잘못 분류
6. 운영코드에 없는 게이트를 가정해서 대상을 부풀림

## 실행 단계

1. 파일 타입 자동 감지 (`*Controller.java`, `*Service.java`)
2. 파일 위치 검색 및 내용 읽기
3. 메서드 시그니처 및 호출 관계 추출
4. Service인 경우 상위 호출자 검색
5. 각 호출 노드에 대해 `[TC:✅]` 여부를 판정
6. `[TC:✅]` 노드를 `[TC:✅] 노드 요약` 표에 구조화
7. 출력 파일 생성 (기존 파일이 있어도 전체를 새로 작성)
8. 초안 완료 후 기존 CallTree 문서가 있으면 누락/범위 차이만 점검

## [TC:✅] 노드 요약 작성 규칙

`[TC:✅]` 노드를 행 단위로 정리하는 분석 요약 표다.

| 필드 | 설명 |
|------|------|
| `nodeId` | 문서 안에서 안정적으로 참조할 식별자 |
| `callNode` | 실제 호출 표현 |
| `layer` | `controller`, `helper`, `service`, `utility`, `external`, `dao` |
| `family` | 역할 분류 (예: `precheck`, `mapping`, `payment`, `db-write`) |
| `bundle` | 의미적으로 하나의 단위를 이루는 호출 묶음 (예: `payment-core`, `trx-family`) |
| `branchType` | 호출자 관점에서 관찰되는 호출 조건 구조. 아래 branchType 작성 기준 참조 |
| `priority` | `critical`, `high`, `normal` |

### branchType 작성 기준

branchType은 **호출자(caller) 관점에서 관찰되는 호출 조건**만 기재한다.
대상 메서드 내부의 서비스 로직 분기는 기재하지 않는다.

| 기재 대상 (호출자 관점) | 예시 |
|------------------------|------|
| 호출 여부가 조건에 따라 달라지는 경우 | `normal/skip` |
| 선행 단계 실패로 호출되지 않는 경우 | `normal/exception` |
| 호출자의 if 분기로 호출 경로가 갈리는 경우 | `applicable/skip` |
| 보상 취소처럼 예외 시에만 호출되는 경우 | `compensation/skip` |

| 기재하지 않는 것 (메서드 내부 분기) | 이유 |
|-----------------------------------|------|
| `new/reuse/not-found` | 서비스 본문 안의 분기. 호출자 관점에서 관찰 불가 |
| `card/bank/pay/fallback` | 결제수단별 내부 분기. 서비스 내부 구조 |
| `use/skip/reject` | 정책별 내부 분기. 서비스 내부 구조 |

### 작성 원칙
- `family`와 `bundle`은 메서드명이 아니라 역할 기준으로 적는다.
- 트리 본문의 `[TC:✅]` 목록과 이 표의 `callNode`는 서로 일치해야 한다.
- 판정 근거는 `[TC:✅]로 본 메서드` 섹션에 서술한다. 표에는 넣지 않는다.

## 출력 파일 규칙

### 저장 위치 및 파일명
- 저장 위치: `.0_my/call-trees/`
- 기본: `callTree-{ClassName}.md`
- 필터 적용: `callTree-{ClassName}-{filter}.md`
  - filter는 파일명에 안전한 짧은 slug로 정리 (예: `v4`, `v1-order`)

### 필수 섹션
- 문서 정보
- 흐름 요약
- 메서드별 호출 트리
- [TC:✅] 노드 요약
- `[TC:✅]`로 본 메서드
- 비대상으로 둔 메서드
- 특이사항

## 출력 템플릿

```markdown
# {ClassName} 호출 흐름

## 문서 정보
- 대상 클래스: `{ClassName}`
- 소스: `{source-path}`
- 필터: `{filter-or-none}`
- 포함 메서드: `{method-list}`
- 작성 시각: `{timestamp}`
- 기준: 메서드 본문 기준으로 `[TC:✅]` 판정

## 흐름 요약
- `{entry-method-1}`
  `{summary}`

## 메서드별 호출 트리

### 1. `{entry-method}`

```text
[TC:✅] {entry-method}()
├─ ...
```

## [TC:✅] 노드 요약
| nodeId | callNode | layer | family | bundle | branchType | priority |
|---|---|---|---|---|---|---|
| N01 | `{callNode}` | `{layer}` | `{family}` | `{bundle}` | `{branchType}` | `{priority}` |

## `[TC:✅]`로 본 메서드
- `{callNode}`
  `{why-target}`

## 비대상으로 둔 메서드
- `{callNode}`
  `{why-not-target}`

## 특이사항
- `{note}`
```

## 서식 규칙
- A4 세로 인쇄 기준으로 가로 폭이 과하지 않게 정리한다.
- 한 줄 70~80자 안쪽으로 끊고, 짧은 문단과 명확한 줄바꿈을 우선한다.
- 표는 꼭 필요한 경우에만 사용하고, 열 수를 최소화한다.
- 표 없이 가능한 내용은 ASCII 트리, 번호 목록, 짧은 불릿으로 대체한다.
- 문서 톤은 짧고 자연스러운 한국어를 사용한다.

## 사용 예시
- `calltree OrderTrxController.java`
- `calltree OrderCancelController.java /v4/`
- 대용량 파일(2000줄 초과)은 엔드포인트 필터 사용 권장
