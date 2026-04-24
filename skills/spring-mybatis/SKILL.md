---
name: ct:spring-mybatis
description: Spring MyBatis 구성 패턴 전문 지식. Mapper 인터페이스·XML SQL·동적 조건·resultMap·count 쿼리·페이징 쿼리·조인 결과 매핑을 다룬다. 환경과 기존 SQL 스타일을 먼저 파악한 뒤 프로젝트 방식에 맞게 적용한다.
---

# Spring MyBatis 구성 패턴

---

## 환경 감지 — 코드 작성 전 필수 확인

| 확인 항목 | 위치 / 기준 |
|---|---|
| 빌드 도구 | `pom.xml` 존재 → Maven / `build.gradle` 존재 → Gradle |
| Spring Boot 버전 | Maven: `<parent>`의 `<version>` / Gradle: `id 'org.springframework.boot' version '...'` 또는 `libs.versions.toml` |
| Java 버전 | Maven: `<java.version>` / Gradle: `sourceCompatibility` 또는 `toolchain` |
| MyBatis 의존성 | `mybatis-spring-boot-starter`, `mybatis` 존재 여부 |
| Mapper 방식 | XML mapper / annotation mapper / 혼합 여부 |
| Mapper 위치 | `@MapperScan`, `mybatis.mapper-locations` 설정 |
| DB 종류 | `spring.datasource.url` 또는 별도 데이터소스 설정 |
| camel case 설정 | `mybatis.configuration.map-underscore-to-camel-case` 여부 |
| 페이징 방식 | limit-offset / RowBounds / 플러그인 사용 여부 |
| 공통 SQL 조각 | `<sql id="...">` 사용 패턴 존재 여부 |

버전과 설정에 따라 문법과 출력 방식이 달라진다. 감지 결과는 사용자에게 먼저 공유한다.

### 적용 절차 — 이 스킬의 코드를 읽는 방법

1. 환경 감지에서 Boot / Java / MyBatis / DB 종류를 먼저 확인
2. 기존 Mapper와 XML 한두 개를 읽고 네이밍과 SQL 스타일을 파악
3. 기준선과 다른 점이 있으면 그대로 덮어쓰지 말고 기존 패턴에 맞춰 출력
4. XML이 아니라 annotation mapper 중심이면 같은 문법을 annotation 기준으로 바꿔 제시

이 절차를 건너뛰고 일반론으로 SQL을 쓰면 프로젝트 안에서 어긋날 가능성이 크다.

---

## 이 스킬의 범위

이 스킬은 **MyBatis 분야의 구현 문법·패턴**만 담당한다. 설계 판단과 아키텍처 결정은 `spring` 에이전트가 맡는다.

**다루는 것 (MyBatis 구현 문법·패턴)**
- Mapper 인터페이스와 XML 구조
- `select`, `insert`, `update`, `delete` SQL 작성 패턴
- `if`, `choose`, `trim`, `where`, `set`, `foreach` 기반 동적 SQL
- `resultMap`, 중첩 매핑, 컬럼 alias, DTO 매핑
- 목록 쿼리, count 쿼리, 정렬, 검색 조건, 페이징

**다루지 않는 것 (spring 에이전트 영역)**
- JPA와 MyBatis 선택 판단
- 트랜잭션 경계와 서비스 책임 분리
- 도메인 모델 설계
- 인덱스 설계, 실행 계획 튜닝, SQL 힌트 전략
- 분산 트랜잭션, 메시징, 배치 아키텍처

판단·설계 질문이 들어오면 에이전트가 먼저 정리한 뒤, 구현 단계에서 이 스킬을 참고한다.

**표준 우선 원칙**: 별도 요구 없으면 MyBatis 공식 문법과 프로젝트 기존 SQL 스타일을 따른다.

---

## 진단 플로우

