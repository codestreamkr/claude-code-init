---
name: ct:spring-jpa
description: Spring Data JPA 쿼리 패턴 전문 지식. Query Methods·QueryDSL·@Query·N+1·페이징·Projection 구현 패턴과 Entity 최소 가이드를 다룬다. 환경(Java·Boot·Hibernate·의존성) 감지 후 버전에 맞게 적용한다.
---

# Spring Data JPA 쿼리 패턴

---

## 환경 감지 — 코드 작성 전 필수 확인

| 확인 항목 | 위치 / 기준 |
|---|---|
| 빌드 도구 | `pom.xml` 존재 → Maven / `build.gradle` 존재 → Gradle |
| Spring Boot 버전 | Maven: `<parent>`의 `<version>` / Gradle: `id 'org.springframework.boot' version '...'` 또는 `libs.versions.toml` |
| Java 버전 | Maven: `<java.version>` / Gradle: `sourceCompatibility` 또는 `toolchain` |
| Hibernate 메이저 | Boot 2.x = Hibernate 5 (`javax.persistence.*`) / Boot 3.x = Hibernate 6 (`jakarta.persistence.*`) |
| QueryDSL 의존성 | `querydsl-jpa` 존재 여부 |
| MapStruct 의존성 | `mapstruct` 존재 여부 (DTO 변환) |
| Lombok 의존성 | `lombok` 존재 여부 (`@Getter`, `@Builder` 사용 가능 여부) |
| 쿼리 로깅 | `p6spy` / `datasource-proxy` 설정 여부 |
| BaseEntity | `@MappedSuperclass` 기반 공통 Entity 존재 여부 |
| ID 전략 | 기존 Entity의 `@GeneratedValue` 전략 |
| DB 종류 | `application.yml`의 `spring.datasource.url` |

버전과 의존성에 따라 문법·전략이 달라진다. 감지 결과는 사용자에게 먼저 공유한다.

### 적용 절차 — 이 스킬의 코드를 읽는 방법

**이 스킬의 모든 코드 블록은 최신 기준선(Spring Boot 3 / Hibernate 6 / Jakarta) 문법이다.** 감지된 환경이 다르면 그대로 복붙하면 컴파일 안 된다.

1. **환경 감지**에서 Boot/Java/Hibernate/의존성을 먼저 확인
2. 기준선과 다른 점이 있으면 하단 **버전 적용 규칙**의 변환표를 거쳐 출력
3. 감지된 의존성에 따라 쿼리 패턴 선택 (예: QueryDSL 없으면 Query Methods + `@Query`만)
4. 감지 결과를 사용자에게 먼저 공유 — "자네 프로젝트는 Boot 2.7 / Hibernate 5네. `import`를 `javax.persistence.*`로 바꿔 적용했네"

이 절차를 건너뛰고 기준선 코드를 그대로 출력하면 버전 오류의 원인이 된다.

---

## 이 스킬의 범위

이 스킬은 **JPA 분야의 구현 문법·패턴**만 담당한다. 설계 판단과 아키텍처 결정은 spring 에이전트가 맡는다.

**다루는 것 (JPA 구현 문법·패턴)**
- 쿼리 구현 — Query Methods, QueryDSL, @Query (JPQL·Native)
- 성능 패턴 — N+1 해결(fetch join·@EntityGraph·batch_fetch_size), 페이징, 벌크 연산
- 매핑·조회 문법 — Projection, Pageable·Sort, `@Modifying`, auditing 어노테이션
- Entity 작성에 필요한 최소 문법 가이드 (ID 전략, 관계 기본 원칙)

**다루지 않는 것 (spring 에이전트 영역)**
- 트랜잭션 경계 설계 (`@Transactional` 범위·전파 선택)
- 서비스·계층 분리, DTO vs Entity 반환 결정
- 연관관계 상세 설계, 상속 전략, Embeddable, 낙관적/비관적 락 선택
- 영속성 컨텍스트 라이프사이클 설계, OSIV 정책 결정
- 도메인 모델 자체의 설계 (어떤 Entity를 둘지)

판단·설계 질문이 들어오면 에이전트가 먼저 정리한 뒤, 구현 단계에서 이 스킬을 쓴다.

**표준 우선 원칙**: 에이전트의 표준 우선 원칙을 따른다 — 별도 요구 없으면 Spring Data JPA 공식 권장 방식을 선택.

---

## 진단 플로우

쿼리·성능 이상이 있을 때 순서대로 탄다.

