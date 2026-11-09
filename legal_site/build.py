"""펫클 법률 페이지 빌드: src/*.md → public/*.html

사용법:  python build.py
날짜를 바꾸려면 아래 두 줄만 수정 후 다시 실행.
"""
import pathlib
import markdown

PRIVACY_DATE = "2026년 10월 30일"
TERMS_DATE = "2026년 11월 20일"   # ← 실제 Play 출시일(프로덕션 공개일)로 맞출 것

ROOT = pathlib.Path(__file__).parent
SRC, OUT = ROOT / "src", ROOT / "public"

PAGES = {
    "privacy": "개인정보처리방침",
    "terms": "이용약관",
    "delete-account": "계정 삭제 요청",
}

TEMPLATE = """<!doctype html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title} · 펫클</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=IBM+Plex+Sans+KR:wght@400;600&display=swap" rel="stylesheet">
<style>
:root {{ --navy:#1B4D8C; --cream:#FFF8EC; --ink:#1f2933; --muted:#5b6672; --line:#e6dccb; }}
* {{ box-sizing:border-box; }}
body {{ margin:0; background:var(--cream); color:var(--ink);
  font:16px/1.75 "IBM Plex Sans KR", system-ui, sans-serif; }}
header {{ background:var(--navy); color:#fff; padding:14px 16px; }}
header .wrap {{ display:flex; gap:16px; align-items:center; flex-wrap:wrap; }}
header b {{ font-size:18px; margin-right:auto; }}
header a {{ color:#dce7f5; text-decoration:none; font-size:14px; }}
header a[aria-current] {{ color:#fff; text-decoration:underline; }}
.wrap {{ max-width:760px; margin:0 auto; }}
main {{ padding:28px 16px 64px; }}
h1 {{ color:var(--navy); font-size:26px; line-height:1.35; margin:0 0 20px; }}
h2 {{ color:var(--navy); font-size:19px; margin:36px 0 10px; padding-top:14px; border-top:1px solid var(--line); }}
h3 {{ font-size:16px; margin:22px 0 6px; }}
a {{ color:var(--navy); }}
ul, ol {{ padding-left:22px; }}
blockquote {{ margin:16px 0; padding:10px 14px; background:#fff; border-left:3px solid var(--navy); color:var(--muted); }}
blockquote p {{ margin:0; }}
.table {{ overflow-x:auto; }}
table {{ border-collapse:collapse; width:100%; background:#fff; font-size:14px; margin:10px 0; }}
th, td {{ border:1px solid var(--line); padding:8px 10px; text-align:left; vertical-align:top; }}
th {{ background:#f3ecdf; }}
footer {{ color:var(--muted); font-size:13px; text-align:center; padding:0 16px 32px; }}
</style>
</head>
<body>
<header><div class="wrap"><b>펫클</b>{nav}</div></header>
<main class="wrap">{body}</main>
<footer>© 아깽이상점 · miyaongshop@gmail.com</footer>
</body>
</html>
"""


def nav(current: str) -> str:
    return "".join(
        f'<a href="{slug}.html"{" aria-current=page" if slug == current else ""}>{label}</a>'
        for slug, label in PAGES.items()
    )


def main() -> None:
    OUT.mkdir(exist_ok=True)
    for slug, title in PAGES.items():
        text = (SRC / f"{slug}.md").read_text(encoding="utf-8")
        text = text.replace("{{PRIVACY_DATE}}", PRIVACY_DATE).replace("{{TERMS_DATE}}", TERMS_DATE)
        assert "{{" not in text, f"치환 안 된 자리표시자: {slug}"
        body = markdown.markdown(text, extensions=["tables", "sane_lists"])
        body = body.replace("<table>", '<div class="table"><table>').replace("</table>", "</table></div>")
        (OUT / f"{slug}.html").write_text(TEMPLATE.format(title=title, nav=nav(slug), body=body), encoding="utf-8")
        print("built", slug)
    # 루트 주소는 개인정보처리방침으로
    (OUT / "index.html").write_text(
        '<!doctype html><meta charset="utf-8"><meta http-equiv="refresh" content="0; url=privacy.html">'
        '<a href="privacy.html">개인정보처리방침</a>', encoding="utf-8")


if __name__ == "__main__":
    main()
