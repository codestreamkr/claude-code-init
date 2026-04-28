---
name: ct:calltreeTest
description: CallTree 문서 기반으로 [TC:✅] 호출 노드를 실제 소스 코드 분석으로 검증하는 Java 단위 테스트를 만든다. `$ct-calltreeTest`, `ct-calltreeTest`, `콜트리 테스트`, `단위 테스트 생성`, `callTree 기반 테스트` 요청에 사용한다.
---

# Java CallTree 기반 테스트 생성

CallTree 문서(`/ct:calltree` 산출물)와 실제 운영코드를 함께 읽고 `[TC:✅]` 호출 노드를 검증하는 Java 단위 테스트를 만든다.
속도보다 정확도를 우선한다.

사용자 입력: $ARGUMENTS

## 입력 형식

- `/ct:calltreeTest calltree-main.md`
- `/ct:calltreeTest calltree-main.md targetService.targetMethod()`

### 입력 해석
1. 첫 번째 인자는 CallTree markdown 파일명 또는 경로다.
2. 파일명이면 우선 `.0_my/call-trees/`에서 찾고, 없으면 저장소 전체에서 찾는다.
3. 두 번째 인자(`target-call`)가 있으면 해당 호출만 대상으로 한다.
4. `target-call`이 없으면 `[TC:✅]` 전체를 대상으로 한다.

## 핵심 원칙

1. 테스트 로직은 반드시 실제 소스 코드에서 추출한다. 조건식, 예외 흐름, 기대값을 추측으로 만들지 않는다.
2. 검증 포인트마다 근거 코드(클래스/메서드/라인)를 확인한다.
3. `[TC:✅]` 대상 선정 책임은 `/ct:calltree`에 있고, 이 커맨드는 선정된 대상을 정확히 테스트로 구현한다.
4. 운영코드상 테스트 필요도가 낮아 보여도 `[TC:✅]` 대상이면 테스트를 생성한다. 필요도 낮음 판단은 Javadoc이나 보조 문서에 메모로 남긴다.
5. 기존 저장소 테스트를 복제하지 않는다. 저장소 코드는 패키지/의존성/타입 적응 용도로만 참고한다.
6. CallTree의 3depth 트리는 범위 안내용이다. 대상 노드에 대해서는 실제 소스를 다시 열어 assertion이 닫히는 지점까지 추적한다.
7. 전체 파일의 full call graph를 다시 그리지 않는다. 대상 call 또는 bundle에 필요한 범위까지만 추적한다.
8. 테스트 메서드는 대상 운영 클래스에 대응하는 `*UnitTest.java`에만 존재한다. 같은 메서드를 다른 파일에 중복 생성하지 않는다. 기존 UnitTest에 이미 전용 메서드가 있으면 새로 만들지 않고 MainTest에서 참조한다.
9. **Controller 테스트 계층 규칙**:
   - **단순 위임**: Controller가 조건 분기·변환·후처리 없이 `service.method()` 호출만 하는 `[TC:✅]` 노드는 `*ControllerUnitTest`를 만들지 않는다. `*ServiceUnitTest`에 작성하고, MainTest도 `ServiceUnitTest`를 직접 참조한다.
   - **Controller 고유 로직 존재**: Controller에 호출 조건 분기, private helper, 예외 보상 등 고유 로직이 있으면 `*ControllerUnitTest`를 생성한다. 단, **엔드포인트 메서드 전체를 호출하지 않는다.** Controller 고유 로직 지점만 직접 테스트한다:
     - 호출 조건 분기(외부 조건) → 조건 true/false별 service 호출 여부 검증
     - private helper → `ReflectionTestUtils.invokeMethod()`로 직접 호출
     - 예외 시 보상 호출 → 예외 상황 재현 후 보상 메서드 호출 검증
   - **이유**: 엔드포인트 전체 호출(`controller.reqClaimV4(...)`)은 MainTest의 오케스트레이션과 겹치고, 내부 service를 전부 mock해야 해서 테스트 의미가 희석된다.

## 테스트 명명 규칙

