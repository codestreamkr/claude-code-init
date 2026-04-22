# kakaopay vendor-facts

> 이 문서는 설계 요약본이다. 이벤트명, 상태값, 헤더명, 수치, 지원 범위는 최종 문서 작성 전에 공식 문서로 다시 확인한다.

## 적용 범위

- 이 문서의 내용은 연동 방식, 결제수단, 계약 범위에 따라 달라질 수 있다.
- 일반결제, 가상계좌, 정기결제, 해외 간편결제, 후속 API 범위는 공식 문서 기준으로 최종 확인한다.

## 핵심 식별자

- `tid`: 거래 식별자
- `partner_order_id`: 가맹점 주문번호
- `partner_user_id`: 가맹점 사용자 식별자
- `pg_token`: 승인에 쓰는 일회성 토큰

## 상태와 채널

- `ready` 성공은 결제 완료가 아님
- `approval_url`은 승인 트리거 전달 채널
- `approve` 성공이 최종 승인 기준
- 공개 문서 기준 일반 결제용 웹훅보다 리다이렉트와 서버 승인 호출이 핵심

## 멱등과 운영 포인트

- Secret Key 인증 사용
- `tid` 저장이 필수
- `partner_order_id`는 중복 검증 필드가 아님
- 등록 도메인과 URL 검증 정책을 확인해야 함

## 공식 레퍼런스

- https://developers.kakaopay.com/docs/payment/online/online-getting-started
- https://developers.kakaopay.com/docs/payment/online/single-payment
- https://developers.kakaopay.com/docs/payment/online/cancellation
- https://developers.kakaopay.com/docs/payment/online/reference
