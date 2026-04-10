---
name: query-tuner-oracle
description: Oracle 쿼리 튜닝 전문 지식. query-tuner agent가 Oracle DB로 감지했을 때 로드된다.
---

# Oracle 튜닝 전문 지식

---

## 정보 조회 쿼리

### [필수] 실행 계획 조회

```sql
-- 방법 1. EXPLAIN PLAN
EXPLAIN PLAN FOR
<여기에 튜닝 대상 쿼리 붙여넣기>;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, NULL, 'ALLSTATS LAST'));

-- 방법 2. AUTOTRACE (SQL*Plus / SQLcl)
SET AUTOTRACE ON EXPLAIN STATISTICS;
<여기에 튜닝 대상 쿼리 붙여넣기>;
SET AUTOTRACE OFF;
```

### [필수] 인덱스 현황 조회

```sql
-- 테이블에 걸린 인덱스 목록
SELECT i.index_name,
       i.index_type,
       i.uniqueness,
       c.column_name,
       c.column_position,
       c.descend
FROM   user_indexes i
JOIN   user_ind_columns c ON i.index_name = c.index_name
WHERE  i.table_name = UPPER('테이블명')
ORDER  BY i.index_name, c.column_position;
```

### [필수] 카디널리티 조회

```sql
-- 컬럼별 고유값 수 및 분포
SELECT column_name,
       num_distinct,
       num_nulls,
       density,
       low_value,
       high_value
FROM   user_tab_col_statistics
WHERE  table_name = UPPER('테이블명')
ORDER  BY num_distinct DESC;
```

### [옵션] 통계 정보 최신성 확인

```sql
-- 테이블 통계 마지막 갱신 시점
SELECT table_name,
       num_rows,
       last_analyzed,
       sample_size
FROM   user_tables
WHERE  table_name = UPPER('테이블명');

-- 통계 갱신이 필요하면
EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, '테이블명', CASCADE => TRUE);
```

### [옵션] 데이터 규모 확인

```sql
SELECT table_name, num_rows
FROM   user_tables
WHERE  table_name IN ('테이블명1', '테이블명2');
-- num_rows는 통계 기준 추정값. 정확한 값은 COUNT(*) 사용
```

---

## EXPLAIN 해석

주요 확인 항목:
- `TABLE ACCESS FULL` → 풀스캔. 인덱스 적용 검토
- `INDEX RANGE SCAN` → 범위 스캔. 선택도 확인
- `INDEX FULL SCAN` → 인덱스 풀스캔. 커버링 인덱스 검토
- `NESTED LOOPS` → 소량 데이터 조인에 유리
- `HASH JOIN` → 대량 데이터 조인에 유리
- `COST`, `CARDINALITY` 예측값과 실제 rows 차이가 크면 통계 문제 의심

---

## 인덱스 전략

### 기본 원칙
- 선택도(Selectivity)가 높은 컬럼 우선
- 복합 인덱스: `=` 조건 컬럼 → 범위 조건 컬럼 순서
- WHERE + ORDER BY를 동시에 커버하는 인덱스 설계

### 인덱스 타입
- B-Tree: 기본, 범위 조건에 적합
- Bitmap: 카디널리티 낮은 컬럼, DW 환경 적합 (OLTP에서는 DML 성능 저하 유발)
- Function-Based: `UPPER(name)`, `TO_CHAR(date)` 등 함수 조건
- Composite: 다중 컬럼 조건

### DDL 형식

```sql
-- 기본 인덱스
CREATE INDEX idx_orders_status_date
ON orders(status, order_date);

-- 함수 기반 인덱스
CREATE INDEX idx_orders_upper_name
ON orders(UPPER(customer_name));

-- 비트맵 인덱스 (DW 환경)
CREATE BITMAP INDEX idx_orders_status
ON orders(status);
```

---

## 쿼리 최적화 패턴

### 힌트 사용

```sql
-- 인덱스 강제 지정
SELECT /*+ INDEX(o idx_orders_status_date) */
  o.*
FROM   orders o
WHERE  o.status = 'COMPLETE';

-- 조인 방식 지정
SELECT /*+ USE_NL(o d) */ ...   -- Nested Loop 강제
SELECT /*+ USE_HASH(o d) */ ... -- Hash Join 강제

-- 병렬 처리
SELECT /*+ PARALLEL(o 4) */ ...
```

### 자주 쓰는 리라이팅 패턴
- `NOT IN` → `NOT EXISTS` (NULL 처리 안전)
- `OR` 조건 → `UNION ALL` (각 조건에 인덱스 활용)
- 스칼라 서브쿼리 반복 → `WITH` 절로 추출 (CTE)
- `ROWNUM` 페이징 → `ROW_NUMBER() OVER()` 방식

---

## 옵티마이저 특성

### CBO (Cost-Based Optimizer)
Oracle CBO는 통계 기반으로 플랜을 선택한다. 통계가 깨지면 CBO 판단 전체가 틀어진다.