| 케이스 | 패턴 | 예시 |
|--------|------|------|
| 정상 호출 | `{methodName}_Test` | `checkProductStock_Test` |
| 외부 조건 미충족 | `{methodName}_{사유}_NoCall` | `checkPayment_PaymentTypeMismatch_NoCall` |
| 내부 하위 호출 생략 | `{methodName}_{사유}_NoServiceCall` | `sendReceipt_NoReceiptCondition_NoServiceCall` |
| 예외 삼킴 | `{methodName}_{예외}_{결과}` | `insertHistory_InsertException_LogsErrorAndReturnsDto` |

구체적 사유가 있으면 `NotApplicable_NoCall`보다 구체 이름을 선호한다.

## 테스트 쌍 구조

각 `[TC:✅]` 노드마다 최소 아래 쌍을 기본 생성한다:
- `{methodName}_Test` — 정상 호출 검증
- `{methodName}_{사유}_NoCall` — 외부 조건 false로 호출 안 됨 검증

내부 분기가 있으면 `_NoServiceCall`, `_Skip` 등 추가 케이스를 만든다.

### `_NoCall` vs `_Throws*` 판단 흐름

```
호출자(controller/상위 service)에 if/조건분기가 있어
대상 메서드 자체가 불리지 않는 경우가 존재하는가?
  ├─ YES → `_NoCall` 케이스 필수 생성
  └─ NO  → `_NoCall` 생략 가능

대상 메서드 내부에서 예외를 던지는 분기가 있는가?
  ├─ YES → `_Throws*` 케이스 생성
  └─ NO  → 생략

둘 다 존재하면 `_NoCall` + `_Throws*` 모두 생성한다.
```

- 외부 조건 유무는 반드시 **호출자 코드**에서 확인한다. CallTree만 보고 판단하지 않는다.
- 외부 조건이 없어서 `_NoCall`을 생략할 때는, 내부 분기 케이스(`_Throws*`, `_NoServiceCall`, `_Skip` 등)가 반드시 1개 이상 있어야 한다.

## 시그니처 페어 규칙

MainTest가 `reqJson`을 넘겨 UnitTest 메서드를 호출하는 흐름에서는 아래 페어를 필수로 만든다.

```java
@Test
public void targetMethod_Test() throws Exception {
    targetMethod_Test(TestResourceLoader.loadOrderCreateBase());
}

public void targetMethod_Test(Map<String, Object> reqJson) throws Exception {
    // 실제 검증 로직
}
```

- 이 규칙은 `_Test`, `_NoCall`, `_NoServiceCall`, `_Throws*` 케이스 모두에 동일 적용한다.

## Mock 초기화 패턴

```java
@Before
public void setUp() {
    targetService = new TargetServiceImpl();
    dependency = mock(DependencyClass.class);
    ReflectionTestUtils.setField(targetService, "dependency", dependency);
}
```

- `@Before`에서 대상 서비스를 `new`로 생성, 의존성은 `mock()` + `ReflectionTestUtils.setField()`로 주입한다.
- Spring context(`@Autowired`)는 사용하지 않는다.

## Shared Fixture 규칙

### 적용 조건
- 여러 테스트가 같은 header/body/payment/meta 구조를 공유할 때
- call-site 분기가 입력 JSON/Map에 의해 결정될 때
- 같은 `fixtureGroup`(§테스트 전략 결정 규칙)에 노드가 2개 이상이면 shared fixture 기본 적용

### fixtureStrategy 해석
- `shared-request`: 공통 request fixture를 먼저 만들고, helper는 꼭 필요한 최소 범위만 둔다.
- `shared-helper`: 공통 request fixture와 `applyXTrigger`, `executeXIfApplicable` helper를 함께 설계한다. helper는 운영코드 분기 재현용으로만 쓰고, 테스트 전용 게이트를 추가하지 않는다.

### 기본 파일
- `src/test/resources/{domain}/{entrypoint}/base-request.json`
- UnitTest는 반드시 base-request.json을 로드하여 입력을 구성한다. `new VO() + setter` 하드코딩 금지.
- 테스트별 조건 변경은 Map에서 값을 덮어쓴 뒤 VO로 변환하는 방식으로 처리한다.

### 기본 helper 패턴

