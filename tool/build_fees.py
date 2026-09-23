# -*- coding: utf-8 -*-
"""
펫클(Petcli) 진료비 시세 데이터 빌드 스크립트

animalclinicfee_전국_전체항목.csv (공개 동물병원 진료비 조사 원자료)를
앱이 번들로 싣는 assets/fees.json으로 변환한다. Firestore 미사용 —
정적 JSON을 앱 시작 시 로드해 메모리에서 조회한다(CLAUDE.md 데이터
원칙과 동일한 패턴).

사용법:
    cd tool
    python3 build_fees.py

CSV가 갱신되면(새 조사 데이터로 교체) 같은 파일명으로 이 디렉터리에
덮어쓴 뒤 다시 실행하면 assets/fees.json이 갱신된다.

절대 원칙(CLAUDE.md와 동일):
  - 항목명은 CSV 원본 "_항목" 값을 그대로 쓴다(체중 구분 접미사만
    분리) — "흉부 엑스레이" 같은 임의 라벨을 새로 만들지 않는다.
  - min == max인 지역·항목은 sampleLow=true로 표시해 앱이 "참고용"
    안내를 붙일 수 있게 한다. 표본 개수 자체는 원자료에 없으므로
    만들어내지 않는다.
"""
import csv
import json
from collections import defaultdict
from pathlib import Path

CSV_PATH = Path(__file__).parent / "animalclinicfee_전국_전체항목.csv"
OUT_PATH = Path(__file__).parent.parent / "assets" / "fees.json"

# CSV의 "_항목" 값(체중 접미사 제외한 기본형) -> (영문 id, 카테고리).
# 카테고리 순서·항목 순서는 지시서의 화면 22 탭 순서를 그대로 따른다.
ITEM_DEFS = [
    ("초진 진찰료", "consult_first", "진찰"),
    ("재진 진찰료", "consult_revisit", "진찰"),
    ("진찰에 대한 상담료", "consult_fee", "진찰"),
    ("종합백신 접종비 개", "vaccine_combo_dog", "백신"),
    ("종합백신 접종비 고양이", "vaccine_combo_cat", "백신"),
    ("광견병백신 접종비", "vaccine_rabies", "백신"),
    ("켄넬코프백신 접종비", "vaccine_kennel_cough", "백신"),
    ("코로나바이러스백신 접종비", "vaccine_corona", "백신"),
    ("인플루엔자백신 접종비", "vaccine_influenza", "백신"),
    ("전혈구 검사비와 판독료", "test_cbc", "검사"),
    ("혈액화학 검사비와 판독료", "test_chemistry", "검사"),
    ("전해질 검사비와 판독료", "test_electrolyte", "검사"),
    ("엑스선 촬영비와 판독료", "xray", "영상"),
    ("초음파 검사비와 판독료", "ultrasound", "영상"),
    ("CT비와 판독료", "ct", "영상"),
    ("MRI비와 판독료", "mri", "영상"),
    ("입원비 개", "hospitalization_dog", "입원"),
    ("입원비 고양이", "hospitalization_cat", "입원"),
    ("심장사상충 예방비", "prevention_heartworm", "예방"),
    ("외부기생충 예방비", "prevention_external_parasite", "예방"),
    ("광범위 구충비", "prevention_deworming", "예방"),
]
BASE_NAME_TO_ID = {base: item_id for base, item_id, _category in ITEM_DEFS}

WEIGHT_SUFFIXES = {" 5kg": "u5", " 10kg": "u10", " 20kg": "u20"}