1. **Mapper와 XML 매칭부터** — 메서드 이름과 XML `id`가 맞는지 먼저 확인
2. **파라미터 구조 확인** — `@Param` 누락, 조건 객체 필드명 불일치 여부 확인
3. **동적 SQL 정리** — `where`, `trim`, `set` 없이 if만 쌓여 있는지 확인
4. **목록/카운트 쌍 확인** — 목록 쿼리와 count 쿼리 조건이 어긋나는지 확인
5. **결과 매핑 확인** — alias로 충분한지, `resultMap`이 필요한지 판단
6. **정렬·필터 안전성 확인** — 문자열 조립으로 raw SQL을 붙이지 않는지 확인
7. **조인 결과 확인** — DTO 필드가 비면 alias / `resultMap` / nullable 컬럼 순으로 점검

### query-tuner 연계 기준

- Mapper/XML 구조, 동적 SQL, `resultMap`, count 쿼리 정리는 이 스킬에서 먼저 본다
- SQL이 길어지거나 조인이 많고, 실행 계획·인덱스·정렬 비용까지 판단해야 하면 `query-tuner` 관점으로 이어서 검증한다
- 튜닝 검토 결과를 반영해 최종 Mapper 구조와 Spring 코드 흐름을 정리하는 단계는 다시 `spring` 에이전트가 맡는다

---

## 수치 감각

- **페이지 크기** — UI 목록 20~50, 운영 검색 50~100
- **정렬 허용 목록** — 컬럼 이름을 그대로 받지 말고 enum 또는 whitelist로 제한
- **`IN` 조건 개수** — DB별 제한 확인. Oracle은 1000 제한 주의
- **공통 SQL 조각** — 2~3곳 이상 반복될 때만 분리. 흐름이 안 읽히면 분리하지 않음
- **동적 조건 개수** — 5개를 넘어가면 조건 객체와 count 쿼리 구조를 함께 재검토

---

## 쿼리 패턴 우선순위

1. **단순 조회** — alias와 DTO로 충분하면 `resultMap` 없이 간다
2. **조인 결과가 복잡함** — `resultMap` 검토
3. **조건이 늘어남** — `where`, `trim`, `choose`로 동적 SQL 정리
4. **목록 + count** — 목록 쿼리와 count 쿼리를 함께 설계
5. **벌크 조건** — `foreach` 사용 시 빈 목록 처리와 separator 주의

복잡한 걸 복잡한 문법으로만 풀지 않는다. alias로 충분한 걸 `resultMap`으로 과하게 감싸지 않는다.

---

## Mapper 인터페이스

### 사용 기준

- 메서드 이름은 의도가 바로 드러나야 한다
- 파라미터가 2개 이하이고 의미가 분명하면 `@Param` 가능
- 검색 조건이 많으면 조건 객체로 묶는다

### 예시

```java
@Mapper
public interface OrderMapper {
    List<OrderListRow> findPage(OrderSearchCondition condition);
    long countPage(OrderSearchCondition condition);
    Optional<OrderDetailRow> findDetail(@Param("orderId") Long orderId);
}
```

- 목록과 count는 같이 보이게 둔다
- 상세 조회와 목록 조회 DTO를 분리한다

---

## XML 기본 패턴

### 기본 select

```xml
<select id="findDetail" resultType="com.example.order.dto.OrderDetailRow">
    select
        o.id as orderId,
        o.status as status,
        o.created_at as createdAt
    from orders o
    where o.id = #{orderId}
</select>
```

- alias로 끝낼 수 있으면 가장 단순하게 간다
- `select *`는 쓰지 않는다

### 동적 where

```xml
<select id="findPage" resultType="com.example.order.dto.OrderListRow">
    select
        o.id as orderId,
        o.status as status,
        o.created_at as createdAt
    from orders o
    <where>
        <if test="status != null">
            and o.status = #{status}
        </if>
        <if test="keyword != null and keyword != ''">
            and o.order_name like concat('%', #{keyword}, '%')
        </if>
    </where>
    order by o.id desc
    limit #{pageSize} offset #{offset}
</select>
```

- `where`로 선행 `and` 정리를 맡긴다
- 빈 문자열, null 조건을 같이 본다

