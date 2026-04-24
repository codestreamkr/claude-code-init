---
name: ct:spring-mvc
description: Spring MVC 구성 패턴 전문 지식. 요청 매핑·바인딩·검증·예외 응답·직렬화·파일 업로드·상태 코드·웹 계층 경계를 다룬다. 환경과 기존 컨벤션을 먼저 파악한 뒤 프로젝트 방식에 맞게 적용한다.
---

# Spring MVC 구성 패턴

---

## 환경 감지 — 코드 작성 전 필수 확인

| 확인 항목 | 위치 / 기준 |
|---|---|
| 빌드 도구 | `pom.xml` 존재 → Maven / `build.gradle` 존재 → Gradle |
| Spring Boot / Framework 버전 | Boot 버전, `spring-webmvc` 포함 여부 |
| 패키지 구조 | `controller`, `api`, `web`, `presentation` 등 웹 계층 위치 |
| Controller 스타일 | `@RestController` 중심인지, `@Controller`와 뷰 렌더링이 섞여 있는지 |
| 공통 응답 포맷 | 공통 성공/실패 응답 래퍼 존재 여부 |
| 검증 방식 | `@Valid`, `@Validated`, 커스텀 validator 사용 여부 |
| 예외 처리 구조 | `@ControllerAdvice`, `ErrorResponse`, 예외 코드 enum 존재 여부 |
| Jackson 설정 | 날짜 포맷, enum 직렬화, null 노출 정책 |
| 파일 처리 방식 | multipart 설정, 다운로드 응답 헤더 패턴 |
| 연관 데이터 접근 | Service 뒤가 JPA인지 MyBatis인지, 혼합인지 |

감지 결과에 따라 MVC 코드의 형태가 달라진다. 버전과 기존 패턴이 다르면 기본 예시를 그대로 쓰지 않는다.

### 적용 절차 — 이 스킬의 코드를 읽는 방법

1. 환경 감지에서 Boot 버전, 웹 계층 구조, 공통 응답/예외 처리 방식을 먼저 확인
2. 기존 Controller, DTO, `@ControllerAdvice` 한두 개를 읽고 프로젝트의 API 계약을 파악
3. 데이터 접근이 얽히면 Service 뒤가 JPA인지 MyBatis인지 확인하고 해당 스킬로 이어갈 준비를 한다
4. MyBatis가 붙고 SQL 자체가 복잡하거나 성능 이슈가 보이면 `query-tuner` 관점 검증까지 염두에 둔다

이 절차를 건너뛰면 URL은 맞아도 검증 메시지, 응답 포맷, 상태 코드가 프로젝트 기준과 어긋난다.

---

## 이 스킬의 범위

이 스킬은 **Spring MVC 분야의 구현 문법·패턴**만 담당한다. 서비스 경계, 데이터 접근 선택, 아키텍처 판단은 `spring` 에이전트가 맡는다.

**다루는 것 (MVC 구현 문법·패턴)**
- `@RequestMapping`, `@GetMapping`, `@PostMapping` 등 요청 매핑
- `@RequestBody`, `@ModelAttribute`, `@RequestParam`, `@PathVariable` 선택
- 요청 DTO, 검증, 바인딩 에러 처리
- `@ControllerAdvice`, 상태 코드, 공통 에러 응답
- Jackson 직렬화, 파일 업로드/다운로드 응답, 캐시 헤더

**다루지 않는 것 (spring 에이전트 또는 다른 스킬 영역)**
- Controller와 Service 책임을 어디까지 나눌지에 대한 최종 판단
- JPA / MyBatis 선택과 데이터 접근 구현 세부
- Security 체인 설계와 인증 방식 선택
- WebFlux, 가상 스레드, 장시간 스트리밍 처리
- 게이트웨이 라우팅, 대규모 API 버저닝 정책

판단·설계 질문이 들어오면 에이전트가 먼저 정리한 뒤, 구현 단계에서 이 스킬을 참고한다.

**연계 기준**
- 데이터 접근 구현이 필요하면 JPA 또는 MyBatis 스킬로 이어간다
- MyBatis와 연결된 SQL이 복잡하거나 성능 검토가 필요하면 `query-tuner` 관점으로 확장한다
- 어떤 스킬을 거치더라도 최종 응답 계약과 서비스 흐름 정리는 다시 `spring` 에이전트가 맡는다

---

## 진단 플로우

1. **요청 매핑부터** — 경로, HTTP 메서드, consumes/produces가 맞는지 확인
2. **바인딩 경로 확인** — `@RequestBody`, `@ModelAttribute`, `@RequestParam` 중 무엇이 실제 입력과 맞는지 확인
3. **검증 흐름 확인** — `@Valid` 누락, 그룹 검증, 메시지 포맷을 점검
4. **예외 응답 확인** — `@ControllerAdvice`가 공통 응답 규약을 제대로 타는지 확인
5. **응답 DTO 확인** — Entity 직접 반환인지, DTO 변환 위치가 적절한지 확인
6. **직렬화 규칙 확인** — 날짜, enum, null 노출 정책이 기대 응답과 맞는지 확인
7. **연관 계층 확인** — 문제의 원인이 MVC인지 Service/JPA/MyBatis인지 경계를 나눠 본다