# CSV의 ADDR1_NM(공식 시도명) -> 앱이 실제 쓰는 축약 시도 키
# (assets/hospitals.json과 동일한 어휘 — lib/models/region_filter.dart가
# 이 값으로 병원 데이터를 필터링하므로 진료비 조회도 같은 키를 써야
# 검색 결과·홈 화면의 현재 선택 지역과 맞아떨어진다). 광주광역시와
# 전라남도는 hospitals.json에서 이미 "전남광주통합" 하나로 합쳐져
# 있으므로 여기서도 같은 키로 합친다.
SIDO_MAP = {
    "강원특별자치도": "강원",
    "경기도": "경기",
    "경상남도": "경상남",
    "경상북도": "경상북",
    "광주광역시": "전남광주통합",
    "대구광역시": "대구",
    "대전광역시": "대전",
    "부산광역시": "부산",
    "서울특별시": "서울",
    "세종특별자치시": "세종",
    "울산광역시": "울산",
    "인천광역시": "인천",
    "전라남도": "전남광주통합",
    "전북특별자치도": "전북",
    "제주특별자치도": "제주",
    "충청남도": "충청남",
    "충청북도": "충청북",
}

META = {
    "source": "동물병원 진료비 조사 공개 데이터",
    "baseDate": "2026-09-01",
}


def split_item(raw_name: str) -> tuple[str, str]:
    """CSV "_항목" 값을 (기본 항목명, 체중 키)로 나눈다. 체중 구분이
    없는 항목은 체중 키로 "default"를 쓴다."""
    for suffix, weight_key in WEIGHT_SUFFIXES.items():
        if raw_name.endswith(suffix):
            return raw_name[: -len(suffix)], weight_key
    return raw_name, "default"


def main() -> None:
    with CSV_PATH.open(encoding="utf-8-sig") as f:
        rows = list(csv.DictReader(f))

    fees: dict[str, dict[str, dict[str, dict[str, dict]]]] = defaultdict(
        lambda: defaultdict(dict)
    )
    weight_based_ids: set[str] = set()
    seen_item_ids: set[str] = set()
    row_count = 0

    for row in rows:
        base_name, weight_key = split_item(row["_항목"])
        item_id = BASE_NAME_TO_ID.get(base_name)
        if item_id is None:
            raise ValueError(
                f"알 수 없는 항목명: {row['_항목']!r} (기본형 {base_name!r}) — "
                "ITEM_DEFS에 추가가 필요합니다."
            )
        if weight_key != "default":
            weight_based_ids.add(item_id)
        seen_item_ids.add(item_id)

        sido_raw = row["ADDR1_NM"]
        sido = SIDO_MAP.get(sido_raw)
        if sido is None:
            raise ValueError(f"알 수 없는 시도명: {sido_raw!r} — SIDO_MAP에 추가가 필요합니다.")
        sigungu = row["ADDR2_NM"]

        min_price = int(row["MIN_PRICE"])
        mid_price = int(row["MID_PRICE"])
        max_price = int(row["MAX_PRICE"])

        region_fees = fees[sido][sigungu].setdefault(item_id, {})
        if weight_key in region_fees:
            raise ValueError(
                f"중복 데이터: {sido}/{sigungu}/{item_id}/{weight_key}"
            )
        region_fees[weight_key] = {
            "mid": mid_price,
            "min": min_price,
            "max": max_price,
            "sampleLow": min_price == max_price,
        }
        row_count += 1

    missing = set(BASE_NAME_TO_ID.values()) - seen_item_ids
    if missing:
        raise ValueError(f"CSV에 없는 정의된 항목: {missing}")

    items = [
        {
            "id": item_id,
            "name": base_name,
            "category": category,
            "weightBased": item_id in weight_based_ids,
        }
        for base_name, item_id, category in ITEM_DEFS
    ]

    output = {
        "meta": META,
        "categories": ["진찰", "백신", "검사", "영상", "입원", "예방"],
        "items": items,
        "fees": fees,
    }

    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    with OUT_PATH.open("w", encoding="utf-8") as f:
        json.dump(output, f, ensure_ascii=False, separators=(",", ":"))

    sido_count = len(fees)
    sigungu_count = sum(len(v) for v in fees.values())
    print(f"CSV 행 수: {len(rows)}, 변환된 시세 행 수: {row_count}")
    print(f"항목 {len(items)}개(체중구분 {len(weight_based_ids)}개 포함), "
          f"시도 {sido_count}개, 시군구 {sigungu_count}개")
    print(f"-> {OUT_PATH}")


if __name__ == "__main__":
    main()
