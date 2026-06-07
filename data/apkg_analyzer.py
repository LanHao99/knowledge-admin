"""
Anki .apkg 卡包分析工具
支持两种路径: AnkiTools 快速预览 + 原生 SQLite 深度解析
用法: python apkg_analyzer.py <apkg文件路径>
"""
import zipfile
import sqlite3
import json
import os
import sys
import textwrap
from pathlib import Path


def analyze_apkg_native(apkg_path: str) -> dict:
    """原生方式解析 .apkg (最可靠)"""
    result = {
        "path": apkg_path,
        "file_size": os.path.getsize(apkg_path),
        "decks": {},
        "models": {},
        "notes": [],
        "cards": [],
        "media_count": 0,
    }

    with zipfile.ZipFile(apkg_path) as zf:
        # ZIP 内部结构
        result["zip_entries"] = [
            {"name": n, "size": zf.getinfo(n).file_size}
            for n in zf.namelist()
        ]

        # 提取媒体文件列表
        try:
            media_raw = zf.read("media")
            # 尝试多种编码
            for enc in ["utf-8", "utf-8-sig", "gbk", "latin-1"]:
                try:
                    media = json.loads(media_raw.decode(enc))
                    result["media_count"] = len(media) - 1  # 去掉 "0" 元条目
                    result["media_files"] = {
                        k: v for k, v in media.items() if k != "0"
                    }
                    break
                except (UnicodeDecodeError, json.JSONDecodeError):
                    continue
        except Exception:
            pass

        # 找 .anki2 并提取为临时 SQLite
        anki2_names = [n for n in zf.namelist() if n.endswith(".anki2")]
        if not anki2_names:
            raise ValueError("apkg 中没有找到 collection.anki2")

        tmp_db = Path(apkg_path).parent / "_tmp.anki2"
        with zf.open(anki2_names[0]) as fsrc:
            tmp_db.write_bytes(fsrc.read())

    try:
        conn = sqlite3.connect(str(tmp_db))
        conn.row_factory = sqlite3.Row
        cur = conn.cursor()

        # --- 集合元数据 ---
        col = dict(cur.execute("SELECT * FROM col").fetchone())
        result["db_version"] = col["ver"]
        result["models"] = json.loads(col["models"])
        result["decks"] = json.loads(col["decks"])
        result["conf"] = json.loads(col["conf"])

        # --- 牌组统计 ---
        for did_str, deck_info in result["decks"].items():
            did = int(did_str)
            cnt = cur.execute(
                "SELECT COUNT(*) FROM cards WHERE did=?", (did,)
            ).fetchone()[0]
            deck_info["card_count"] = cnt

        # --- 笔记类型统计 ---
        for mid_str, model in result["models"].items():
            mid = int(mid_str)
            cnt = cur.execute(
                "SELECT COUNT(*) FROM notes WHERE mid=?", (mid,)
            ).fetchone()[0]
            model["note_count"] = cnt

            # 卡片状态分布
            q_names = {
                -1: "已暂停",
                0: "新建/待学",
                1: "学习中",
                2: "待复习",
                3: "待复习(同日)",
            }
            q_dist = cur.execute(
                """SELECT queue, COUNT(*) as c FROM cards
                   WHERE nid IN (SELECT id FROM notes WHERE mid=?)
                   GROUP BY queue""",
                (mid,),
            ).fetchall()
            model["card_queues"] = {
                q_names.get(q, f"queue_{q}"): c for q, c in q_dist
            }

        # --- 全局统计 ---
        result["total_notes"] = cur.execute(
            "SELECT COUNT(*) FROM notes"
        ).fetchone()[0]
        result["total_cards"] = cur.execute(
            "SELECT COUNT(*) FROM cards"
        ).fetchone()[0]
        result["total_revlog"] = cur.execute(
            "SELECT COUNT(*) FROM revlog"
        ).fetchone()[0]

        # --- 笔记内容 ---
        notes = cur.execute(
            "SELECT id, mid, flds, tags, sfld FROM notes ORDER BY id"
        ).fetchall()
        for n in notes:
            mid = str(n["mid"])
            model = result["models"].get(mid, {})
            fld_names = [f["name"] for f in model.get("flds", [])]
            fields = n["flds"].split("\x1f")
            result["notes"].append(
                {
                    "id": n["id"],
                    "model_name": model.get("name", "?"),
                    "fields": {
                        (fld_names[i] if i < len(fld_names) else f"field_{i}"): f
                        for i, f in enumerate(fields)
                    },
                    "tags": n["tags"],
                    "sort_field": n["sfld"],
                }
            )

        # --- 卡片信息 ---
        cards = cur.execute(
            "SELECT id, nid, did, ord, type, queue, due, ivl, reps, lapses FROM cards ORDER BY id"
        ).fetchall()
        for c in cards:
            deck_name = result["decks"].get(str(c["did"]), {}).get("name", "?")
            result["cards"].append(
                {
                    "id": c["id"],
                    "note_id": c["nid"],
                    "deck": deck_name,
                    "ord": c["ord"],
                    "type": c["type"],
                    "queue": c["queue"],
                    "due": c["due"],
                    "interval": c["ivl"],
                    "reps": c["reps"],
                    "lapses": c["lapses"],
                }
            )

        conn.close()
    finally:
        if tmp_db.exists():
            tmp_db.unlink()

    return result


