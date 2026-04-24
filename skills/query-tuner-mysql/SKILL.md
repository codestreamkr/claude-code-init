---
name: ct:query-tuner-mysql
description: MySQL/MariaDB 쿼리 튜닝 전문 지식. query-tuner agent가 MySQL DB로 감지했을 때 로드된다.
---

# MySQL 튜닝 전문 지식

---

## 정보 조회 쿼리

### [필수] 실행 계획 조회

```sql
-- 기본 EXPLAIN
EXPLAIN
<여기에 튜닝 대상 쿼리 붙여넣기>;

-- 실제 실행 통계 포함 (MySQL 8.0+)
EXPLAIN ANALYZE
<여기에 튜닝 대상 쿼리 붙여넣기>;

-- JSON 형식 (상세 분석용)
EXPLAIN FORMAT=JSON
<여기에 튜닝 대상 쿼리 붙여넣기>;
```

### [필수] 인덱스 현황 조회

```sql
-- 테이블 인덱스 목록 및 카디널리티
SHOW INDEX FROM 테이블명;

-- information_schema로 상세 조회
SELECT index_name,
       seq_in_index,
       column_name,
       non_unique,
       cardinality,
       index_type
FROM   information_schema.STATISTICS
WHERE  table_schema = DATABASE()
  AND  table_name = '테이블명'
ORDER  BY index_name, seq_in_index;
```

### [필수] 카디널리티 조회

```sql
-- 컬럼별 고유값 수 (정확한 값)
SELECT column_name,
       COUNT(DISTINCT column_name) AS cardinality
FROM   테이블명;

-- information_schema 기준 (추정값, 빠름)
SELECT column_name, cardinality
FROM   information_schema.STATISTICS
WHERE  table_name = '테이블명'
  AND  seq_in_index = 1;
```

### [옵션] 통계 정보 최신성 확인

```sql
-- 테이블 통계 확인
SELECT table_name,
       table_rows,
       data_length,
       index_length,
       update_time
FROM   information_schema.TABLES
WHERE  table_schema = DATABASE()
  AND  table_name = '테이블명';

-- 통계 갱신
ANALYZE TABLE 테이블명;
```

### [옵션] 데이터 규모 확인

```sql
-- 추정값 (빠름)
SELECT table_rows
FROM   information_schema.TABLES
WHERE  table_name = '테이블명';

-- 정확한 값 (느림, 대용량 주의)
SELECT COUNT(*) FROM 테이블명;
```

---

## EXPLAIN 해석

주요 확인 항목:
- `type` 컬럼: `ALL`(풀스캔) → `index` → `range` → `ref` → `eq_ref` → `const` 순으로 좋아짐
- `key` 컬럼: 실제 사용된 인덱스 (NULL이면 인덱스 미사용)
- `rows` 컬럼: 예상 스캔 행 수
- `Extra` 컬럼:
  - `Using filesort` → 인덱스로 정렬 불가, 별도 정렬 발생
  - `Using temporary` → 임시 테이블 사용 (GROUP BY, ORDER BY 최적화 필요)
  - `Using index` → 커버링 인덱스 적용됨 (좋음)
  - `Using where` → 인덱스 스캔 후 추가 WHERE 필터링 발생

---

## 진단 플로우

1. **느린 쿼리 식별** — `performance_schema.events_statements_summary_by_digest`에서 `sum_timer_wait` 상위
2. **실측 플랜** — `EXPLAIN ANALYZE` (8.0+) 또는 `EXPLAIN FORMAT=TREE`
3. **type 컬럼 확인** — `ALL` / `index` → 인덱스 부재, `Using filesort` / `Using temporary` → 쿼리 구조 이슈
4. **rows 추정 오차** — 예상치와 실제 큰 차이 → `ANALYZE TABLE` + 히스토그램 검토
5. **Index Merge 탐지** — `Using union` / `Using intersect` 보이면 복합 인덱스 1개로 재설계
6. **Buffer Pool 히트율** — 낮으면 메모리 부족 또는 워크셋 과다

---

## 수치 감각

- **type 컬럼 목표** — `ref` 이상이 기본선. `range`까지는 허용, `index`·`ALL`은 문제
- **Buffer Pool 히트율** — 99% 미만이면 경고 신호 (OLTP 기준)
- **`innodb_buffer_pool_size`** — 일반적으로 서버 메모리의 50~70%
- **`innodb_stats_persistent_sample_pages`** — 기본 20. VLDB는 200~2000으로 올려야 추정 정확
- **히스토그램 버킷** — 기본 100. 쏠림 심하면 1024 (최대)
- **`tmp_table_size` / `max_heap_table_size`** — 작으면 임시 테이블이 디스크로 — 최소 64MB 권장
- **Prefix 인덱스 길이** — 카디널리티가 전체의 80%에 도달하는 지점이 최소선

