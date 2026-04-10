---
name: query-tuner-postgres
description: PostgreSQL 쿼리 튜닝 전문 지식. query-tuner agent가 PostgreSQL DB로 감지했을 때 로드된다.
---

# PostgreSQL 튜닝 전문 지식

---

## 정보 조회 쿼리

### [필수] 실행 계획 조회

```sql
-- 실제 실행 통계 포함 (권장)
EXPLAIN (ANALYZE, BUFFERS)
<여기에 튜닝 대상 쿼리 붙여넣기>;

-- JSON 형식 (상세 분석용)
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
<여기에 튜닝 대상 쿼리 붙여넣기>;

-- 주의: EXPLAIN ANALYZE는 실제로 쿼리가 실행됨
-- DML 쿼리는 트랜잭션 안에서 실행 후 롤백
BEGIN;
EXPLAIN (ANALYZE, BUFFERS) UPDATE ...;
ROLLBACK;
```

### [필수] 인덱스 현황 조회

```sql
-- 테이블 인덱스 목록
SELECT indexname,
       indexdef,
       pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM   pg_indexes
LEFT   JOIN pg_class ON pg_class.relname = indexname
WHERE  tablename = '테이블명';

-- 인덱스 사용 통계 (사용 안 되는 인덱스 탐지)
SELECT indexrelid::regclass AS index_name,
       idx_scan,
       idx_tup_read,
       idx_tup_fetch
FROM   pg_stat_user_indexes
WHERE  relid = '테이블명'::regclass
ORDER  BY idx_scan;
```

### [필수] 카디널리티 조회

```sql
-- 컬럼별 고유값 수 및 분포 (통계 기준)
SELECT attname        AS column_name,
       n_distinct,
       correlation,   -- 1에 가까울수록 물리적 정렬과 일치 (인덱스 효율적)
       null_frac,
       most_common_vals,
       most_common_freqs
FROM   pg_stats
WHERE  tablename = '테이블명'
ORDER  BY attname;
```

### [옵션] 통계 정보 최신성 확인

```sql
-- 테이블 통계 최신성 확인
SELECT relname,
       n_live_tup,
       n_dead_tup,
       last_analyze,
       last_autoanalyze,
       last_vacuum,
       last_autovacuum
FROM   pg_stat_user_tables
WHERE  relname = '테이블명';

-- 통계 갱신
ANALYZE 테이블명;

-- dead tuple이 많으면 VACUUM 먼저
VACUUM ANALYZE 테이블명;
```

### [옵션] 데이터 규모 확인

```sql
-- 추정값 (빠름)
SELECT reltuples::bigint AS estimated_rows,
       pg_size_pretty(pg_total_relation_size(oid)) AS total_size
FROM   pg_class
WHERE  relname = '테이블명';

-- 정확한 값 (느림, 대용량 주의)
SELECT COUNT(*) FROM 테이블명;
```

---

## EXPLAIN 해석

주요 확인 항목:
- `Seq Scan` → 풀스캔. 인덱스 적용 검토
- `Index Scan` → 인덱스 사용 + 힙 접근
- `Index Only Scan` → 커버링 인덱스 (좋음)
- `Bitmap Index Scan` → 여러 인덱스 조합
- `Hash Join` vs `Nested Loop` vs `Merge Join`
- `actual time`, `rows`, `loops` 비교
- `Buffers: shared hit/read` → 캐시 히트율 확인
- 예상 `rows` vs `actual rows` 차이가 크면 통계 문제 또는 데이터 쏠림 의심

---

## 인덱스 전략

### 기본 원칙
- 통계 정보가 중요: `ANALYZE` 실행 여부 먼저 확인
- 부분 인덱스(Partial Index)로 불필요한 행 제외
- 표현식 인덱스로 함수 조건 커버
- `correlation` 값이 낮은 컬럼은 인덱스 효율이 떨어질 수 있음

### 인덱스 타입
- B-Tree: 기본, 범위/정렬에 적합
- Hash: `=` 조건 전용, 범위 조건 미지원
- GIN: 배열, JSONB, 전문 검색
- GiST: 지리 데이터, 범위 타입
- BRIN: 물리 정렬된 대용량 테이블 (로그성 데이터)

