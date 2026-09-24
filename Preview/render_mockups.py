#!/usr/bin/env python3
"""Generate deterministic SeeZMemo UI renderings for the supported phones."""

from html import escape
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "renders"
SVG_OUT = OUT / "svg"

DEVICES = {
    "iPhone16": (393, 852, 1179, 2556),
    "iPhone17Pro": (402, 874, 1206, 2622),
}

SCREENS = [
    ("01_home", "首頁"),
    ("02_camera", "拍攝招牌"),
    ("03_editor_photos", "新增店家・照片"),
    ("04_editor_details", "新增店家・資料"),
    ("05_add_photo", "加入照片"),
    ("06_ocr", "辨識店名"),
    ("07_map", "修正位置"),
    ("08_nearby_map", "附近店家地圖"),
    ("09_visit_date", "選擇拜訪時間"),
    ("10_draft_saved", "草稿已保存"),
    ("11_records_list", "全部紀錄清單"),
    ("12_records_map", "全部紀錄地圖"),
    ("13_journal_share", "流水帳分享"),
]


def text(x, y, value, size=15, weight=400, color="#18221e", anchor="start"):
    return f'<text x="{x}" y="{y}" font-size="{size}" font-weight="{weight}" fill="{color}" text-anchor="{anchor}">{escape(value)}</text>'


def rect(x, y, w, h, fill, radius=16, stroke="none", sw=0):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{radius}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>'


def line(x1, y1, x2, y2, color="#d8dedb", sw=1):
    return f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{color}" stroke-width="{sw}"/>'


def status_bar(width):
    return "".join([
        text(24, 27, "9:41", 13, 650),
        rect(width / 2 - 56, 11, 112, 29, "#090b0a", 15),
        text(width - 25, 27, "●  5G  ▰", 11, 600, anchor="end"),
    ])


def nav(width, title, back=False, trailing=""):
    parts = [rect(0, 46, width, 50, "#ffffff", 0), line(0, 96, width, 96, "#edf0ee")]
    if back:
        parts += [text(18, 78, "‹", 32, 350, "#087b58"), text(39, 75, "返回", 15, 500, "#087b58")]
    parts.append(text(width / 2, 76, title, 17, 650, anchor="middle"))
    if trailing:
        parts.append(text(width - 18, 76, trailing, 24, 500, "#087b58", "end"))
    return "".join(parts)


def photo_art(x, y, w, h, label="青沐食堂"):
    return "".join([
        f'<defs><linearGradient id="shop" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#b9d9df"/><stop offset="0.52" stop-color="#f4ddbc"/><stop offset="1" stop-color="#806a55"/></linearGradient></defs>',
        rect(x, y, w, h, "url(#shop)", 16),
        rect(x + 14, y + h * .34, w - 28, h * .34, "#f8f1e6", 4),
        rect(x + 26, y + h * .50, w - 52, h * .18, "#173b2e", 2),
        text(x + w / 2, y + h * .62, label, max(13, min(22, w / 9)), 700, "#ffffff", "middle"),
        rect(x + 28, y + h * .69, w * .23, h * .27, "#252d29", 2),
        rect(x + w * .61, y + h * .69, w * .20, h * .27, "#d5e5df", 2),
    ])


def home(width, height, saved=False):
    p = [rect(0, 0, width, height, "#fff6f6", 0), status_bar(width)]
    p += [rect(20, 54, 48, 48, "#ffffffcc", 24), text(44, 86, "▤", 25, 700, "#111111", "middle"), rect(width-68, 54, 48, 48, "#ffffffcc", 24), text(width-44, 88, "+", 34, 450, "#111111", "middle")]
    p += [rect(20, 122, width - 40, 218, "#d82f43", 34, "#ffffff", 2), rect(width/2-68, 164, 136, 136, "#ffffffdd", 68), text(width / 2, 250, "▣", 72, 800, "#111111", "middle")]
    p += [text(20, 382, "草稿", 21, 700), text(width - 48, 382, "1 筆" if saved else "0 筆", 14, 400, "#69756f", "end"), text(width - 20, 382, "⌄", 19, 600, "#59645f", "end")]
    if saved:
        p += [rect(20, 402, width - 40, 112, "#ffffff", 20), photo_art(32, 416, 82, 82), text(130, 439, "青沐食堂", 17, 650), text(130, 465, "台北市信義區松智路17號", 13, 400, "#69756f"), text(130, 489, "剛剛更新", 12, 400, "#9aa39f"), text(width - 34, 465, "›", 28, 400, "#a6afaa", "end")]
    else:
        p += [text(width / 2, 444, "⌖", 44, 500, "#9eb0a8", "middle"), text(width / 2, 486, "尚無草稿", 19, 650, anchor="middle"), text(width / 2, 513, "可以拍照或點右上角＋新增店家。", 14, 400, "#76817c", "middle")]
    p += [rect(20, 586, width - 40, 94, "#ffffff", 22), text(38, 623, "地圖", 21, 700), text(38, 650, "查看目前位置方圓 2 公里內的店家", 13, 400, "#69756f"), text(width - 47, 643, "●", 42, 700, "#e84848", "middle")]
    p += [text(width/2, height-24, "程式版本 V0.0.3（程式編譯時間 20260916）", 11, 400, "#a5aaa7", "middle")]
    return "".join(p)