---

## 인덱스 전략

보편 원칙(복합 인덱스 순서, 커버링, 선택도)은 에이전트에서 다룬다. 여기는 MySQL/InnoDB 특유의 것만.

### 인덱스 타입
- B-Tree: 기본 (InnoDB 기본값)
- FULLTEXT: 텍스트 검색
- Prefix Index: 긴 `VARCHAR` 컬럼 일부만 인덱싱

### DDL 형식

```sql
-- 기본 인덱스
ALTER TABLE orders ADD INDEX idx_status_date (status, order_date);

-- 커버링 인덱스
ALTER TABLE orders ADD INDEX idx_covering (status, order_date, amount);

-- Prefix 인덱스
ALTER TABLE users ADD INDEX idx_email (email(20));

-- 온라인 추가 (서비스 중단 최소화, MySQL 5.6+)
ALTER TABLE orders ADD INDEX idx_status_date (status, order_date), ALGORITHM=INPLACE, LOCK=NONE;
```

---

## 쿼리 최적화 패턴

### 인덱스 힌트

```sql
-- 인덱스 강제 사용
SELECT * FROM orders FORCE INDEX (idx_status_date)
WHERE status = 'COMPLETE';

-- 인덱스 사용 제외
SELECT * FROM orders IGNORE INDEX (idx_old)
WHERE status = 'COMPLETE';
```

### MySQL 특유 리라이팅
- 5.7 이하 `IN (SELECT ...)` → `INNER JOIN` (서브쿼리 비최적화 회피)
- `NOT IN` → `LEFT JOIN ... IS NULL` (MySQL은 `NOT EXISTS`보다 이쪽이 빠른 경우가 많다)
- 커버링 인덱스 적극 활용 — InnoDB는 보조 인덱스 → PK → 힙 접근 구조라 커버링 이득이 특히 크다

공통 리라이팅(`OR`→`UNION ALL`, 대용량 OFFSET→keyset)은 에이전트 안티패턴에서.

---

## 옵티마이저 특성

### 비용 모델
MySQL 옵티마이저는 테이블 통계 기반 비용 모델을 쓴다.
주요 비용:
- I/O 비용 — `innodb_page_size` 단위 읽기
- CPU 비용 — row/record 처리 비용
- 비용 상수는 `mysql.server_cost`, `mysql.engine_cost` 테이블에서 조정 가능

### Optimizer Trace
옵티마이저가 왜 이 플랜을 선택했는지 볼 수 있다.

```sql
SET optimizer_trace = "enabled=on";
<대상 쿼리 실행>;
SELECT * FROM information_schema.OPTIMIZER_TRACE;
SET optimizer_trace = "enabled=off";
```

### 조인 옵티마이저 특성
- `optimizer_search_depth` — 조인 순서 탐색 깊이 (기본 62)
- greedy search 알고리즘 기본 사용
- 테이블 수가 많으면 완전 탐색을 포기하고 greedy로 fallback

### 주요 최적화 스위치

```sql
SELECT @@optimizer_switch;
```

- `index_condition_pushdown` (ICP) — WHERE 조건을 스토리지 엔진에 내림
- `mrr` (Multi-Range Read) — 랜덤 I/O를 순차로 변환
- `batched_key_access` (BKA) — 조인 시 키 접근 배치화
- `hash_join` (8.0.18+) — 인덱스 없는 조인에 해시 적용

---

## 통계 시스템

### InnoDB 영구 통계

```sql
-- 샘플링 페이지 수 (기본 20, 늘리면 정확도↑ 비용↑)
SHOW VARIABLES LIKE 'innodb_stats_persistent_sample_pages';

-- 자동 재계산 임계치 (기본 10% 변경)
SHOW VARIABLES LIKE 'innodb_stats_auto_recalc';
```

### 히스토그램 (8.0+)

```sql
-- 생성 (쏠림이 있는 컬럼에 필수)
ANALYZE TABLE orders UPDATE HISTOGRAM ON status, priority WITH 100 BUCKETS;

-- 조회
SELECT * FROM information_schema.COLUMN_STATISTICS
WHERE  table_name = 'orders';

-- 삭제
ANALYZE TABLE orders DROP HISTOGRAM ON status;
```

