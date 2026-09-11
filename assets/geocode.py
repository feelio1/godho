# -*- coding: utf-8 -*-
"""
펫병원체크 지오코딩 스크립트
hospitals.json에서 좌표(lat/lng) 없는 병원의 주소를 카카오 로컬 API로 변환해 채운다.

사용법 (PowerShell):
    $env:KAKAO_KEY = "여기에_REST_API_키"
    py geocode.py

동작:
  - hospitals.json 로드 → lat/lng null인 병원만 대상
  - 도로명주소 우선, 실패 시 지번주소로 재시도
  - 카카오 API 호출(초당 제한 고려해 약간의 딜레이)
  - 결과를 hospitals.json에 다시 저장 (원본은 hospitals.json.bak 로 백업)
  - 진행상황과 성공/실패 집계 출력. 중단 후 재실행하면 이미 채워진 건 건너뜀.
"""
import json, os, sys, time, urllib.parse, urllib.request

KEY = os.environ.get("KAKAO_KEY", "").strip()
IN = "hospitals.json"
BAK = "hospitals.json.bak"
LOCAL_API = "https://dapi.kakao.com/v2/local/search/address.json"


def geocode(addr):
    """주소 → (lat, lng) 또는 None. 카카오 로컬 주소검색 API."""
    if not addr:
        return None
    url = LOCAL_API + "?" + urllib.parse.urlencode({"query": addr, "size": 1})
    req = urllib.request.Request(url, headers={"Authorization": f"KakaoAK {KEY}"})
    try:
        with urllib.request.urlopen(req, timeout=10) as r:
            data = json.loads(r.read().decode("utf-8"))
        docs = data.get("documents", [])
        if not docs:
            return None
        d = docs[0]
        # 카카오는 x=경도(lng), y=위도(lat) 문자열로 반환
        return float(d["y"]), float(d["x"])
    except Exception as e:
        # 429(쿼터), 401(키오류) 등은 메시지로 확인
        print(f"    [오류] {e} / 주소: {addr}")
        return None


def main():
    if not KEY:
        sys.exit('환경변수 KAKAO_KEY가 없습니다. PowerShell에서:\n  $env:KAKAO_KEY = "REST_API_키"\n먼저 실행하세요.')
    if not os.path.exists(IN):
        sys.exit(f"{IN} 파일이 현재 폴더에 없습니다. hospitals.json이 있는 폴더에서 실행하세요.")

    bundle = json.load(open(IN, encoding="utf-8"))
    hospitals = bundle["hospitals"]

    # 백업 1회
    if not os.path.exists(BAK):
        json.dump(bundle, open(BAK, "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
        print(f"원본 백업: {BAK}")

    targets = [h for h in hospitals if h.get("lat") is None]
    print(f"좌표 없는 병원: {len(targets)}곳 (전체 {len(hospitals)}곳)")
    if not targets:
        print("채울 대상이 없습니다. 종료.")
        return

    ok = 0
    fail = 0
    for i, h in enumerate(targets, 1):
        addr = h.get("roadAddr") or h.get("jibunAddr")
        res = geocode(addr)
        if res is None and h.get("jibunAddr") and h.get("roadAddr"):
            # 도로명 실패 시 지번으로 재시도
            res = geocode(h["jibunAddr"])
        if res:
            h["lat"], h["lng"] = res
            ok += 1
        else:
            fail += 1
        if i % 50 == 0:
            print(f"  진행 {i}/{len(targets)} · 성공 {ok} 실패 {fail}")
            # 중간 저장(중단 대비)
            json.dump(bundle, open(IN, "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
        time.sleep(0.05)  # 초당 호출 제한 여유

    json.dump(bundle, open(IN, "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
    still = sum(1 for h in hospitals if h.get("lat") is None)
    print(f"\n완료: 성공 {ok} · 실패 {fail}")
    print(f"남은 좌표 없음: {still}곳 (실패분은 주소 정제 후 재시도 가능)")
    print(f"저장: {IN}")


if __name__ == "__main__":
    main()