def print_report(result: dict):
    """打印分析报告"""
    print("=" * 65)
    print("  Anki .apkg 解析报告")
    print("=" * 65)
    print(f"  文件: {result['path']}")
    print(f"  大小: {result['file_size']:,} bytes")
    print(f"  数据库版本: {result.get('db_version', '?')}")
    print(
        f"  笔记: {result['total_notes']} | 卡片: {result['total_cards']} | 复习记录: {result['total_revlog']}"
    )

    # 牌组
    decks = result["decks"]
    print(f"\n{'─' * 50}")
    print(f"  【牌组】{len(decks)} 个")
    for did, d in sorted(decks.items()):
        print(f"    [{did}] {d['name']}  (卡片: {d.get('card_count', 0)})")

    # 笔记类型
    models = result["models"]
    print(f"\n{'─' * 50}")
    print(f"  【笔记类型】{len(models)} 个")
    for mid, m in sorted(models.items()):
        flds = [f["name"] for f in m["flds"]]
        tmpls = [t["name"] for t in m["tmpls"]]
        print(f"    [{mid}] {m['name']}")
        print(f"      字段: {flds}")
        print(f"      卡片模板: {tmpls}")
        print(f"      笔记数: {m.get('note_count', 0)}")
        if m.get("card_queues"):
            print(f"      卡片状态: {m['card_queues']}")

    # 媒体文件
    media_count = result.get("media_count", 0)
    if media_count:
        print(f"\n{'─' * 50}")
        print(f"  【媒体文件】{media_count} 个")
        media_files = result.get("media_files", {})
        for k, v in list(media_files.items())[:10]:
            print(f"    [{k}] {v}")
        if len(media_files) > 10:
            print(f"    ... 共 {len(media_files)} 个")

    # 笔记内容
    notes = result["notes"]
    if notes:
        print(f"\n{'─' * 50}")
        print(f"  【笔记内容】共 {len(notes)} 条")
        for n in notes[:20]:
            print(f"\n    [{n['model_name']}] id={n['id']}")
            for fname, fval in n["fields"].items():
                val = fval.strip()[:120]
                if val:
                    print(f"      [{fname}] {val}")
            if n["tags"]:
                print(f"      tags: {n['tags']}")

    # 卡片信息
    cards = result["cards"]
    if cards:
        q_names = {
            -1: "暂停",
            0: "新建",
            1: "学习中",
            2: "待复习",
            3: "待复习(日)",
        }
        print(f"\n{'─' * 50}")
        print(f"  【卡片信息】共 {len(cards)} 张")
        for c in cards[:10]:
            q_label = q_names.get(c["queue"], f"q{c['queue']}")
            print(
                f"    [id={c['id']}] 牌组={c['deck']} | "
                f"间隔={c['interval']}d | 复习{c['reps']}次 | "
                f"忘记{c['lapses']}次 | 状态={q_label}"
            )

    print(f"\n{'=' * 65}")


# ==================== AnkiTools 快速转换 ====================
def convert_with_ankitools(apkg_path: str, out_dir: str = None):
    """使用 AnkiTools 转换为 XLSX"""
    if out_dir is None:
        out_dir = os.path.dirname(apkg_path)
    out_file = os.path.join(out_dir, os.path.basename(apkg_path).replace(".apkg", "_anki.xlsx"))

    try:
        from AnkiTools import anki_convert

        anki_convert(apkg_path, out_file=out_file)
        print(f"  AnkiTools 导出: {out_file}")
        return out_file
    except ImportError:
        print("  [跳过] AnkiTools 未安装 (pip install AnkiTools)")
        return None
    except Exception as e:
        print(f"  [失败] AnkiTools 转换出错: {e}")
        return None


# ==================== 主入口 ====================
if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("用法: python apkg_analyzer.py <apkg文件路径>")
        print("示例: python apkg_analyzer.py 测试牌组.apkg")
        sys.exit(1)

    apkg_path = sys.argv[1]
    if not os.path.exists(apkg_path):
        print(f"文件不存在: {apkg_path}")
        sys.exit(1)

    # 方法1: AnkiTools 快速导出 XLSX
    print("\n[1/2] AnkiTools 转换...")
    xlsx_file = convert_with_ankitools(apkg_path)

    # 方法2: 原生 SQLite 深度解析
    print("\n[2/2] 原生 SQLite 深度解析...\n")
    result = analyze_apkg_native(apkg_path)
    print_report(result)