def camera(width, height):
    p = [rect(0, 0, width, height, "#0b0e0c", 0), status_bar(width), photo_art(0, 76, width, height - 180)]
    p += [rect(0, height - 142, width, 142, "#090b0a", 0), text(24, height - 102, "取消", 16, 550, "#ffffff")]
    p += [f'<circle cx="{width/2}" cy="{height-69}" r="35" fill="none" stroke="#ffffff" stroke-width="5"/>', f'<circle cx="{width/2}" cy="{height-69}" r="28" fill="#ffffff"/>']
    p += [text(width - 29, height - 65, "↻", 28, 500, "#ffffff", "end"), rect(width / 2 - 62, 56, 124, 31, "#000000aa", 16), text(width / 2, 77, "對準門口或招牌", 13, 600, "#ffffff", "middle")]
    return "".join(p)


def section_card(width, y, h, title, detail=""):
    return "".join([rect(16, y, width - 32, h, "#ffffff", 21), text(32, y + 30, title, 17, 700), text(width - 32, y + 29, detail, 12, 450, "#7b8580", "end") if detail else ""])


def editor_photos(width, height):
    p = [rect(0, 0, width, height, "#f2f3f2", 0), status_bar(width), nav(width, "新增店家", True)]
    p += [section_card(width, 112, 226, "照片", "1 / 10"), photo_art(32, 157, 170, 112), rect(32, 269, 170, 38, "#fff5dc", 8), text(117, 294, "★ 首張", 13, 700, "#c27700", "middle"), rect(216, 157, 142, 150, "#e8f5ef", 18), text(287, 214, "+", 36, 400, "#0f7b58", "middle"), text(287, 245, "加入照片", 14, 650, "#0f7b58", "middle")]
    p += [rect(163, 166, 31, 31, "#ffffffdd", 16), text(178.5, 188, "×", 20, 600, "#d33b3b", "middle")]
    p += [section_card(width, 338, 176, "位置"), text(34, 389, "◆  25.033976, 121.564472", 14, 500), text(34, 423, "台北市信義區松智路 17 號", 14, 400, "#6b756f"), text(width - 45, 413, "●", 40, 700, "#e84b4b", "middle"), rect(31, 450, width - 62, 37, "#f7f8f7", 8, "#d7ddda", 1), text(44, 474, "台北市信義區松智路17號", 13, 400), text(32, 503, "✎  套用最近門牌，可直接修改文字", 12, 550, "#147a58")]
    p += [section_card(width, 520, 160, "店家名稱"), rect(31, 562, width - 62, 39, "#f7f8f7", 8, "#d7ddda", 1), text(44, 587, "輸入店家名稱", 14, 400, "#929b97"), rect(31, 614, width - 62, 45, "#167e5b", 10), text(width / 2, 643, "▣  拍照辨識", 15, 650, "#ffffff", "middle")]
    p += [text(width / 2, height - 18, "向下滑動繼續填寫", 12, 500, "#87918c", "middle")]
    return "".join(p)