1. **쿼리 로그부터** — `hibernate.show_sql` 말고 `p6spy` 또는 `datasource-proxy`로 바인딩 값까지 로깅
2. **쿼리 건수 vs 결과 엔티티 수** — 쿼리 ≥ (엔티티 수 + 1)이면 **N+1 확정**
3. **N+1 해법 순서** — `JOIN FETCH` → `@EntityGraph` → `default_batch_fetch_size`
4. **`HHH000104` 경고** — 컬렉션 fetch join + 페이징. 쿼리 분리하거나 `@BatchSize`로 전환
5. **`MultipleBagFetchException`** — 컬렉션 fetch join 2개 이상. `Set` 변경 또는 쿼리 분리
6. **DTO 필요하면** — `@QueryProjection`(QueryDSL) 또는 JPQL `SELECT new ...` 또는 Interface Projection
7. **벌크 연산** — `@Modifying(clearAutomatically = true)` 필수. 안 붙이면 영속성 컨텍스트가 DB와 어긋남

---

## 수치 감각

- **`default_batch_fetch_size`** — 100~1000 권장. Oracle `IN` 리터럴 제한 1000 주의
- **`hibernate.jdbc.batch_size`** — 20~50. INSERT/UPDATE 배치 효율 구간 (너무 크면 메모리)
- **`hibernate.jdbc.fetch_size`** — 기본 0(드라이버 기본값). 대량 커서 조회는 100~1000
- **페이지 크기** — UI 20~50, 내부 배치 500~1000
- **N+1 판단** — 쿼리 수 ≥ (결과 엔티티 수 + 1)
- **`order_inserts` / `order_updates`** — `true`로 설정해야 배치가 실제로 묶임
- **`provider_disables_autocommit`** — `true`면 커넥션 획득 시 autocommit 호출 생략, OLTP 성능 향상

---

## 쿼리 패턴 우선순위

1. **Query Methods** → 단순 조회 (findById, existsByEmail 등)
2. **QueryDSL** → 동적 + 복잡 쿼리 (의존성이 있을 때만)
3. **@Query (JPQL)** → 벌크 연산(@Modifying), 네이티브 쿼리

단순한 걸 복잡한 방법으로 풀지 않는다. Query Method로 되는 걸 QueryDSL로 짜면 유지보수만 어려워진다.

---

## Entity 기본 가이드

스킬 범위는 쿼리 패턴이지만, Entity 작성 시 최소한의 판단 기준은 여기서 제공한다.

### ID 전략

| 전략 | 사용 기준 |
|---|---|
| IDENTITY | MySQL/MariaDB 기본. 단순하고 검증됨 |
| SEQUENCE | PostgreSQL/Oracle 기본. 배치 INSERT에 유리 |
| TABLE | 쓰지 않는다 |
| UUID | 분산 환경, URL 노출 시 |

프로젝트에 기존 전략이 있으면 그대로 따른다.

### 연관관계 기본 원칙

- 양방향보다 단방향을 먼저 고려한다
- @ManyToOne이 기본. @OneToMany는 진짜 필요할 때만
- 양방향이면 연관관계 편의 메서드를 반드시 작성한다
- CascadeType.ALL은 부모-자식 생명주기가 완전히 같을 때만

### Auditing

- 프로젝트에 BaseEntity가 있으면 상속한다
- 없으면 createdAt, updatedAt 정도만 @CreatedDate, @LastModifiedDate로

### Soft Delete

- 프로젝트에 기존 패턴이 있으면 따른다
- 없으면 별도 제안하지 않는다 (요청 시에만)

연관관계 상세 설계, 상속 전략, Embeddable, 낙관적/비관적 락은 이 스킬 범위 밖이다. 필요하면 별도 요청을 안내한다.

---

## Query Methods

### 사용 기준
- 조건 2~3개 이하의 단순 조회
- 메서드 이름만으로 의도가 명확할 때

### 네이밍 규칙

| 목적 | 패턴 | 예시 |
|---|---|---|
| 단건 조회 | findBy... | findByEmail(String email) |
| 목록 조회 | findAllBy... | findAllByStatus(Status status) |
| 존재 확인 | existsBy... | existsByEmail(String email) |
| 건수 | countBy... | countByStatus(Status status) |
| 삭제 | deleteBy... | deleteByExpiredAtBefore(LocalDateTime date) |

### 한계선
- 조건 3개 이상이면 메서드 이름이 너무 길어진다 → @Query 또는 QueryDSL로 전환
- 동적 조건이 필요하면 → QueryDSL
- OR 조건이 복잡하면 → @Query

---

## QueryDSL 패턴 (의존성이 있을 때만)

### 기본 구조

