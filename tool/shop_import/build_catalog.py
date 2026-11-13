"""후회없개B2B 수집 데이터(raw_nrpet.txt) → 펫클 쇼핑 Firestore 가져오기 파일

출력
  out/products.json        products/{id}        (앱 공개 — 판매가만, 원가 없음)
  out/supplier_items.json  supplier_items/{id}  (관리자 전용 — 도매가·공급사 링크)
  out/sellers.json         sellers/aggaeng      (판매자 = 아깽이상점, 직판형)
  out/review.csv           가격·마진 검토표 (엑셀로 열기)

가격 원칙
  - 판매가 = 공급사가 사이트에 공개한 소비자가(= 사업자 도매가 ÷ 0.7)를 100원 단위 반올림.
  - '정가 취소선'은 쓰지 않는다(price만, salePrice 없음). 공급사 정가는 할인 연출용이라
    그대로 쓰면 과장 표시가 되고 제품 헌법(미끼 금지)과도 어긋난다.
"""
import csv
import json
import pathlib

ROOT = pathlib.Path(__file__).parent
OUT = ROOT / "out"
SUPPLIER = "nr-pet"
SUPPLIER_NAME = "후회없개B2B"
SELLER_ID = "aggaeng"
PG_RATE = 0.035          # PG 수수료 가정 (계약 후 실제 요율로 교체)
SHIP_FEE = 3000          # 고객 배송비(일반)
FREE_OVER = 30000        # 무료배송 기준
BULKY_FEE = 4000         # 배변판·켄넬(공급사 별도 배송)

CATEGORY = {"강아지간식": "treat", "강아지옷": "apparel", "강아지 장난감": "toy"}
HYGIENE = ("배변",)
NOTICE = {
    "treat": ["사료의 명칭", "성분등록번호", "사용한 원료의 명칭", "등록성분량", "내용량",
              "제조(수입)업자", "제조연월일·유통기한", "보관방법·주의사항", "소비자상담 전화번호"],
    "apparel": ["제품 소재", "색상", "치수", "제조자(수입자)", "제조국", "세탁방법 및 취급시 주의사항",
                "제조연월", "품질보증기준", "A/S 책임자와 전화번호"],
    "_default": ["품명 및 모델명", "법에 의한 인증·허가 등을 받았음을 확인할 수 있는 경우 그에 대한 사항",
                 "제조국 또는 원산지", "제조자(수입자)", "A/S 책임자와 전화번호"],
}
HOLD = {   # 판매 보류(앱에서 숨김) — 확인되면 여기서 지우고 다시 실행
    "nr-ythpm5lf6l23": "노즈워크 장난감: 공급사 공지(2025-08-12) 품절·단종 목록 + 포장이 유명 초콜릿바 상표와 비슷 → 판매 안 함",
}
MIN_QTY = {"f5shengfqtva": 10}   # 배변봉투 1P: 낱개 판매는 배송비보다 싸서 10개 단위


def r100(x: float) -> int:
    return int(round(x / 100.0) * 100)


def retail(ws: int) -> int:
    return r100(ws / 0.7)


def parse():
    items, overrides = [], {}
    for line in (ROOT / "raw_nrpet.txt").read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        if line.startswith("@"):
            pid, rest = line[1:].split("~", 1)
            overrides[pid] = {k: int(v) for k, v in (p.strip().rsplit(" ", 1) for p in rest.split(","))}
            continue
        f = line.split("~")
        items.append(dict(id=f[0], name=f[1], out=f[2] == "1", list=int(f[3]), ws=int(f[4]),
                          pub=int(f[5]), opts=f[6], outOpts=[x for x in f[7].split("|") if x],
                          ship=int(f[9]), method=f[10], cat=f[11]))
    return items, overrides


def option_axes(spec: str):
    axes = []
    for part in [p for p in spec.split(";") if p]:
        name, vals = part.split(" → ")
        axes.append((name.strip(), vals.split("/")))
    return axes


def combos(axes):
    if not axes:
        return [""]
    res = [""]
    for _, vals in axes:
        res = [f"{a}/{v}" if a else v for a in res for v in vals]
    return res


def ws_for(label: str, base: int, ov: dict) -> int:
    if not ov:
        return base
    if label in ov:
        return ov[label]
    tail = label.split("/")[-1]
    return ov.get(f"*/{tail}", base)


def category_of(it):
    if it["cat"] in CATEGORY:
        return CATEGORY[it["cat"]]
    return "hygiene" if any(k in it["name"] for k in HYGIENE) else "living"


GOSI = json.loads((ROOT / "gosi_nrpet.json").read_text(encoding="utf-8"))
TODO = "확인 필요"