def editor_details(width, height):
    p = [rect(0, 0, width, height, "#f2f3f2", 0), status_bar(width), nav(width, "新增店家", True)]
    p += [section_card(width, 112, 160, "店家名稱"), rect(31, 155, width - 62, 39, "#f7f8f7", 8, "#d7ddda", 1), text(44, 180, "青沐食堂", 15, 500), rect(31, 207, width - 62, 44, "#167e5b", 10), text(width / 2, 235, "▣  拍照辨識", 15, 650, "#ffffff", "middle")]
    p += [section_card(width, 288, 146, "店家類型"), rect(31, 331, width - 62, 39, "#f7f8f7", 8, "#d7ddda", 1), text(44, 356, "美食", 15, 500), rect(31, 385, 49, 28, "#eef7f3", 14, "#b9dbcd", 1), text(55, 404, "美食", 11, 550, "#126c4f", "middle"), rect(85, 385, 49, 28, "#ffffff", 14, "#ccd4d0", 1), text(109, 404, "甜點", 11, 500, "#4f5954", "middle"), rect(139, 385, 49, 28, "#ffffff", 14, "#ccd4d0", 1), text(163, 404, "咖啡", 11, 500, "#4f5954", "middle"), rect(193, 385, 49, 28, "#ffffff", 14, "#ccd4d0", 1), text(217, 404, "書店", 11, 500, "#4f5954", "middle"), text(260, 404, "⌄", 17, 600, "#147a58")]
    p += [section_card(width, 450, 132, "店家資料"), rect(31, 493, width - 62, 62, "#f7f8f7", 8, "#d7ddda", 1), text(44, 518, "週二公休，午間定食", 14, 400), text(44, 543, "菜單與營業時間", 14, 400, "#66716c")]
    p += [section_card(width, 598, 105, "拜訪時間", "今日"), text(34, 665, "▣  2026年9月9日", 15, 550, "#147a58"), text(width - 34, 665, "⌄", 16, 600, "#6b756f", "end")]
    p += [rect(16, height - 91, (width - 44) / 2, 52, "#ffffff", 12, "#147a58", 1.5), text(16 + (width - 44) / 4, height - 58, "暫存", 17, 650, "#147a58", "middle"), rect(28 + (width - 44) / 2, height - 91, (width - 44) / 2, 52, "#147a58", 12), text(28 + 3 * (width - 44) / 4, height - 58, "完成", 17, 650, "#ffffff", "middle")]
    return "".join(p)


def photo_sheet(width, height):
    p = [editor_photos(width, height), rect(0, 0, width, height, "#00000044", 0), rect(0, height - 355, width, 355, "#ffffff", 28), rect(width / 2 - 20, height - 341, 40, 5, "#c7cdca", 3), text(width / 2, height - 304, "加入照片", 18, 700, anchor="middle")]
    p += [rect(20, height - 267, width - 40, 59, "#147a58", 13), text(width / 2, height - 230, "●  拍照", 17, 650, "#ffffff", "middle"), rect(20, height - 192, width - 40, 59, "#ffffff", 13, "#147a58", 1.5), text(width / 2, height - 155, "▧  從相簿選擇", 17, 650, "#147a58", "middle"), text(width / 2, height - 83, "取消", 16, 550, "#5f6a65", "middle")]
    return "".join(p)


def ocr_dialog(width, height):
    p = [editor_details(width, height), rect(0, 0, width, height, "#00000055", 0), rect(34, 230, width - 68, 354, "#f7f7f7", 18), text(width / 2, 265, "選擇辨識結果", 18, 700, anchor="middle"), text(width / 2, 289, "從招牌照片擷取到以下文字", 13, 400, "#68726d", "middle")]
    choices = ["青沐食堂", "AOMORI DINING", "日替わり定食", "오늘의 메뉴"]
    for i, choice in enumerate(choices):
        y = 313 + i * 51
        p += [line(34, y, width - 34, y, "#d8dcda"), text(width / 2, y + 32, choice, 16, 550, "#087b58", "middle")]
    p += [line(34, 517, width - 34, 517, "#d8dcda"), text(width / 2, 552, "取消", 16, 600, "#d14a4a", "middle")]
    return "".join(p)


def map_screen(width, height):
    p = [rect(0, 0, width, height, "#edf0eb", 0), status_bar(width), nav(width, "修正位置", True)]
    p += [rect(0, 97, width, height - 355, "#e4efe7", 0)]
    for i in range(7):
        p.append(line(0, 130 + i * 64, width, 110 + i * 64, "#ffffff", 9))
    for i in range(6):
        p.append(line(25 + i * 76, 97, 5 + i * 76, height - 258, "#cddbd2", 2))
    p += [rect(width / 2 - 96, 111, 192, 36, "#ffffffdd", 18), text(width / 2, 135, "輕點地圖修正大頭針位置", 13, 650, anchor="middle"), text(width / 2, 315, "●", 57, 700, "#e94444", "middle"), text(width / 2, 351, "店家位置", 13, 650, anchor="middle")]
    panel_y = height - 258
    p += [rect(0, panel_y, width, 258, "#ffffff", 0), text(20, panel_y + 33, "◆  25.033976, 121.564472", 14, 550), rect(20, panel_y + 51, width - 40, 46, "#f7f8f7", 9, "#d5dcd8", 1), text(33, panel_y + 80, "台北市信義區松智路 17 號", 14, 400), rect(20, panel_y + 112, width - 40, 43, "#ffffff", 10, "#147a58", 1.4), text(width / 2, panel_y + 140, "↗  用 Google Maps 開啟", 15, 600, "#147a58", "middle"), rect(20, panel_y + 169, width - 40, 50, "#147a58", 11), text(width / 2, panel_y + 201, "套用位置", 17, 650, "#ffffff", "middle")]
    return "".join(p)


