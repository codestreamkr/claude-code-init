# kcp ENTRY

KCP 관련 요청이면 이 파일을 먼저 읽는다.

## 이 벤더에서 먼저 볼 것

- 표준결제인지, 모바일 결제인지, 자동결제인지
- 서비스 인증서와 서명 데이터가 현재 구조에 반영돼 있는지
- `tno`, `site_cd`, `order_no` 저장 여부
- 가상계좌 웹훅 수신과 방화벽 허용 구조
- 취소 서명 생성과 재시도 처리 구조

## 다음 로딩 순서

1. [vendor-facts.md](vendor-facts.md)
2. [report-template.md](report-template.md)
3. [proposal-template.md](proposal-template.md)
4. [final-doc-template.md](final-doc-template.md)
