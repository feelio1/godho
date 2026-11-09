# 펫클 쇼핑 — 후회없개B2B 상품 가져오기

수집: 2026-11-09, 사업자회원 로그인 상태 (상품 29개 / 옵션 159개)

## 파일
| 파일 | 내용 | 공개 범위 |
|---|---|---|
| `out/products.json` | `products/{id}` — 판매가·옵션·고시 자리 | 앱 공개 |
| `out/supplier_items.json` | `supplier_items/{id}` — 도매가·공급사 링크·옵션별 원가 | **관리자 전용** |
| `out/sellers.json` | `sellers/aggaeng` — 판매자 아깽이상점(직판형) | 앱 공개 |
| `out/review.csv` | 옵션별 도매가·판매가·마진 검토표 | 내부 |
| `raw_nrpet.txt` | 원본 수집 데이터 | 내부 |
| `build_catalog.py` | raw → out 변환 (가격 규칙 바꾸면 다시 실행) | — |
| `import_to_firestore.js` | Firestore에 쓰기 (기본은 미리보기) | — |

## 가격 규칙
- 판매가 = 공급사 공개 소비자가(도매가 ÷ 0.7)를 100원 단위 반올림 → 대체로 **도매가 대비 30% 마진**.
- 정가 취소선 없음(공급사 "정가"는 할인 연출용 숫자라 과장 표시 위험 + 제품 헌법).
- 고객 배송비 3,000원 / 30,000원 이상 무료 / 배변판·켄넬은 별도 배송 4,000원 (`shippingClass: bulky`).

## 쇼핑 설계와 달라진 점 (CC 지시서에 반영할 것)
1. 판매자 = **아깽이상점 1곳**(입점형 → 직판형). 상세 하단 "통신판매중개자" 고지 삭제, 판매자 정보는 아깽이상점.
2. 카테고리에 `apparel`(옷) 추가.
3. 옵션은 2축(색상×사이즈)을 **한 줄 조합**("블루 / M")으로 펼쳐 기존 단일 옵션 구조 유지.
4. 새 필드: `shippingClass`(standard|bulky), `minQty`, `tags`(discontinuing).
5. `supplier_items` 컬렉션 추가 — 보안 규칙에서 **클라이언트 읽기·쓰기 모두 금지**:
   ```
   match /supplier_items/{id} { allow read, write: if false; }
   ```
6. `pricing.dart`: bulky 상품은 별도 배송비(4,000) 계산, 무료배송 기준은 standard 상품에만.

## 오픈 전 반드시
- [ ] 공급사에 **자사 앱 판매 + 이미지/상세 사용 허락** 확인 → 이미지 다운로드 게시판에서 받아 Storage 업로드 → `images` 채우기
- [ ] `notice`(상품정보제공고시) — 공급사 상세 이미지에서 판독해 채움(`gosi_nrpet.json`). 남은 빈칸·이상한 값은 `out/gosi_todo.md`
- [ ] A/S 칸의 【전화번호】 채우기 (gosi_nrpet.json `_common.as`) 후 `python3 build_catalog.py` 다시 실행
- [ ] `sellers.json` 【】 칸 채우기 (사업자번호·통신판매업 번호 등)
- [ ] 양털 조끼패딩 **카키**: 공급사 데이터상 사이즈별 가격이 모두 같음(다른 색은 사이즈별 상승) → 공급사 확인
- [ ] 단종예정 져키 2종: 재고 소진 시 `hidden`
- [ ] 개인정보처리방침에 "배송을 위한 공급업체(후회없개) 제공" 추가
