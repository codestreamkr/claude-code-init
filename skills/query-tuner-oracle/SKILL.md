---
name: ct:query-tuner-oracle
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

## 진단 플로우

증상이 들어오면 순서대로 탄다. 건너뛰면 엉뚱한 곳을 고친다.

1. **느린 쿼리 식별** — `v$sql` / `v$sql_monitor`에서 `elapsed_time / executions` 상위 확보
2. **실측 플랜 확보** — `DBMS_XPLAN.DISPLAY_CURSOR('sql_id', NULL, 'ALLSTATS LAST')`
3. **E-Rows vs A-Rows** — 10배 이상 차이면 통계·히스토그램·확장 통계 의심 (옵티마이저 판단이 틀어진 것)
4. **접근 경로** — `Clustering Factor` / 인덱스 선택도 확인 (`user_indexes`, `user_tab_col_statistics`)
5. **Bind 이슈** — Bind Peeking / Adaptive Cursor 문제는 `v$sql_shared_cursor`로 확인
6. **구조 변경** — 여기까지 통계·경로 이슈가 아니면 쿼리 리라이팅·인덱스 재설계·힌트(최후) 검토

---

## 수치 감각

"많다/적다" 대신 기준으로 말한다.

- **E-Rows vs A-Rows** — 10배 이상 차이면 통계 문제 확정 (1~2배는 정상 오차)
- **Clustering Factor** — `clustering_factor / num_rows > 0.9`면 랜덤 I/O 지배, IOT/커버링/파티셔닝 검토
- **히스토그램 필요성** — `density < 1/num_distinct`면 쏠림 있음 → 히스토그램 필수
- **DB_FILE_MULTIBLOCK_READ_COUNT** — 기본 128은 DW용. OLTP는 16~32 권장
- **OPTIMIZER_INDEX_COST_ADJ** — 기본 100. SSD 환경은 20~50 (인덱스 선호도 상향)
- **통계 stale 기준** — 10% 변경 시 자동 갱신 대상이지만 대용량은 수동 관리 필요
- **Parallel 임계** — OLTP·소규모 테이블은 `PARALLEL` 금지, 수 GB 이상 DW에만

---

## 인덱스 전략

보편 원칙(복합 인덱스 순서, 커버링, 선택도)은 에이전트에서 다룬다. 여기는 Oracle 특유의 타입과 DDL만.

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

### Oracle 특유 리라이팅
- `ROWNUM` 페이징 → `ROW_NUMBER() OVER()` 또는 `OFFSET ... FETCH FIRST` (12c+)
- `DECODE` 중첩 → `CASE WHEN` (가독성과 최적화 힌트 적용 모두 유리)
- `(+)` outer join → ANSI `LEFT/RIGHT JOIN` (옵티마이저가 더 잘 다룸)

공통 리라이팅(`NOT IN`→`NOT EXISTS`, `OR`→`UNION ALL`, 대용량 OFFSET→keyset)은 에이전트 안티패턴에서.

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

## 버전별 차이

새 프로젝트 진단 시 먼저 버전부터 확인한다. 기능 가용성과 기본 동작이 다르다.

- **11g** — Adaptive Cursor Sharing 도입 (Bind Peeking 부작용 완화)
- **12c** — Top-Frequency / Hybrid 히스토그램, Adaptive Plans, `OFFSET ... FETCH FIRST`, In-Memory Column Store, Identity 컬럼
- **18c** — Automatic Indexing (Exadata/Autonomous 한정)
- **19c** — Real-Time Statistics, Automatic SQL Plan Management, SQL 매크로
- **21c+** — Blockchain 테이블, JSON 네이티브 타입, `ANY_VALUE` 집계함수

버전 확인: `SELECT banner_full FROM v$version;`

---

## Oracle 체크리스트

- 통계 갱신 시점 확인 — `last_analyzed` 기준. CBO는 통계가 전부다.
- 쏠림 컬럼은 히스토그램 필수 — 없으면 CBO가 cardinality를 크게 틀린다.
- 다중 컬럼 상관관계는 확장 통계로 — 옵티마이저는 기본적으로 컬럼 간 독립을 가정한다.
- 힌트 전에 통계·확장 통계·SQL Plan Baseline 먼저 검토.
- OLTP 환경에서 `PARALLEL`, `BITMAP` 인덱스는 금기.