### DDL 형식

```sql
-- 기본 인덱스
CREATE INDEX idx_orders_status_date ON orders(status, order_date);

-- 부분 인덱스 (특정 조건 행만 인덱싱)
CREATE INDEX idx_orders_active ON orders(order_date)
WHERE status = 'ACTIVE';

-- 표현식 인덱스
CREATE INDEX idx_orders_year ON orders(EXTRACT(YEAR FROM order_date));

-- JSONB 인덱스
CREATE INDEX idx_meta_gin ON orders USING GIN(metadata);

-- 서비스 중단 없이 생성 (트랜잭션 블록 밖에서 실행)
CREATE INDEX CONCURRENTLY idx_orders_status ON orders(status);
```

---

## 쿼리 최적화 패턴

### 플래너 제어 (힌트 대신 설정으로 제어)

```sql
-- 특정 세션에서만 적용
SET enable_nestloop = OFF;    -- NL 조인 비활성화
SET enable_seqscan = OFF;     -- 시퀀셜 스캔 비활성화
SET work_mem = '256MB';       -- 정렬/해시 메모리 조정

-- 원복
RESET enable_nestloop;
RESET enable_seqscan;
RESET work_mem;
```

### 자주 쓰는 리라이팅 패턴
- 반복 서브쿼리 → `WITH` 절(CTE)로 추출
- `NOT IN` → `NOT EXISTS` 또는 `LEFT JOIN ... IS NULL`
- 대용량 페이징 `OFFSET` → keyset 페이징으로 전환

---

## 옵티마이저 특성

### CBO 비용 모델
PostgreSQL 플래너는 비용 기반이다. 주요 파라미터:
- `seq_page_cost` = 1.0 (기본)
- `random_page_cost` = 4.0 (기본, SSD면 1.1~1.5로 낮춰야 함)
- `effective_cache_size` — OS 캐시까지 포함한 예상 캐시 크기 (메모리의 50~75%)
- `work_mem` — 정렬/해시 메모리 (세션별)
- `cpu_tuple_cost`, `cpu_index_tuple_cost`, `cpu_operator_cost`

**SSD 환경에서 `random_page_cost`가 기본값(4.0)이면 인덱스 스캔이 과소평가된다.**

### 플래너 힌트 부재
PostgreSQL은 힌트가 없다. `enable_*` 세션 변수로 특정 방식 비활성화만 가능하다.

```sql
SET enable_seqscan = OFF;
SET enable_nestloop = OFF;
```

영구 설정 금지. 세션 단위로만 사용.

### JIT 컴파일 (11+)
대량 쿼리에 JIT이 적용되면 빨라지지만, 짧은 OLTP 쿼리는 JIT 컴파일 오버헤드가 더 크다.

```sql
SHOW jit;
SET jit = off;  -- OLTP 환경에서 비활성화 검토
```

### Generic vs Custom Plan (Prepared Statement)
Prepared statement는 첫 5회는 custom plan(바인드값 고려), 이후 generic plan으로 전환.
데이터 쏠림이 심한 컬럼에서 generic plan이 나빠지는 경우가 있다.
`plan_cache_mode = force_custom_plan`으로 해결 가능.

---

## 통계 시스템

### ANALYZE 동작
- 기본 샘플: `default_statistics_target = 100` (블록당 300개 * 100 = 30,000 행)
- 쏠림이 심한 컬럼은 타겟을 올려야 한다:

```sql
ALTER TABLE orders ALTER COLUMN status SET STATISTICS 1000;
ANALYZE orders;
```

### 자동 통계 수집
- Autovacuum daemon이 ANALYZE도 수행
- 임계치: `autovacuum_analyze_threshold + autovacuum_analyze_scale_factor * n_live_tup`
- 기본 scale_factor 0.1 = 10% 변경 시 자동 분석
- 대용량 테이블에서는 너무 느리게 트리거됨 → 테이블별 조정 필요

### 다중 컬럼 통계 (CREATE STATISTICS, 10+)
컬럼 간 상관관계를 옵티마이저에게 알려주는 핵심 도구.