def nearby_map_screen(width, height):
    p = [rect(0, 0, width, height, "#e6efe8", 0), status_bar(width), nav(width, "附近店家", True, "⚙")]
    for i in range(10):
        p.append(line(0, 120 + i * 70, width, 90 + i * 70, "#ffffff", 8))
    for i in range(7):
        p.append(line(15 + i * 68, 96, 35 + i * 68, height, "#cad9cf", 2))
    p += [f'<circle cx="{width/2}" cy="{height/2}" r="178" fill="#3b82f61b" stroke="#3b82f666" stroke-width="2"/>', f'<circle cx="{width/2}" cy="{height/2}" r="8" fill="#2384e8" stroke="#fff" stroke-width="3"/>']
    pins = [(width*.31, height*.35, "青沐食堂", "美食"), (width*.66, height*.42, "巷口咖啡", "咖啡"), (width*.46, height*.64, "日光雜貨", "特殊販賣物")]
    for x, y, name, kind in pins:
        p += [rect(x-46, y-48, 92, 35, "#ffffffee", 8), text(x, y-33, name, 11, 700, anchor="middle"), text(x, y-20, kind, 9, 450, "#68726d", "middle"), text(x, y+18, "●", 42, 700, "#e43f3f", "middle")]
    p += [rect(55, height-90, width-110, 45, "#ffffffdd", 12), rect(59, height-86, (width-118)/2, 37, "#147a58", 9), text(59+(width-118)/4, height-62, "⌖ 地圖", 13, 650, "#ffffff", "middle"), text(width-59-(width-118)/4, height-62, "☷ 清單", 13, 650, "#56615c", "middle")]
    return "".join(p)


def records_list_screen(width, height):
    p = [rect(0, 0, width, height, "#f3f4f3", 0), status_bar(width), nav(width, "紀錄資料", True, "⌖  ☷")]
    p += [rect(18, 112, width-36, 40, "#ffffff", 10), text(34, 137, "搜尋名稱、類型、國家或資料", 13, 400, "#929a96"), text(width-30, 181, "排序：時間（最近優先）⌄", 13, 600, "#147a58", "end")]
    rows = [("青沐食堂", "美食・台灣", "0.8 公里"), ("日光雜貨", "特殊販賣物・日本", "1.2 公里"), ("巷口咖啡", "咖啡・台灣", "1.7 公里")]
    for i, (name, meta, distance) in enumerate(rows):
        y = 202 + i*108
        p += [rect(16, y, width-32, 94, "#ffffff", 17), photo_art(28, y+12, 70, 70, name), text(112, y+32, name, 16, 700), text(112, y+56, meta, 13, 400, "#68726d"), text(112, y+78, distance, 12, 400, "#989f9b"), text(width-34, y+57, "›", 25, 400, "#a5aaa7", "end")]
    return "".join(p)


def records_map_screen(width, height):
    p = [nearby_map_screen(width, height), rect(0, 46, width, 50, "#ffffff", 0), text(18, 78, "‹ 返回", 15, 500, "#087b58"), text(width/2, 76, "紀錄資料", 17, 650, anchor="middle"), text(width-18, 76, "⌖  ☷", 18, 650, "#087b58", "end")]
    p += [rect(width/2-83, height-126, 166, 34, "#ffffffdd", 17), text(width/2, height-104, "瀏覽範圍共 3 間店家", 12, 650, anchor="middle")]
    return "".join(p)


def journal_share_screen(width, height):
    p = [rect(0, 0, width, height, "#f0f1f0", 0), status_bar(width), editor_details(width, height), rect(0, 0, width, height, "#00000055", 0), rect(0, height-520, width, 520, "#ffffff", 28)]
    p += [text(width/2, height-480, "流水帳分享到 Facebook", 18, 700, anchor="middle"), rect(22, height-446, width-44, 280, "#f7f7f7", 13), text(38, height-418, "<。喵仔流水帳。>", 14, 700), text(38, height-388, "店鋪名稱：青沐食堂", 13, 400), text(38, height-363, "店鋪類型：美食", 13, 400), text(38, height-338, "到遊感想：想再拜訪", 13, 400), text(38, height-313, "店鋪資訊：午間定食", 13, 400), text(38, height-288, "所在位置：台北市信義區…（座標）", 13, 400), text(38, height-263, "紀錄時間：2026年09月16日 14:30", 13, 400), text(38, height-220, "#遊記 #食記 #流水帳本", 13, 650, "#147a58")]
    p += [rect(22, height-140, width-44, 52, "#1877f2", 12), text(width/2, height-107, "f  分享", 17, 700, "#ffffff", "middle"), text(width/2, height-50, "文字已複製，可在 Facebook 貼上", 12, 400, "#69756f", "middle")]
    return "".join(p)