```java
private boolean isTargetApplicable(Map<String, Object> reqJson) { ... }

private void applyTargetTrigger(Map<String, Object> reqJson) { ... }

private ReturnType executeTargetIfApplicable(Map<String, Object> reqJson) { ... }

private void applySecondaryTrigger(Map<String, Object> reqJson) { ... }

private ReturnType executeSecondaryIfApplicable(Map<String, Object> reqJson) { ... }
```

### helper 규칙
1. helper는 실제 호출 구조를 재현하기 위한 최소 범위로만 만든다.
2. helper 안에 운영코드에 없는 외부 게이트를 새로 만들지 않는다.
3. negative 케이스도 가능하면 helper를 실제로 실행한다.
4. helper가 `null`, `emptyList`, `0` 등을 반환하는 경우 그 의미가 운영코드 분기와 맞아야 한다.
5. `shared-helper` 전략이면 helper 이름도 실제 call family가 드러나게 유지한다.
6. fixture 하나로 2개 이상 call family를 재현할 수 있게 설계한다.

좋은 예: `executeLookupIfApplicable(req)`가 조건 미충족 시 `null` 반환
나쁜 예: 운영 메서드는 항상 호출되는데 helper가 임의로 호출을 차단

## 로그 패턴

- `[TAG][STEP]` 형식을 사용한다.
- production method 호출 직전에 `[➡️ CALL]` 로그를 반드시 남긴다.
- negative 케이스에서도 미호출/생략 결과가 로그로 드러나야 한다.
- 내부 로직이 있으면 단계 의미가 드러나는 로그를 남긴다.
- **모든 `@Test` 메서드에 적용한다.** UnitTest, Controller 직접 호출, `ReflectionTestUtils.invokeMethod` 모두 동일.

### 호출 직전 로그

```java
log.info("[DOMAIN_TEST][TARGET_METHOD][➡️ CALL] service.targetMethod(arg1={}, arg2={}) 호출 직전",
        arg1, arg2);
```

### 단계 로그 대표 태그

| 태그 | 사용 시점 |
|------|-----------|
| `[BASE_MAPPING]` | 기본 필드 매핑 단계 |
| `[DTO_MAPPING]` | DTO 조립/변환 단계 |
| `[REQUEST_PARAM]` | 요청 파라미터 확인 |
| `[SUM]` | 합산/집계 결과 |
| `[NO_SERVICE_CALL]` | 내부 조건으로 하위 서비스 호출 생략 |
| `[EXPECTED_ERROR_LOG]` | 의도적 예외 삼킴 케이스에서 error 로그 |

## 노드 완료 게이트

노드 1개의 처리가 "끝났다"고 판정하려면 아래 항목을 모두 통과해야 한다.

1. **독립 테스트 존재**: 해당 노드 전용의 `@Test` 메서드가 `*UnitTest.java`에 존재하는가. 다른 노드의 `verify()`로 간접 확인한 것은 불인정.
2. **테스트 쌍 완성**: `_Test` + negative 케이스가 모두 존재하는가 (§테스트 쌍 구조)
3. **시그니처 페어 완성**: MainTest가 파라미터 호출을 사용하면 페어가 존재하는가 (§시그니처 페어 규칙)
4. **소스 근거 확인**: 각 assertion에 대응하는 운영코드 위치(클래스:라인)를 특정할 수 있는가
5. **assertion 닫힘**: 호출 여부, 파라미터 매핑, 분기 결과, side effect 중 해당되는 것이 모두 검증되었는가
6. **로그 패턴 적용**: 모든 `@Test`에 `[TAG][STEP]` 로그가 있는가 (§로그 패턴)
7. **명명 규칙 준수**: 메서드 이름이 §테스트 명명 규칙에 맞는가
8. **ArgumentCaptor 판단**: mapping/조립 계열이면 캡처 기반 검증, 단순 위임이면 매처 허용. 애매하면 캡처 사용.
9. **fixture 사용 확인**: shared fixture가 존재하는 흐름이면 base-request.json에서 파생되었는가

## 테스트 전략 결정 규칙

CallTree 문서에는 분석 결과만 있고, 테스트 전략은 이 스킬이 아래 규칙으로 결정한다.
각 규칙에는 우선순위가 있으며, 충돌 시 상위 규칙이 이긴다.