### 동적 update

```xml
<update id="updateOrderStatus">
    update orders
    <set>
        <if test="status != null">
            status = #{status},
        </if>
        <if test="updatedBy != null">
            updated_by = #{updatedBy},
        </if>
    </set>
    where id = #{orderId}
</update>
```

- `set`으로 trailing comma를 제거한다

### foreach

```xml
<select id="findByIds" resultType="com.example.order.dto.OrderListRow">
    select
        o.id as orderId,
        o.status as status
    from orders o
    where o.id in
    <foreach collection="orderIds" item="id" open="(" separator="," close=")">
        #{id}
    </foreach>
</select>
```

- 빈 목록 처리 기준을 서비스 쪽에서 먼저 정한다
- DB별 `IN` 개수 제한을 넘는지 확인한다

---

## resultMap과 alias 선택 기준

### alias로 충분한 경우

- 단순 DTO 조회
- 필드 구조가 평평함
- 조인 결과가 많지 않음

### resultMap이 필요한 경우

- 필드명이 많이 어긋남
- 중첩 구조를 직접 매핑해야 함
- 같은 결과 구조를 여러 쿼리에서 재사용함

### 예시

```xml
<resultMap id="orderDetailMap" type="com.example.order.dto.OrderDetailRow">
    <id property="orderId" column="order_id"/>
    <result property="status" column="status"/>
    <result property="memberName" column="member_name"/>
</resultMap>

<select id="findDetail" resultMap="orderDetailMap">
    select
        o.id as order_id,
        o.status as status,
        m.name as member_name
    from orders o
    join members m on m.id = o.member_id
    where o.id = #{orderId}
</select>
```

---

## 목록과 count 쿼리

- 목록 쿼리와 count 쿼리는 조건이 어긋나지 않게 같이 관리한다
- 공통 조건을 `<sql>`로 빼더라도 읽기 어려워지면 다시 풀어쓴다
- 정렬과 limit-offset은 count 쿼리에서 제거한다

### 예시

```xml
<sql id="orderSearchCondition">
    <where>
        <if test="status != null">
            and o.status = #{status}
        </if>
        <if test="keyword != null and keyword != ''">
            and o.order_name like concat('%', #{keyword}, '%')
        </if>
    </where>
</sql>

<select id="findPage" resultType="com.example.order.dto.OrderListRow">
    select
        o.id as orderId,
        o.status as status
    from orders o
    <include refid="orderSearchCondition"/>
    order by o.id desc
    limit #{pageSize} offset #{offset}
</select>

<select id="countPage" resultType="long">
    select count(*)
    from orders o
    <include refid="orderSearchCondition"/>
</select>
```

---

## 안티패턴

- **정렬 컬럼 raw 문자열 조립** — whitelist 없이 `${sort}` 붙이지 않는다
- **`select *` 사용** — 컬럼 추가가 응답 계약 오염으로 이어진다
- **if만 연속 사용** — `where`, `trim`, `set` 없이 SQL을 이어붙이지 않는다
- **목록과 count 분리 관리** — 조건 하나 수정할 때 count가 빠질 위험이 크다
- **alias와 DTO 필드명 불일치 방치** — "왜 null이지" 문제가 반복된다
- **공통 SQL 과잉 재사용** — 흐름이 안 읽히면 재사용이 아니라 난독화다

---

## 추가 확장 제안

| 상황 | 제안 |
|---|---|
| 검색 조건이 계속 늘어남 | 조건 객체를 다시 설계하고 XML을 목록/상세/집계로 나눈다 |
| JPA와 MyBatis 혼용 | 조회는 MyBatis, 변경은 JPA 같은 역할 분리를 문서화하고 간다 |
| 대량 배치성 처리 | MyBatis batch executor 또는 별도 배치 구조 검토 |
| SQL 재사용이 많음 | `<sql>` 조각보다 DB view 또는 전용 조회 DTO 분리를 먼저 검토 |