def build_notice(sid: str, name: str, cat: str) -> dict:
    """상품정보제공고시. 공급사 상세 이미지에서 판독한 값(gosi_nrpet.json) + 공통값."""
    g = GOSI.get(sid, {})
    c = GOSI["_common"]
    if cat == "treat" and "byOption" in g:          # 비건간식: 맛마다 등록번호·원료가 다름
        cm, bo = g["common"], g["byOption"]
        per = lambda k: " / ".join(f"{flav}: {v[k]}" for flav, v in bo.items())
        return {
            "사료의 명칭": f"{cm['사료의 명칭']} ({per('제품명')})",
            "사료의 종류·형태·용도": f"{cm['사료의 종류']} · {cm['사료의 형태']} · {cm['사용 용도']}",
            "성분등록번호": per("성분등록번호"),
            "사용한 원료의 명칭": per("사용한 원료"),
            "등록성분량": per("등록성분량"),
            "내용량": cm["내용량"],
            "제조(수입)업자": f"{cm['제조원']} (제조국 {cm['제조국']})",
            "제조연월일·유통기한": cm["유통기한"],
            "급여량": cm["급여량"],
            "보관방법·주의사항": f"{cm['보관방법']}. {cm['주의사항']}",
            "판매원(공급사)": cm["판매원(공급사)"],
            "소비자상담": c["as"],
        }
    if cat == "treat" and g.get("jerky"):
        jc, f = GOSI["_jerky_common"], g["fields"]
        return {
            "사료의 명칭": f"{jc['사료의 명칭']} ({f['제품명']})",
            "사료의 종류·형태·용도": f"{jc['사료의 종류']} · {jc['사료의 형태']} · {jc['사용 용도']}",
            "성분등록번호": f["성분등록번호"],
            "사용한 원료의 명칭": f["사용한 원료"],
            "등록성분량": f["등록성분량"],
            "내용량": jc["내용량"],
            "제조(수입)업자": f"{jc['제조원']} (제조국 {jc['제조국']}) / 유통원 {jc['유통원']}",
            "제조연월일·유통기한": jc["유통기한"],
            "보관방법·주의사항": f"{jc['보관방법']}. {jc['주의사항']}",
            "인증": jc["인증"],
            "판매원(공급사)": jc["판매원(공급사)"],
            "소비자상담": c["as"],
        }
    if cat == "apparel":
        return {
            "제품 소재": g.get("소재", TODO),
            "색상": g.get("색상", TODO),
            "치수": g.get("치수", TODO),
            "제조자(수입자)": f"{c['importer']} (수입)",
            "제조국": g.get("제조국", "중국"),
            "세탁방법 및 취급시 주의사항": g.get("세탁방법", "제품에 부착된 케어라벨 참조"),
            "제조연월": g.get("제조연월", "입고 시기별 상이 (확인이 필요하면 고객센터로 문의)"),
            "품질보증기준": c["warranty"],
            "A/S 책임자와 전화번호": c["as"],
        }
    notice = {
        "품명 및 모델명": name,
        "소재": g.get("소재", TODO),
        "색상": g.get("색상", "-"),
    }
    for k in ("크기", "구성"):
        if k in g:
            notice[k] = g[k]
    notice.update({
        "법에 의한 인증·허가 사항": g.get("인증", "해당사항 없음"),
        "제조국": g.get("제조국", TODO),
        "제조자(수입자)": f"{c['importer']} (수입)",
        "품질보증기준": c["warranty"],
        "A/S 책임자와 전화번호": c["as"],
    })
    return notice