### 1. mainTestClass

1. 기존 `*MainTest.java`가 있으면 그 파일을 우선 사용한다.
2. 없으면 엔트리포인트 메서드의 소속 클래스 기준으로 `{RootClassName}MainTest`를 만든다.
3. Controller가 단순 위임이어도 MainTest 이름은 엔트리포인트 기준으로 유지한다.
4. 후보가 둘 이상이면 기존 Javadoc, `testNN_*` 구성, 호출 대상 일치율이 가장 높은 파일을 택한다.

우선순위: **기존 파일 > 명명 규칙**

### 2. fixtureStrategy

1. 기존 `base-request.json`이 있으면 `shared-request`로 본다.
2. 노드 2개 이상이 같은 요청 JSON 골격을 공유하면 `shared-request`.
3. VO/Map 공통 빌더나 helper 메서드 재사용만 필요하면 `shared-helper`.
4. 노드마다 입력 구조가 실질적으로 다르면 `none`.

우선순위: **기존 fixture > 입력 구조 공유도**

**입력 구조 동일의 기준:** 같은 `base-request.json` 하나에서 두 노드의 입력을 모두 파생할 수 있으면 동일. 별도 fixture 파일이 필요하면 다름.

### 3. fixtureGroup

1. 기본값은 `bundle`과 동일하게 시작한다.
2. 같은 bundle 안에서도 입력 구조가 다르면 그룹을 분리한다.
3. 다른 bundle이어도 같은 request fixture를 그대로 공유하면 같은 그룹으로 묶는다.

우선순위: **입력 구조 일치 > bundle 이름**

### 4. mainTestGroup

1. 같은 `bundle`은 같은 `testNN_*` 묶음으로 둔다.
2. 한 bundle 안에 성격이 완전히 다른 노드가 섞이면 `family` 기준으로 분리한다.
3. 새 그룹 번호는 기존 MainTest의 마지막 `testNN_*` 다음 번호를 쓴다.

우선순위: **bundle > family > source order**

## 기본 워크플로우

### Phase 0: 대상 목록 생성 (필수, 최초 1회)

1. CallTree에서 아래 섹션을 제목 기준으로 찾아 읽는다:
   - `[TC:✅] 노드 요약` → 대상 노드 목록과 분석 속성 확인
     (읽는 필드: nodeId, callNode, layer, family, bundle, branchType, priority)
   - `메서드별 호출 트리` → 호출 흐름 파악
   - `특이사항` → 분석 시 발견된 주의 사항 확인
   `[TC:✅] 노드 요약`이 없으면 트리의 `[TC:✅]` 표기를 기준으로 fallback 진행하되,
   범위 판단이 약해질 수 있음을 짧게 알린다.
2. **테스트 전략 결정** — §테스트 전략 결정 규칙에 따라 mainTestClass, fixtureStrategy, fixtureGroup, mainTestGroup을 결정한다.
3. 기존 테스트/관련 소스/문서 위치를 병렬 수집한다.
4. **기존 MainTest 탐색:**
   - 대상 엔트리포인트에 대응하는 기존 `*MainTest.java`를 검색한다 (파일명, 클래스 Javadoc, `@Test` 구성으로 판별).
   - 결정한 `mainTestClass`와 기존 MainTest 파일명이 다르면:
     - **기존 MainTest가 존재하면 기존 파일을 갱신 대상으로 확정한다.** 결정한 이름으로 신규 생성하지 않는다.
     - 불일치 사실을 사용자에게 알린다: `"mainTestClass={결정명} ≠ 기존={파일명} → 기존 파일 갱신으로 진행"`
   - 기존 MainTest가 없을 때만 결정한 `mainTestClass` 이름으로 신규 생성한다.
