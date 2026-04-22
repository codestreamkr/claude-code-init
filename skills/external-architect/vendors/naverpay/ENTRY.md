# naverpay ENTRY

네이버페이 관련 요청이면 이 파일을 먼저 읽는다.

## 이 벤더에서 먼저 볼 것

- 결제 예약, 결제창 호출, `returnUrl` 또는 `onAuthorize`, 승인 API 흐름이 분리돼 있는지
- 결제 예약 ID와 결제 번호 저장 구조
- 멱등 헤더 사용 여부
- 거래 완료, 포인트 적립, 후속 정산 API 사용 범위
- 단건 결제 외 자동결제나 정산 API까지 포함되는지

## 다음 로딩 순서

1. [vendor-facts.md](vendor-facts.md)
2. [report-template.md](report-template.md)
3. [proposal-template.md](proposal-template.md)
4. [final-doc-template.md](final-doc-template.md)