```sql
-- 의존 관계 (city는 zipcode를 함의)
CREATE STATISTICS stats_city_zip (dependencies)
  ON city, zipcode FROM orders;

-- 서로 다른 조합의 고유값 수
CREATE STATISTICS stats_product_cat (ndistinct)
  ON product_id, category_id FROM orders;

-- 다중 컬럼 히스토그램 (14+)
CREATE STATISTICS stats_full (dependencies, ndistinct, mcv)
  ON city, zipcode FROM orders;

ANALYZE orders;
```

---

## PostgreSQL 특유의 함정

### MVCC와 Dead Tuple
UPDATE는 기존 행을 dead로 마킹하고 새 행을 추가한다.
VACUUM이 따라잡지 못하면 dead tuple이 쌓여 인덱스/테이블 스캔 비용이 커진다.

```sql
SELECT relname,
       n_live_tup,
       n_dead_tup,
       round(n_dead_tup::numeric / nullif(n_live_tup, 0), 2) AS dead_ratio
FROM   pg_stat_user_tables
WHERE  n_dead_tup > 1000
ORDER  BY dead_ratio DESC NULLS LAST;
```

### HOT Update
변경된 컬럼이 인덱스에 없으면 HOT update로 처리 → 인덱스 갱신 생략.
인덱스를 무분별하게 많이 만들면 HOT update 기회를 잃는다.

### Index Bloat
인덱스는 VACUUM으로 완전히 회수되지 않는다. `REINDEX CONCURRENTLY` 필요.

```sql
-- 인덱스 크기 추이 점검
SELECT schemaname,
       tablename,
       indexname,
       pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM   pg_stat_user_indexes
ORDER  BY pg_relation_size(indexrelid) DESC;
```

### TOAST 오버헤드
큰 컬럼(2KB↑)은 TOAST 테이블에 분리 저장된다.
`SELECT *`로 TOAST 컬럼을 불필요하게 가져오면 I/O 급증.

### Correlation과 Index 효율
`pg_stats.correlation`이 0에 가까우면 인덱스 스캔 후 랜덤 힙 접근이 발생.
BRIN은 correlation이 1에 가까운 대용량 테이블에만 의미 있다.

---

## 실전 진단 쿼리

### 워크로드 전체 관점 (pg_stat_statements)

```sql
-- 확장 활성화 (postgresql.conf)
-- shared_preload_libraries = 'pg_stat_statements'
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- 가장 느린 쿼리
SELECT query,
       calls,
       total_exec_time,
       mean_exec_time,
       rows,
       shared_blks_hit,
       shared_blks_read
FROM   pg_stat_statements
ORDER  BY total_exec_time DESC
LIMIT  20;
```

### 실제 느린 쿼리 자동 로깅 (auto_explain)

```text
# postgresql.conf
shared_preload_libraries = 'auto_explain'
auto_explain.log_min_duration = '1s'
auto_explain.log_analyze = on
auto_explain.log_buffers = on
```

### 캐시 히트율

```sql
SELECT relname,
       heap_blks_hit,
       heap_blks_read,
       round(heap_blks_hit::numeric /
             nullif(heap_blks_hit + heap_blks_read, 0) * 100, 2) AS hit_ratio
FROM   pg_statio_user_tables
ORDER  BY heap_blks_hit + heap_blks_read DESC
LIMIT  20;
```

### 사용되지 않는 인덱스

```sql
SELECT schemaname,
       tablename,
       indexname,
       idx_scan,
       pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM   pg_stat_user_indexes
WHERE  idx_scan = 0
ORDER  BY pg_relation_size(indexrelid) DESC;
```

---

## 주의사항
- 통계가 오래됐으면 `ANALYZE table_name` 먼저 실행
- dead tuple이 많으면 `VACUUM ANALYZE` 먼저
- 표현식 인덱스는 쿼리의 표현식과 정확히 일치해야 사용됨
- `LIKE 'keyword%'`는 B-Tree 사용 가능, `'%keyword'`는 불가
- `CREATE INDEX CONCURRENTLY`는 트랜잭션 블록 안에서 실행 불가
- PostgreSQL은 힌트가 없어 `enable_*` 설정으로 플래너를 유도함 → 영구 변경 금지, 세션 단위로만 사용