```java
public interface OrderRepositoryCustom {
    Page<OrderDto> searchOrders(OrderSearchCondition condition, Pageable pageable);
}

public class OrderRepositoryImpl implements OrderRepositoryCustom {

    private final JPAQueryFactory queryFactory;

    @Override
    public Page<OrderDto> searchOrders(OrderSearchCondition condition, Pageable pageable) {
        List<OrderDto> content = queryFactory
            .select(new QOrderDto(
                order.id,
                order.orderNumber,
                order.status,
                order.createdAt
            ))
            .from(order)
            .where(
                statusEq(condition.getStatus()),
                createdAtBetween(condition.getStartDate(), condition.getEndDate())
            )
            .offset(pageable.getOffset())
            .limit(pageable.getPageSize())
            .orderBy(order.createdAt.desc())
            .fetch();

        JPAQuery<Long> countQuery = queryFactory
            .select(order.count())
            .from(order)
            .where(
                statusEq(condition.getStatus()),
                createdAtBetween(condition.getStartDate(), condition.getEndDate())
            );

        return PageableExecutionUtils.getPage(content, pageable, countQuery::fetchOne);
    }

    private BooleanExpression statusEq(OrderStatus status) {
        return status != null ? order.status.eq(status) : null;
    }

    private BooleanExpression createdAtBetween(LocalDate start, LocalDate end) {
        if (start == null && end == null) return null;
        if (start != null && end != null) {
            return order.createdAt.between(
                start.atStartOfDay(), end.plusDays(1).atStartOfDay());
        }
        if (start != null) return order.createdAt.goe(start.atStartOfDay());
        return order.createdAt.lt(end.plusDays(1).atStartOfDay());
    }
}
```

### 동적 조건 패턴
- BooleanExpression 메서드로 분리, null 반환 시 조건 무시
- where()에 null이 들어가면 자동 무시되는 QueryDSL 특성 활용

### Projection
- @QueryProjection + DTO 생성자: 컴파일 타임 체크 가능
- Projections.constructor(): QueryDSL 의존성을 DTO에서 제거할 때

---

## @Query (JPQL / Native)

### 사용 기준
- 벌크 연산 (@Modifying + @Query)
- 네이티브 쿼리가 필요한 경우
- Query Method로 표현하기 어려운 단일 정적 쿼리

### 벌크 연산

```java
@Modifying(clearAutomatically = true)
@Query("UPDATE Order o SET o.status = :status WHERE o.createdAt < :date")
int bulkUpdateStatus(@Param("status") OrderStatus status,
                     @Param("date") LocalDateTime date);
```

- clearAutomatically = true: 벌크 연산 후 영속성 컨텍스트를 자동 초기화
- 벌크 연산은 영속성 컨텍스트를 무시하고 DB에 직접 실행한다는 점을 항상 주의

### 네이티브 쿼리

```java
@Query(value = "SELECT * FROM orders WHERE MATCH(description) AGAINST(:keyword)",
       nativeQuery = true)
List<Order> fullTextSearch(@Param("keyword") String keyword);
```

- 네이티브 쿼리는 DB 종속성을 만든다. 진짜 필요한 경우에만 사용

---

## N+1 감지 및 해결

### N+1이 발생하는 상황
- @OneToMany, @ManyToMany의 LAZY 로딩 컬렉션을 루프에서 접근
- @ManyToOne도 여러 엔티티를 조회하면서 연관 엔티티를 각각 로딩

### 해결 우선순위

1. **fetch join** — 가장 직접적

```java
@Query("SELECT o FROM Order o JOIN FETCH o.orderItems WHERE o.id = :id")
Optional<Order> findByIdWithItems(@Param("id") Long id);
```

2. **@EntityGraph** — 선언적, 재사용 가능

```java
@EntityGraph(attributePaths = {"orderItems", "orderItems.product"})
Optional<Order> findById(Long id);
```

3. **default_batch_fetch_size** — 전역 설정

```yaml
spring:
  jpa:
    properties:
      hibernate:
        default_batch_fetch_size: 100
```

### 주의사항
- fetch join + 페이징 = 메모리 페이징 경고 (HHH000104). 컬렉션 fetch join에서 페이징하면 안 된다
- 컬렉션 fetch join은 1개만 가능. 2개 이상이면 MultipleBagFetchException
- batch_fetch_size로 해결하거나, 쿼리를 분리

---

## 페이징과 정렬

### Page vs Slice

| 항목 | Page | Slice |
|---|---|---|
| 전체 건수 조회 | O (COUNT 쿼리 실행) | X |
| 다음 페이지 존재 여부 | O | O |
| 적합한 UI | 페이지 번호 네비게이션 | 더보기 / 무한 스크롤 |

### 카운트 쿼리 최적화

```java
@Query(value = "SELECT o FROM Order o JOIN o.member m WHERE m.status = :status",
       countQuery = "SELECT COUNT(o) FROM Order o JOIN o.member m WHERE m.status = :status")
Page<Order> findByMemberStatus(@Param("status") MemberStatus status, Pageable pageable);
```

