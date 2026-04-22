# naverpay vendor-facts

> 이 문서는 설계 요약본이다. 이벤트명, 상태값, 헤더명, 수치, 지원 범위는 최종 문서 작성 전에 공식 문서로 다시 확인한다.

## 적용 범위

- 이 문서의 내용은 연동 방식, 결제수단, 계약 범위에 따라 달라질 수 있다.
- 일반결제, 가상계좌, 정기결제, 해외 간편결제, 후속 API 범위는 공식 문서 기준으로 최종 확인한다.

## 핵심 식별자

- 결제 예약 ID
- 결제 번호
- 가맹점 주문번호

## 상태와 채널

- `returnUrl` 또는 `onAuthorize`는 승인 전 전달 채널
- 승인 API 성공이 기본 완료 기준
- 취소 이후 거래 완료, 포인트 적립, 정산 같은 후속 단계가 남을 수 있음

## 멱등과 운영 포인트

- API key 기반 인증
- `X-NaverPay-Idempotency-Key` 지원
- TLS 1.2 이상 필요
- 계약 유형에 따라 후속 API 범위가 달라질 수 있음

## 공식 레퍼런스

- https://docs.pay.naver.com/docs/common/online-payment-overview/
- https://docs.pay.naver.com/docs/onetime-payment/onetime-payment-overview/
- https://docs.pay.naver.com/docs/common/authentication/
- https://docs.pay.naver.com/docs/common/idempotency/