8.0 이전에는 히스토그램이 없어서 쏠림이 있는 컬럼에 카디널리티 추정이 자주 틀린다.

---

## MySQL 특유의 함정

### InnoDB Clustered Index
PK가 곧 데이터 저장 순서다. 보조 인덱스는 PK 값을 포인터로 저장한다.
결과:
- PK가 커지면 모든 보조 인덱스가 커진다 → PK는 짧게
- PK를 UUID로 쓰면 랜덤 삽입 → 페이지 분할과 단편화
- 보조 인덱스 스캔 후 PK로 힙 접근 → 커버링 인덱스 효과가 크다

### Index Merge의 함정
옵티마이저가 인덱스 2개를 조합해서 쓰는데, 실제로는 복합 인덱스 1개가 훨씬 빠른 경우가 많다.
`EXPLAIN`에 `Using union`, `Using intersect`가 보이면 복합 인덱스 재설계 검토.

### 서브쿼리 비최적화
MySQL 5.7까지는 서브쿼리를 조인으로 변환하지 못해 반복 실행이 잦다.
`IN (SELECT ...)` → `INNER JOIN`으로 수동 변환 권장.

### DATETIME vs TIMESTAMP
`TIMESTAMP`는 4바이트 UTC 저장, `DATETIME`은 8바이트 로컬.
인덱스 크기 차이가 성능에 영향. 단, `TIMESTAMP`는 2038년 문제가 있다.

### 문자셋/콜레이션 불일치
JOIN 컬럼의 콜레이션이 다르면 인덱스 무효화.
`utf8mb4_0900_ai_ci` vs `utf8mb4_general_ci` 같은 미묘한 차이 주의.

---

## 실전 진단 쿼리

### 실제 실행 시간 (8.0+)

```sql
EXPLAIN ANALYZE
<대상 쿼리>;
-- tree 형태로 실제 실행 시간, rows 반환
```

### Performance Schema로 느린 쿼리

```sql
SELECT digest_text,
       count_star,
       avg_timer_wait/1e9 AS avg_ms,
       sum_rows_examined,
       sum_rows_sent
FROM   performance_schema.events_statements_summary_by_digest
ORDER  BY sum_timer_wait DESC
LIMIT  20;
```

### InnoDB Buffer Pool 히트율

```sql
SELECT (1 - (
         SELECT variable_value FROM performance_schema.global_status
         WHERE  variable_name = 'Innodb_buffer_pool_reads'
       ) / (
         SELECT variable_value FROM performance_schema.global_status
         WHERE  variable_name = 'Innodb_buffer_pool_read_requests'
       )) * 100 AS hit_ratio;
```

---

## 버전별 차이

- **5.6** — ICP, MRR 도입, 온라인 DDL (`ALGORITHM=INPLACE`)
- **5.7** — Generated Columns, 네이티브 JSON 타입, `sys` 스키마, 파생 테이블 merge 개선
- **8.0** — 히스토그램, Window Functions, CTE, Invisible/Descending Index, Hash Join (8.0.18+), 기본 콜레이션 `utf8mb4_0900_ai_ci`
- **8.0.31+** — Lateral derived table, `EXPLAIN FORMAT=JSON` 확장
- **8.4 LTS** — GROUP BY 기본 동작(sort 제거) 변경, 기본 인증 방식 변경
- **MariaDB 분기 (10.x~11.x)** — 옵티마이저 힌트(`STRAIGHT_JOIN`, `Optimizer Hints`) 지원 범위가 다름, `THREAD_POOL` 내장, System-versioned 테이블 네이티브 지원. MySQL 문법이 그대로 안 먹는 경우 존재

버전 확인: `SELECT VERSION();`

---

## MySQL 체크리스트

- PK 설계가 전체 성능에 영향 — InnoDB 클러스터드 인덱스 구조상 PK는 짧고 순차적으로.
- UUID를 PK로 쓰면 페이지 분할·단편화 — 순차 UUID(v7) 또는 별도 surrogate key 검토.
- 콜레이션·문자셋 불일치 JOIN은 인덱스 무효화 — `utf8mb4_0900_ai_ci` 같은 미묘한 차이 주의.
- `ALTER TABLE`은 피크 시간 외 또는 `ALGORITHM=INPLACE, LOCK=NONE` 옵션으로.
- `EXPLAIN`에 `Using union`/`intersect` 보이면 Index Merge — 복합 인덱스 1개로 재설계 검토.
- 8.0 미만은 히스토그램 없음 — 쏠림 데이터는 카디널리티 추정이 자주 틀린다.