- 복잡한 조회 쿼리에서 COUNT 쿼리는 불필요한 JOIN을 제거한 별도 쿼리로 분리

### 정렬
- 단순 정렬: Pageable에 Sort 포함 (Sort.by("createdAt").descending())
- 복잡한 정렬: @Query 내 ORDER BY 직접 작성

---

## Projection

### Interface Projection

```java
public interface OrderSummary {
    Long getId();
    String getOrderNumber();
    OrderStatus getStatus();
}

List<OrderSummary> findAllByStatus(OrderStatus status);
```

- 필요한 컬럼만 SELECT하므로 성능에 유리
- 중첩 Projection은 N+1을 유발할 수 있으니 주의

### DTO Projection (@Query)

```java
@Query("SELECT new com.example.dto.OrderDto(o.id, o.orderNumber, o.status) " +
       "FROM Order o WHERE o.status = :status")
List<OrderDto> findOrderDtoByStatus(@Param("status") OrderStatus status);
```

- 패키지 경로 전체를 써야 한다는 불편함이 있지만, 타입 안전

### 선택 기준
- 단순 읽기 전용: Interface Projection
- 복잡한 변환/계산이 필요: DTO Projection 또는 QueryDSL Projection

---

## 안티패턴

### OSIV와 LazyInitializationException
- OSIV가 꺼져 있으면 트랜잭션 밖에서 LAZY 로딩 시 예외 발생
- 서비스 레이어에서 필요한 데이터를 모두 로딩하고 DTO로 변환 후 반환

### save() 오용
- 이미 영속 상태인 엔티티에 save()를 다시 호출하면 불필요한 merge 발생
- 변경 감지(dirty checking)를 활용한다

### findAll() 후 필터링
- 전체를 가져온 뒤 Java에서 필터링하는 것은 DB를 안 쓰는 것과 같다
- WHERE 조건을 쿼리에 넣는다

### 양방향 연관관계 무한 루프
- toString(), JSON 직렬화에서 순환 참조 발생
- DTO로 변환 후 반환. Entity를 직접 API 응답으로 내보내지 않는다

---

## 버전 적용 규칙

환경 감지 결과에 맞춰 변환. 기준선(Boot 3 / Hibernate 6 / Jakarta)에서 과거 버전으로 내려가는 방향.

### Spring Boot 2 → 3 / Hibernate 5 → 6 변환

| Boot 2 + Hibernate 5 | Boot 3 + Hibernate 6 |
|---|---|
| `javax.persistence.*` | `jakarta.persistence.*` (전면 교체) |
| `javax.validation.*` | `jakarta.validation.*` |
| `@SQLDelete` + `@Where` | `@SoftDelete`, `@SQLRestriction` (권장) |
| `GenerationType.AUTO` 동작 안정적 | `SEQUENCE` 시도 → 시퀀스 없으면 `hibernate_sequence` 자동 생성 (Flyway 환경 주의) |
| Query Result Tuple 기존 동작 | 일부 쿼리 결과 타입 변경 |
| UUID 매핑에 `columnDefinition` 필요 | UUID 네이티브 지원 개선 |

**Spring Data JPA 버전별 추가 변화**
- 3.x: `CrudRepository` 반환 타입 `Iterable` → `List`
- 3.2+: SQL Query Hint 지원, AOT 힌트 개선, Fluent `findBy()` API

### 의존성에 따른 패턴 선택

| 상황 | 선택 |
|---|---|
| QueryDSL 있음 | 동적 + 복잡 쿼리에 QueryDSL 적용 |
| QueryDSL 없음 | Query Methods + `@Query`만 사용. QueryDSL 도입 제안은 별도 요청 시에만 |
| MapStruct 있음 | DTO 변환에 `@Mapper` 사용 |
| MapStruct 없음 | 직접 변환 (record 생성자 또는 정적 팩토리) |
| Lombok 있음 | `@Getter`, `@Builder`, `@NoArgsConstructor(access = PROTECTED)` 사용 |
| Lombok 없음 | 수동 getter·기본 생성자 작성 |
| p6spy/datasource-proxy 있음 | 진단 시 바인딩 값까지 로깅 확인 |
| p6spy 없음 | `hibernate.show_sql` + `format_sql`로 우선 확인, 도입은 별도 제안 |

### Java 버전별 활용

| Java | 적용 가능한 것 |
|---|---|
| 8 | 기본 문법만. DTO는 일반 클래스 |
| 11 | `var` 타입 추론 |
| 17+ | `record`로 Projection DTO 선언 (`record OrderDto(Long id, String status) {}`), JPQL `SELECT new ...`에도 사용 가능 |
| 21 | 가상 스레드. 블로킹 JDBC 호출 성능 재검토. JPA는 여전히 블로킹이므로 가상 스레드 풀 크기 주의 |