주요 비용 요소:
- `DB_FILE_MULTIBLOCK_READ_COUNT` — 멀티블록 읽기 단위
- `OPTIMIZER_INDEX_COST_ADJ` — 인덱스 접근 선호도 (기본 100)
- `OPTIMIZER_INDEX_CACHING` — 인덱스 버퍼 캐시 기대율

### Bind Variable Peeking
첫 실행 시 바인드 값으로 플랜을 만들고 캐시한다. 이후 다른 값이 와도 같은 플랜을 쓴다.
데이터 쏠림이 심한 컬럼에서 문제 발생. `_optim_peek_user_binds = FALSE`로 비활성화 가능하나 권장하지 않는다.

### Adaptive Cursor Sharing (11g+)
바인드 값 분포에 따라 여러 플랜을 보관. 첫 실행 플랜이 나쁘면 자동으로 재컴파일.

### SQL Plan Baseline
좋은 플랜을 고정시키는 공식 메커니즘. 힌트보다 안전하다.
`DBMS_SPM.LOAD_PLANS_FROM_CURSOR_CACHE`로 캡처한다.

---

## 통계 시스템

### 자동 통계 수집
- 기본: 매일 밤 유지보수 창에서 `DBMS_STATS.GATHER_DATABASE_STATS_JOB_PROC` 실행
- 10% 이상 변경된 테이블이 대상
- 샘플링: `DBMS_STATS.AUTO_SAMPLE_SIZE` 사용 (해시 기반, 빠르고 정확)

### 히스토그램 종류
- **Frequency** — 고유값이 254개 이하일 때
- **Top-Frequency** (12c+) — 상위 값만 추적
- **Hybrid** (12c+) — Height-Balanced 개선판
- **Height-Balanced** (11g-) — 구형, 부정확

쏠림이 있는 컬럼에는 히스토그램 필수:

```sql
EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, '테이블명',
  METHOD_OPT => 'FOR COLUMNS SIZE AUTO 컬럼명');
```

### 확장 통계 (Extended Statistics)
다중 컬럼 상관관계, 함수 표현식 통계를 수집한다.

```sql
-- 다중 컬럼 상관관계 (city, zipcode 같은 경우)
SELECT DBMS_STATS.CREATE_EXTENDED_STATS(USER, 'orders', '(city, zipcode)')
FROM   dual;

-- 함수 기반
SELECT DBMS_STATS.CREATE_EXTENDED_STATS(USER, 'orders', '(UPPER(customer_name))')
FROM   dual;

EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'orders');
```

---

## Oracle 특유의 함정

### OR-Expansion 미적용
OR 조건에 인덱스가 있어도 CBO가 OR-Expansion을 안 할 때가 있다.
`USE_CONCAT` 힌트 또는 UNION ALL로 수동 변환.

### NULL과 B-Tree 인덱스
B-Tree 인덱스는 NULL을 저장하지 않는다. `WHERE col IS NULL`은 인덱스 사용 불가.
해법: 함수 기반 인덱스 `CREATE INDEX idx ON t(NVL(col, 'X'))`.

### Clustering Factor
인덱스 스캔 후 테이블 접근 효율을 결정한다.
값이 테이블 블록 수에 가까우면 좋고, rows 수에 가까우면 나쁘다.

```sql
SELECT index_name, clustering_factor, num_rows, leaf_blocks
FROM   user_indexes
WHERE  table_name = '테이블명';
```

### Parallel 실행의 함정
`PARALLEL` 힌트는 대량 처리에는 좋지만 OLTP에는 독이 된다.
PX 프로세스 자원 소모와 조율 오버헤드가 크다.

---

## 실전 진단 쿼리

### 실제 실행 통계 (v$sql_monitor, 12c+)

```sql
SELECT DBMS_SQLTUNE.REPORT_SQL_MONITOR(
         sql_id => 'sql_id_값',
         type   => 'TEXT')
FROM   dual;
```

### 캐시에 있는 실제 플랜

```sql
SELECT * FROM TABLE(
  DBMS_XPLAN.DISPLAY_CURSOR('sql_id_값', NULL, 'ALLSTATS LAST'));
```

### 가장 느린 SQL 찾기

```sql
SELECT sql_id,
       executions,
       elapsed_time/1000000              AS elapsed_sec,
       elapsed_time/executions/1000000   AS avg_sec,
       sql_text
FROM   v$sql
WHERE  executions > 0
ORDER  BY elapsed_time DESC
FETCH  FIRST 20 ROWS ONLY;
```

---

## 주의사항
- 함수로 감싼 컬럼은 인덱스 무효화: `TO_CHAR(order_date, 'YYYY') = '2024'` → Function-Based Index 또는 범위 조건으로 변환
- 암묵적 형변환 주의: 문자 컬럼에 숫자 바인딩 시 인덱스 무효화
- `LIKE '%keyword'` 앞 와일드카드는 인덱스 미사용
- Bind Variable Peeking: 특정 값으로 만든 플랜이 다른 값에서 비효율적일 수 있음