5. **대상 목록을 생성한다:**
   - `[TC:✅]` 전체 노드를 나열한다
   - **Controller 위임 판별**: 각 노드의 호출자가 Controller이면 Controller 코드를 확인한다. 단순 위임이면 `대응 UnitTest`를 `*ServiceUnitTest`로 매핑한다. Controller 고유 로직이 있을 때만 `*ControllerUnitTest`로 매핑한다.
   - 기존 `*UnitTest.java`에 전용 메서드가 있고 게이트 충족 → `reuse`
   - 전용 메서드가 있으나 게이트 미충족 → `supplement`
   - 전용 메서드가 없음 → `new`
   - `new`/`supplement` 노드에만 순번(M01, M02, ...)을 부여
   - 노드별로 `nodeId`, `callNode`, `대상 클래스`, `bundle`, `priority`, `대응 UnitTest`, `상태`를 표로 정리
   - 같은 UnitTest 파일의 노드는 연속 순번으로 배치
6. **목록을 사용자에게 출력하고 즉시 Phase 1로 진행한다.**
7. fixture 설계: 같은 `fixtureGroup`에 노드가 2개 이상이면 shared fixture 기본 적용.

### Phase 1: 노드별 처리 (반복)

대상 목록의 M01부터 순서대로 아래를 반복한다:

1. **운영코드 읽기** — 대상 메서드의 실제 소스를 열어 아래를 확정한다:
   - 대상 호출이 실행되는 외부 조건 (호출자 코드에서 확인)
   - 대상 메서드 내부의 분기와 후처리
   - 예외 처리 방식
   - 3depth에 보이지 않는 private helper/service 연쇄가 있으면 assertion이 닫히는 지점까지 추가 추적
2. **테스트 대상 호출 방식 결정:**
   - **Controller 위임 판별 (최우선)**: 대상 노드가 Controller에서 호출되면, Controller 코드를 열어 단순 위임인지 확인한다.
     - 단순 위임(조건 분기·파라미터 변환·후처리 없이 `service.method()` 호출만) → `ServiceUnitTest`에 테스트 작성. `ControllerUnitTest` 생성하지 않음.
     - Controller에 의미 있는 분기·변환·예외 처리 존재 → `ControllerUnitTest`에 해당 로직 테스트 작성.
   - service/public 메서드 → 직접 호출
   - controller private helper(Controller 고유 로직이 있는 경우만) → `ReflectionTestUtils.invokeMethod(...)` 로 직접 호출
   - 엔드포인트 메서드 전체 호출로 우회하지 않는다
3. **테스트 코드 작성** — §테스트 쌍 구조에 따라 생성. 하드코딩 VO 생성 금지.
4. **노드 완료 게이트 확인** — 전 항목 점검
5. **완료 보고 후 즉시 다음 노드로 이동한다.** 사용자가 개입하면 그때 멈춘다.

### Phase 2: 마무리 (모든 노드 완료 후)

1. MainTest를 `mainTestGroup` 기준으로 `testNN_*` 묶음으로 생성/갱신한다.
2. 보조 문서를 `.0_my/call-trees/{MainTestClass}_YYYYMMDD_HHMMSS.md`에 생성/갱신한다.
3. 가능한 범위에서 `test-compile` 또는 실제 실행 검증을 수행한다.

**Phase 2는 모든 노드가 완료된 후에 한번에 수행한다.**

## 처리 전략

### 기본 모드: 순차 단건 처리

기본 동작은 **노드 1개를 온전히 닫고 → 완료 보고 → 즉시 다음 노드**다.

### 병렬 모드: `--parallel` 옵션

사용자가 명시적으로 `--parallel`을 지정했을 때만 Agent 도구로 병렬 처리한다.

- Agent 1개 = 노드 1개. 같은 UnitTest 파일에 들어갈 노드는 1개 Agent가 처리한다.
- shared fixture와 MainTest는 메인 흐름에서만 생성/수정한다.
- 각 Agent에게 담당 노드, UnitTest 경로, fixture 경로, 스킬 규칙을 전달한다.
- Agent는 `*UnitTest.java`, 메서드명 목록, assertion-근거 매핑, 게이트 자체 점검 결과를 반환한다.
- 메인 흐름에서 게이트 통과 여부와 누락 노드를 검수한다. 미통과 시 수정 또는 재실행.

## 재탐색 정지 조건