def main():
    OUT.mkdir(exist_ok=True)
    items, overrides = parse()
    products, supplier_items, review = [], [], []

    for order, it in enumerate(items, start=1):
        pid = f"nr-{it['id']}"
        discontinuing = it["name"].endswith("*")
        name = it["name"].rstrip("*")
        cat = category_of(it)
        axes = option_axes(it["opts"])
        labels = combos(axes)
        ov = overrides.get(it["id"], {})
        ws_by = {lab: ws_for(lab, it["ws"], ov) for lab in labels}
        base_ws = min(ws_by.values())
        base_price = retail(base_ws)

        options = []
        if labels != [""]:
            for i, lab in enumerate(labels, start=1):
                options.append({
                    "id": f"o{i}",
                    "name": lab.replace("/", " / "),
                    "extraPrice": retail(ws_by[lab]) - base_price,
                    "soldOut": lab in it["outOpts"],
                })

        if pid in HOLD:
            status = "hidden"
        elif it["out"] and discontinuing:
            status = "hidden"
        elif it["out"]:
            status = "soldout"
        else:
            status = "active"

        bulky = it["method"] != "택배"
        axes_desc = " · ".join(f"{n} {len(v)}종" for n, v in axes)
        desc_lines = [name]
        if axes_desc:
            desc_lines.append(f"옵션: {axes_desc}")
        if cat == "apparel":
            desc_lines.append("사이즈는 상세 이미지의 실측표를 확인해 주세요.")
        if bulky:
            desc_lines.append("부피가 큰 상품이라 다른 상품과 따로 배송됩니다.")

        products.append({
            "id": pid,
            "sellerId": SELLER_ID,
            "name": name,
            "category": cat,
            "petTypes": ["dog"],
            "lifeStages": ["puppy", "adult", "senior"],
            "price": base_price,
            "images": [],                       # 이미지 사용 허락 후 업로드 (공급사 이미지 다운로드 게시판)
            "description": "\n".join(desc_lines),
            "options": options,
            "notice": build_notice(it["id"], name, cat),
            "shippingClass": "bulky" if bulky else "standard",
            "minQty": MIN_QTY.get(it["id"], 1),
            "status": status,
            "sortOrder": order * 10,
            "tags": ["discontinuing"] if discontinuing else [],
        })

        supplier_items.append({
            "id": pid,
            "productId": pid,
            "supplier": SUPPLIER,
            "supplierName": SUPPLIER_NAME,
            "supplierProductId": it["id"],
            "supplierUrl": f"https://nr-pet.com/products/{it['id']}",
            "supplierName_raw": it["name"].rstrip("*"),
            "wholesale": base_ws,
            "wholesaleByOption": {o["name"]: ws_by[lab] for o, lab in zip(options, labels)} if options else {},
            "supplierShipping": {"method": it["method"], "fee": it["ship"]},
            "supplierListPrice": it["list"],
            "collectedAt": "2026-11-09",
        })

        for lab in labels:
            w = ws_by[lab]
            p = retail(w)
            pg = round(p * PG_RATE)
            margin = p - w - pg
            review.append({
                "상품ID": pid, "분류": cat, "상품명": name, "옵션": lab or "-",
                "도매가": w, "판매가": p, "PG수수료(3.5%)": pg, "개당마진": margin,
                "마진율": f"{margin / p:.0%}", "상태": status,
                "비고": ";".join(x for x in [
                    "단종예정" if discontinuing else "",
                    "옵션품절" if lab in it["outOpts"] else "",
                    "별도배송(4,000)" if bulky else "",
                    f"최소{MIN_QTY[it['id']]}개" if it["id"] in MIN_QTY else "",
                    "공급사 데이터 확인(사이즈별 가격 동일)" if it["id"] == "xm2u5x4y2wxj" and lab.startswith("카키") else "",
                    GOSI.get(it["id"], {}).get("flag", ""),
                ] if x),
            })

    sellers = [{
        "id": SELLER_ID,
        "name": "아깽이상점",
        "brandName": "펫클 스토어",
        "ceoName": "박수연",
        "bizRegNo": "105-28-52433",
        "mailOrderNo": "제2026-인천검단-0037호",
        "address": "인천광역시 검단구 솔모랭이길 10, 301호(원당동)",
        "csPhone": "010-4447-1891",
        "csEmail": "miyaongshop@gmail.com",
        "shipping": {"baseFee": SHIP_FEE, "freeOver": FREE_OVER, "bulkyFee": BULKY_FEE,
                     "extraJejuFee": 3000, "carrier": "공급사 지정 택배", "dispatchDays": 1},
        "returnPolicy": {"returnFee": 3000, "exchangeFee": 6000,
                         "returnAddress": "인천 서구 여우재로 106 1층 (공급사 반품지)",
                         "note": "단순변심 수령 후 7일 이내 / 불량 30일 이내. 간식은 포장 개봉 시 단순변심 반품 불가."},
        "status": "active",
    }]

    (OUT / "products.json").write_text(json.dumps(products, ensure_ascii=False, indent=2), encoding="utf-8")
    (OUT / "supplier_items.json").write_text(json.dumps(supplier_items, ensure_ascii=False, indent=2), encoding="utf-8")
    (OUT / "sellers.json").write_text(json.dumps(sellers, ensure_ascii=False, indent=2), encoding="utf-8")
    with (OUT / "review.csv").open("w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(review[0].keys()))
        w.writeheader()
        w.writerows(review)

    # 고시 빈칸 목록
    todo_lines = []
    for p in products:
        gaps = [k for k, v in p["notice"].items() if v == TODO]
        flag = GOSI.get(p["id"][3:], {}).get("flag")
        if gaps or flag:
            todo_lines.append(f"- {p['name']}: " + ", ".join(gaps) + (f"  ⚠ {flag}" if flag else ""))
    (OUT / "gosi_todo.md").write_text("# 상품정보제공고시 — 공급사에 확인할 칸\n\n" + "\n".join(todo_lines) + "\n", encoding="utf-8")

    # 콘솔 요약
    print(f"products {len(products)} · option rows {len(review)}")
    for p in products:
        print(f"{p['status']:8} {p['category']:8} {p['price']:>7,}원  opts={len(p['options']):>2}  {p['name']}")


if __name__ == "__main__":
    main()
