# kakaopay ENTRY

카카오페이 관련 요청이면 이 파일을 먼저 읽는다.

## 이 벤더에서 먼저 볼 것

- `ready -> approval_url -> approve` 흐름이 현재 코드에 반영돼 있는지
- `tid`, `partner_order_id`, `pg_token` 저장과 복원 구조
- 승인 완료를 리다이렉트가 아니라 서버 `approve` 성공으로 보고 있는지
- 등록 도메인과 URL 검증 정책을 반영하고 있는지
- 취소와 주문 조회 경로가 분리돼 있는지

## 다음 로딩 순서

1. [vendor-facts.md](vendor-facts.md)
2. [report-template.md](report-template.md)
3. [proposal-template.md](proposal-template.md)
4. [final-doc-template.md](final-doc-template.md)