아래가 모두 확보되면 더 깊게 내려가지 않는다:
1. 대상 메서드 호출 여부를 검증할 수 있다.
2. 주요 파라미터 매핑을 assertion으로 표현할 수 있다.
3. 내부 skip/default/예외 branch를 테스트 이름과 검증으로 닫을 수 있다.
4. 최종 side effect 또는 후처리 결과가 확인된다.

하나라도 부족하면 추적을 계속한다.

## benchmark commit 처리

사용자가 `git > <commit>` 또는 "어느 커밋 수준만큼" 같은 기준을 주면:

1. `git show --stat`, `git show --name-only`로 benchmark commit의 산출물 구조를 확인한다.
2. benchmark commit이 포함하는 산출물 층위(fixture, UnitTest, MainTest, 보조 문서)에 맞춘다.
3. benchmark commit이 없으면 기본 완료 단위(call 1개)를 유지한다.

## MainTest 템플릿

```java
@FixMethodOrder(MethodSorters.NAME_ASCENDING)
public class {FlowName}MethodMainTest {

    private Map<String, Object> reqJson;

    @Before
    public void setUp() {
        reqJson = TestResourceLoader.load{FixtureName}Base();
    }

    /**
     * 현재 반영 범위: {family1}, {family2}, {family3}
     * benchmark 수준 작업이면 최소 4개 이상의 testNN_* 묶음을 둔다.
     */

    @Test
    public void test01_{shortCallName}() {
        {UnitTestClass} ut = new {UnitTestClass}();
        ut.setUp();
        ut.{testMethod1}(reqJson);

        {UnitTestClass} ut2 = new {UnitTestClass}();
        ut2.setUp();
        ut2.{testMethod2}(reqJson);
    }

    @Test
    public void test02_{anotherCallFamily}() {
        {UnitTestClass2} ut = new {UnitTestClass2}();
        ut.setUp();
        ut.{testMethod3}(reqJson);

        {UnitTestClass2} ut2 = new {UnitTestClass2}();
        ut2.setUp();
        ut2.{testMethod4}(reqJson);
    }
}
```

### MainTest 고정 규칙
1. `@FixMethodOrder(MethodSorters.NAME_ASCENDING)` + `test01_...` 형태 사용
2. 번호는 CallTree 순서 기준
3. `@Before`에서 공통 fixture(`reqJson`)를 한 번 로드한다.
4. 각 `testNN_*`에서 UnitTest 인스턴스를 만들고 `setUp()` 후 테스트 메서드를 직접 호출한다.
5. partial 상태면 클래스 Javadoc에 현재 반영 범위를 명시
6. benchmark 수준 작업이면 최소 4개 이상의 `testNN_*` 묶음을 목표로 한다.
7. 각 `testNN_*`는 call 하나만이 아니라 branch family 또는 call family 묶음을 대표하도록 잡는다.
8. MainTest가 `reqJson`을 넘겨 호출하는 UnitTest 메서드는 `xxx()` + `xxx(Map<String,Object>)` 오버로드 페어를 갖춰야 한다.

## MainTest 보조 문서 템플릿

```md
# {MainTestClass} 흐름 정리

## 문서 정보
- 대상 테스트:
  `{relative-path-to-main-test}`
- 관련 운영 코드:
  `{relative-path-to-controller-or-service}`
- 관련 엔드포인트:
  `{entrypoint-or-flow}`
- 작성 시각:
  `{timestamp}`

## 개요
이 클래스는 `{entryMethod}` 컨트롤러를 통째로 호출하는 통합 테스트가 아니라,
{흐름} 오케스트레이션에서 핵심 호출 노드를 번호 순서로 묶어 실행하는
메인 테스트 오케스트레이터다.

- `@FixMethodOrder(MethodSorters.NAME_ASCENDING)`으로
  `test01`부터 `testNN`까지 순차 실행한다.
- 각 `testNN_*` 메서드는 대응 UnitTest를 직접 생성하고
  `setUp()` 후 `_Test(reqJson)`/negative 케이스를 순서대로 호출한다.
- MainTest가 호출하는 UnitTest 메서드는 `xxx(Map<String,Object>)`와 무파라미터 `@Test` 페어를 함께 유지한다.

## 공통 실행 흐름
{MainTestClass}
└─ testNN_*()
   ├─ reqJson fixture 준비(@Before)
   ├─ UnitTest 인스턴스 생성
   ├─ setUp() 호출
   ├─ _Test(reqJson) 호출
   └─ negative 케이스(reqJson) 호출

## 흐름 트리
{MainTestClass}
├─ 1. {그룹명}
│  ├─ test01_{methodName} -> {service}.{method}()
│  │  ├─ {UnitTestClass}#{methodName}_Test
│  │  │  └─ {정상 케이스 검증 의도}
│  │  └─ {UnitTestClass}#{methodName}_{사유}_{Throws*|NoCall}
│  │     └─ {예외/미호출 케이스 검증 의도}
│  └─ test02_{methodName} -> {service}.{method}()
│     ├─ ...
│     └─ ...
└─ N. {그룹명}
   └─ ...

## 단계별 해석
### 1. MainTest 역할
### 2. 유지된 커버리지
### 3. 별도 점검 필요 항목
### 4. 권장 보강 시나리오
```

