"""Read-only checks for maintenance boundaries and explicit resource references."""

from pathlib import Path
import re
import sys
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[1]


def verify() -> int:
    """Check first-party layout and resource references; return a process exit code."""
    problems: list[str] = []
    scenes = list((ROOT / "content/scenes").rglob("*.tscn")) + list((ROOT / "tests/scenes").rglob("*.tscn"))
    scripts = list((ROOT / "src").rglob("*.gd")) + list((ROOT / "tests").rglob("*.gd"))
    for path in (ROOT / "content").rglob("*"):
        if path.suffix in {".gd", ".gdshader"}:
            problems.append(f"Implementation in content/: {path.relative_to(ROOT)}")
        if path.suffix == ".tscn" and not path.is_relative_to(ROOT / "content/scenes"):
            problems.append(f"Scene outside content/scenes/: {path.relative_to(ROOT)}")
    for path in (ROOT / "src").rglob("*.tscn"):
        problems.append(f"Scene in src/: {path.relative_to(ROOT)}")
    for path in (ROOT / "tests").rglob("*.tscn"):
        if not path.is_relative_to(ROOT / "tests/scenes"):
            problems.append(f"Test scene outside tests/scenes/: {path.relative_to(ROOT)}")
    for folder in ("assets", "scenes", "game", "data"):
        if (ROOT / folder).exists():
            problems.append(f"Obsolete top-level content directory: {folder}")
    resources = scenes + list((ROOT / "content").rglob("*.tres"))
    references = 0
    for path in resources:
        text = path.read_text(encoding="utf-8-sig")
        for target in re.findall(r'^\[ext_resource\b[^\n]*\bpath="(res://[^"\n]+)"', text, re.M):
            references += 1
            if not (ROOT / target.removeprefix("res://")).exists():
                problems.append(f"Missing dependency in {path.relative_to(ROOT)}: {target}")
    for path in scripts:
        if path.read_bytes().startswith(b"\xef\xbb\xbf"):
            problems.append(f"GDScript has UTF-8 BOM: {path.relative_to(ROOT)}")
    for relative in ("readme.md", "content/README.md", "src/README.md", "tests/README.md", "tools/README.md", "docs/file_maintenance.md"):
        path = ROOT / relative
        for link in re.findall(r"\[[^\]]*\]\(([^)]+)\)", path.read_text(encoding="utf-8-sig")):
            if link.startswith(("https://", "http://", "#", "mailto:")):
                continue
            target = unquote(link.split("#", 1)[0])
            if target and not (path.parent / target).exists():
                problems.append(f"Missing documentation target in {relative}: {target}")
    print(f"LAYOUT: {len(scenes)} scenes, {len(scripts)} scripts, {references} external references")
    for problem in problems:
        print(problem)
    print(f"LAYOUT {'PASS' if not problems else 'FAIL'}: {len(problems)} problems")
    return int(bool(problems))


if __name__ == "__main__":
    sys.exit(verify())