def visit_date_screen(width, height):
    p = [editor_details(width, height), rect(16, 420, width-32, 355, "#ffffff", 22), text(32, 454, "拜訪時間", 17, 700), rect(width-90, 432, 58, 34, "#ffffff", 9, "#147a58", 1), text(width-61, 454, "今日", 14, 650, "#147a58", "middle"), text(32, 493, "▣  2026年9月9日", 15, 550, "#147a58")]
    p += [text(width/2, 532, "2026 年 9 月", 16, 700, anchor="middle")]
    for col, day in enumerate(["日", "一", "二", "三", "四", "五", "六"]):
        p.append(text(45 + col*(width-90)/6, 565, day, 12, 600, "#69756f", "middle"))
    n = 1
    for row in range(5):
        for col in range(7):
            if n <= 30:
                x = 45 + col*(width-90)/6; y = 601 + row*37
                if n == 9: p.append(f'<circle cx="{x}" cy="{y-5}" r="16" fill="#147a58"/>')
                p.append(text(x, y, str(n), 13, 600 if n == 9 else 450, "#ffffff" if n == 9 else "#26302b", "middle")); n += 1
    return "".join(p)


def render_screen(screen, width, height):
    return {
        "01_home": home(width, height),
        "02_camera": camera(width, height),
        "03_editor_photos": editor_photos(width, height),
        "04_editor_details": editor_details(width, height),
        "05_add_photo": photo_sheet(width, height),
        "06_ocr": ocr_dialog(width, height),
        "07_map": map_screen(width, height),
        "08_nearby_map": nearby_map_screen(width, height),
        "09_visit_date": visit_date_screen(width, height),
        "10_draft_saved": home(width, height, True),
        "11_records_list": records_list_screen(width, height),
        "12_records_map": records_map_screen(width, height),
        "13_journal_share": journal_share_screen(width, height),
    }[screen]


def svg_document(width, height, body):
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{width*3}" height="{height*3}" viewBox="0 0 {width} {height}">
<style>text{{font-family:-apple-system,BlinkMacSystemFont,"PingFang TC","Noto Sans CJK TC",sans-serif}}</style>
{body}</svg>'''


def main():
    SVG_OUT.mkdir(parents=True, exist_ok=True)
    for device, (points_w, points_h, pixels_w, pixels_h) in DEVICES.items():
        device_dir = OUT / device
        device_dir.mkdir(parents=True, exist_ok=True)
        for screen, _ in SCREENS:
            svg_path = SVG_OUT / f"{device}_{screen}.svg"
            svg_path.write_text(svg_document(points_w, points_h, render_screen(screen, points_w, points_h)), encoding="utf-8")

    cards = []
    for screen, label in SCREENS:
        cards.append(f'<figure><img src="../renders/iPhone16/{screen}.png" alt="iPhone 16 {label}"><figcaption>iPhone 16 · {label}</figcaption></figure>')
        cards.append(f'<figure><img src="../renders/iPhone17Pro/{screen}.png" alt="iPhone 17 Pro {label}"><figcaption>iPhone 17 Pro · {label}</figcaption></figure>')
    html = f'''<!doctype html><html lang="zh-Hant"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>SeeZMemo V0.0.3 操作渲染圖</title><style>
body{{margin:0;background:#14211c;color:#fff;font-family:-apple-system,BlinkMacSystemFont,"PingFang TC",sans-serif}}header{{padding:42px 5vw 18px}}h1{{margin:0 0 8px;font-size:34px}}p{{margin:0;color:#b9c9c1}}main{{display:grid;grid-template-columns:repeat(auto-fit,minmax(270px,1fr));gap:34px;padding:28px 5vw 60px}}figure{{margin:0;text-align:center}}img{{width:min(100%,294px);border:9px solid #070908;border-radius:38px;box-shadow:0 18px 48px #0008}}figcaption{{margin-top:14px;font-weight:650}}
</style></head><body><header><h1>SeeZMemo V0.0.3</h1><p>店家大頭針 · iPhone 16 / iPhone 17 Pro 全操作頁面</p></header><main>{''.join(cards)}</main></body></html>'''
    (ROOT / "Preview" / "index.html").write_text(html, encoding="utf-8")


if __name__ == "__main__":
    main()