### 보조 문서 고정 규칙
1. partial이면 그 사실을 문서에도 표시
2. 각 `testNN_*`는 `callNode -> 하위 테스트 메서드 -> 검증 의도`까지 적는다
3. 메인 테스트 번호 순서는 CallTree 순서를 따른다
4. CallTree의 `bundle`, `priority`, `mainTestGroup` 정보가 있으면 문서에도 같은 기준을 드러낸다
5. 흐름 트리에서 각 testNN 하위에 UnitTest 메서드명과 검증 의도를 한 줄씩 기재한다
6. "유지된 커버리지"는 흐름 트리의 그룹 단위로 커버 범위를 요약한다
7. "별도 점검 필요 항목"은 현재 MainTest가 커버하지 못하는 영역을 명시한다
8. "권장 보강 시나리오"는 추가 테스트로 고정 회귀에 포함할 만한 구체적 조건을 나열한다

## 외부 조건 vs 내부 조건

### 외부 조건
- 호출자(controller, 상위 service, helper)의 분기에서 대상 메서드 호출 자체를 막는 조건
- 외부 조건이 false이면 대상 메서드는 실행되지 않는다
- **이 경우만 `..._NoCall` 이름을 쓴다**

### 내부 조건
- 대상 메서드 본문에 진입한 뒤 내부 service/DAO/side effect 실행을 막는 조건
- 대상 메서드는 호출되므로 `NoCall`을 쓰지 않는다
- 내부에서 생략되는 내용을 이름에 드러낸다 (`_NoServiceCall`, `_Skip` 등)

## 자주 틀리는 패턴

1. MainTest는 파라미터 호출인데 UnitTest 오버로드 페어(`xxx(Map<String,Object>)`)가 없는 상태
2. 실제 사유가 있는데도 무조건 `NotApplicable_NoCall` 남발
3. negative 케이스가 `applicable=false`만 보고 끝남 — helper까지 실제로 실행해야 한다
4. 예외 삼킴 테스트인데 error 로그가 의도된 것임이 이름/Javadoc/로그에 드러나지 않음
5. 같은 엔드포인트 흐름인데 fixture 없이 테스트마다 입력 구조를 흩어 씀
6. CallTree와 실제 코드가 충돌하는데 독자적으로 대상을 제외하거나 추가

피해야 할 이름 패턴:
- 실제 사유가 있는데도 무조건 `NotApplicable_NoCall`
- 운영코드에 없는 외부 조건을 helper에 추가한 이름
- 실제로는 메서드가 호출되는데 `NoCall`로 끝나는 이름

## 최종 체크리스트

1. 외부 조건을 실제 호출자 코드에서 찾았는가
2. 내부 조건을 대상 메서드 본문에서 찾았는가
3. negative 케이스가 helper 실행까지 포함하는가
4. 이름이 실제 사유를 드러내는가
5. `[➡️ CALL]` 로그가 production method 직전에 있는가
6. 내부 로직이 있으면 단계 로그가 있는가
7. MainTest와 보조 문서까지 동기화했는가
8. 필요도 낮음 판단이 있으면 테스트는 생성했고 메모도 남겼는가
9. 같은 흐름을 여러 테스트가 공유하면 fixture/helper가 정리됐는가

