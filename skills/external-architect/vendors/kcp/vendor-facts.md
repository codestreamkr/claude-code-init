# kcp vendor-facts

> 이 문서는 설계 요약본이다. 이벤트명, 상태값, 헤더명, 수치, 지원 범위는 최종 문서 작성 전에 공식 문서로 다시 확인한다.

## 적용 범위

- 이 문서의 내용은 연동 방식, 결제수단, 계약 범위에 따라 달라질 수 있다.
- 일반결제, 가상계좌, 정기결제, 해외 간편결제, 후속 API 범위는 공식 문서 기준으로 최종 확인한다.

## 핵심 식별자

- `site_cd`: 상점 코드
- `tno`: 거래 고유번호
- `order_no`: 가맹점 주문번호
- `tx_cd`: 업무 처리 코드

## 상태와 채널

- 승인, 승인취소, 입금대기, 입금완료 등 상태코드 체계가 세분화돼 있음
- 가상계좌 노티가 핵심 비동기 채널
- 일반 상태는 거래상태표 원본을 함께 저장하는 편이 안전

## 멱등과 운영 포인트

- 서비스 인증서 필요
- 취소 시 `kcp_sign_data` 서명 필요
- 웹훅 URL과 IP/포트 허용이 선행돼야 함
- 명시적 멱등 헤더 지원보다 내부 중복 방지가 중요

## 공식 레퍼런스

- https://developer.kcp.co.kr/
- https://developer.kcp.co.kr/page/std
- https://developer.kcp.co.kr/page/document/webhook
- https://developer.kcp.co.kr/page/refer/server
- https://developer.kcp.co.kr/page/refer/statuscode