---

## 수치 감각

- **API 응답 시간** — 일반 CRUD는 수백 ms 안쪽을 기본 기대치로 본다
- **파일 업로드** — 컨트롤러에서 직접 저장 로직을 길게 들고 가지 않는다
- **검증 실패 응답** — 필드 오류와 비즈니스 오류 포맷은 구분하되 전체 구조는 맞춘다
- **상태 코드 선택** — 400, 404, 409, 422, 500을 구현 편의가 아니라 오류 책임 기준으로 나눈다

---

## 요청 매핑 패턴

### 기본 원칙

- 컬렉션과 단건의 경로를 섞지 않는다
- 동작을 드러내는 동사 경로보다 자원과 HTTP 메서드 조합을 먼저 본다
- `Pageable`이나 검색 조건이 커지면 요청 객체로 묶는 편이 낫다

### 예시

```java
@RestController
@RequestMapping("/api/orders")
public class OrderController {

    @GetMapping("/{orderId}")
    public OrderResponse get(@PathVariable Long orderId) {
        return orderService.get(orderId);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public OrderResponse create(@Valid @RequestBody CreateOrderRequest request) {
        return orderService.create(request);
    }
}
```

---

## 바인딩과 검증 패턴

### 선택 기준

- JSON 본문이면 `@RequestBody`
- query string / form 조합이면 `@ModelAttribute`
- 단순 단건 파라미터면 `@RequestParam`
- 경로 식별자는 `@PathVariable`

### 예시

```java
public record OrderSearchRequest(
        @NotNull OrderStatus status,
        @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
        @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
}

@GetMapping
public Page<OrderSummaryResponse> search(@Valid @ModelAttribute OrderSearchRequest request,
                                         Pageable pageable) {
    return orderQueryService.search(request, pageable);
}
```

- 검증은 Controller에서 시작하되, 비즈니스 규칙 검증은 Service로 넘긴다
- 검증 실패 포맷은 메서드마다 따로 만들지 않고 공통 예외 응답으로 모은다

---

## 예외 응답 패턴

### 기본 원칙

- Controller마다 `try-catch`를 넣지 않는다
- 바인딩 실패, 비즈니스 예외, 시스템 예외를 같은 방식으로 감싸되 상태 코드는 구분한다
- 공통 에러 응답이 있으면 그 구조를 따라간다

### 예시

```java
@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(MethodArgumentNotValidException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public ErrorResponse handleValidation(MethodArgumentNotValidException e) {
        return ErrorResponse.of("INVALID_REQUEST", "요청값이 올바르지 않습니다.");
    }
}
```

---

## 응답 DTO와 직렬화 패턴

- Entity를 직접 응답으로 내보내지 않는다
- 응답 DTO 변환 위치는 Service 또는 전용 assembler로 고정한다
- 날짜/enum 표현은 기존 Jackson 설정을 따른다
- 파일 다운로드는 `Content-Disposition`, `Content-Type`, 캐시 헤더를 같이 본다

---

## JPA / MyBatis 연계 기준

### JPA로 이어질 때

- Entity 조회 결과를 응답 DTO로 어디서 변환할지 정리
- N+1, fetch join, Projection 이슈가 보이면 JPA 스킬로 이어감

### MyBatis로 이어질 때

- Mapper 결과를 어떤 DTO로 받을지, count/목록 쿼리를 어떻게 맞출지 정리
- SQL 자체가 길거나 조인이 많고 정렬/인덱스 부담이 보이면 `query-tuner` 관점으로 확장

MVC는 끝까지 잡되, 데이터 접근 구현 세부는 해당 스킬을 붙여 완성한다.

---

## 안티패턴

- Controller에서 비즈니스 로직과 데이터 조합까지 모두 처리
- Entity를 그대로 JSON 응답으로 반환
- 상태 코드를 예외 종류가 아니라 구현 편의대로 선택
- 검증 실패 응답과 비즈니스 오류 응답의 구조가 제각각
- 파일 업로드/다운로드 처리를 Controller 한 메서드에 과도하게 몰아넣음

---

## 버전 적용 규칙

### Spring Boot 2.x → 3.x

| Boot 2.x | Boot 3.x |
|---|---|
| `javax.validation.*` | `jakarta.validation.*` |
| 구버전 `ErrorAttributes` / 커스텀 에러 응답 혼용 가능 | `ProblemDetail`, `ErrorResponse` 기반 확장 가능 |
| 과거 Converter/Formatter 설정 방식 유지 | 같은 개념이지만 Jakarta 패키지 기준으로 정리 |

### Jackson / Validation

| 상황 | 확인할 것 |
|---|---|
| 날짜 포맷 불일치 | `ObjectMapper` 전역 설정, `@JsonFormat` 사용 여부 |
| enum 직렬화 차이 | `WRITE_ENUMS_USING_TO_STRING`, `@JsonValue` 사용 여부 |
| 검증 메시지 커스터마이징 | `messages.properties`, `MessageSource` 연결 여부 |