## Contract Audit 보고 형식

Phase 2 완료 후 아래 형식으로 결과를 보고한다.

```md
## 입력 계약 확인
- callTree 문서: `{calltree-path}`
- entryFlow: `{entry-flow}`
- completionUnit: `{completion-unit}`
- mainTestClass: `{MainTestClass}`
- fixtureStrategy: `{fixture-strategy}`

## bundle 우선순위
| bundle | family | priority | mainTestGroup | status | notes |
|---|---|---|---|---|---|
| `{bundle}` | `{family}` | `{priority}` | `{mainTestGroup}` | `{pending|done}` | `{note}` |

## 산출물 계획
- UnitTest 대상 클래스: `{class}`
- MainTest: `{MainTestClass}`
- fixture: `{fixture-path-or-none}`
- 보조 문서: `{doc-path}`

## 적용한 원본 코드 조건
- [`{class}.java:{line}`]: `{external-condition-or-entry-guard}`
- [`{class}.java:{line}`]: `{internal-branch-or-post-processing}`

## 생성·갱신한 테스트 메서드
- `{UnitTestClass}#{testMethod}` — callNode: `{callNode}`, 의도: `{why}`
- `{MainTestClass}#{testNN_method}` — family: `{family}`

## assertion 근거 매핑
| testMethod | assertion 요약 | 근거 코드 |
|---|---|---|
| `{testMethod}` | `{assertion-summary}` | `{class}.java:{line}` |

## 검증 결과
- 명령: `{test-compile or run command}`
- 결과: `{passed|failed|skipped}`
- 메모: `{note}`

## 필요도 낮음 판단 메모
- 노드: `{callNode-or-none}`
- 반영 위치: `{javadoc-or-doc-path}`
- 메모: `{note}`

## audit 메모
- 비어 있는 critical bundle: `{bundle}`
- 이번에 닫은 family: `{family-list}`
- 다음 generation 후보: `{bundle-list}`
```

## 완료 기준

1. 모든 노드가 §노드 완료 게이트를 통과했을 때 전체 완료다.
2. MainTest는 partial이어도 되지만, 현재 반영 범위가 바로 실행 가능해야 한다.
3. 테스트 파일만 추가한 상태를 완료로 보지 않는다. MainTest, 보조 문서까지 함께 맞아야 한다.
4. 기존 파일을 수정한 경우, 해당 파일이 git staging에 포함되었는지 확인하고 누락 시 경고한다.

## 실패 대응

1. 파일 읽기나 코드 검색이 가능하면 사용자 확인 없이 직접 수행한다.
2. 빌드/테스트 실패 시 우회한다:
   - PowerShell 인자 이슈 → `mvn.cmd`
   - 인코딩 이슈 → UTF-8 옵션
   - 실행 스킵 → `test-compile`로 최소 검증
3. 우회 경로가 남아 있으면 멈추지 않는다. 정말 불가능할 때만 사용자 검증으로 전환한다.

## 금지 항목

1. Controller 엔드포인트를 직접 호출해 우회 검증하는 방식
2. 코드 근거 없이 mocking/stubbing을 과도하게 추가하는 방식
3. CallTree만 보고 실제 코드 확인 없이 테스트를 생성하는 방식
4. 기존 테스트를 임의 삭제하거나 대체하는 방식
5. 운영코드에는 없는 외부 조건을 테스트 helper에 추가하는 방식
6. CallTree와 실제 코드가 충돌할 때 독자적으로 대상을 제외하거나 추가하는 방식
7. `@Test` 메서드에서 `[TAG][STEP]` 로그를 생략하는 방식
8. 같은 테스트 메서드를 여러 UnitTest 파일에 중복 생성하는 방식
9. 동일 엔트리포인트에 기존 MainTest가 있는데 계약 `mainTestClass` 이름이 다르다는 이유로 신규 MainTest를 생성하는 방식
10. Controller가 Service에 단순 위임하는 노드에 대해 `*ControllerUnitTest`를 생성하는 방식. 이 경우 반드시 `*ServiceUnitTest`에 작성한다.
