# toss ENTRY

토스 관련 요청이면 이 파일을 먼저 읽는다.

## 이 벤더에서 먼저 볼 것

- 결제위젯인지 결제창 또는 API 개별 연동인지
- 국내 일반결제만인지, 가상계좌와 해외 간편결제까지 포함하는지
- 승인 성공을 완료 기준으로 둘지, 웹훅 보정이 필요한지
- `paymentKey`, `orderId`, `secret` 저장 여부
- `PAYMENT_STATUS_CHANGED`, `DEPOSIT_CALLBACK`, `CANCEL_STATUS_CHANGED` 사용 범위

## 다음 로딩 순서

1. [vendor-facts.md](vendor-facts.md)
2. [report-template.md](report-template.md)
3. [proposal-template.md](proposal-template.md)
4. [final-doc-template.md](final-doc-template.md)
