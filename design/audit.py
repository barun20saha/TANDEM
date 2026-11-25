#!/usr/bin/env python3
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP_LIB = os.path.join(ROOT, "app", "lib")
TOKENS_DART = os.path.join(APP_LIB, "theme", "tokens.dart")
TOKENS_JSON = os.path.join(ROOT, "design", "tokens.json")
DEV_DIR = os.path.join(APP_LIB, "dev")
AUDIT_MD = os.path.join(ROOT, "design", "AUDIT.md")

HEX_REGEX = re.compile(r"#[0-9a-fA-F]{6}\b")
COLOR_CONSTRUCTOR_REGEX = re.compile(r"Color\(0x[0-9a-fA-F]+\)")
MATERIAL_COLORS_REGEX = re.compile(r"\bColors\.[a-zA-Z0-9_]+\b")
FAKE_DATA_REGEX = re.compile(
    r"\b(pixel\s*9|framework\s+laptop|barun|home\s+desktop|office\s+mac|"
    r"office\s+server|alice|maya|mock|fake|sample|dummy|lorem)\b",
    re.IGNORECASE,
)


def _srgb_channel(c_hex: str) -> float:
    v = int(c_hex, 16) / 255.0
    return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4


def _rel_luminance(hex_color: str) -> float:
    h = hex_color.lstrip("#")
    r = _srgb_channel(h[0:2])
    g = _srgb_channel(h[2:4])
    b = _srgb_channel(h[4:6])
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast_ratio(fg: str, bg: str) -> float:
    l1 = _rel_luminance(fg)
    l2 = _rel_luminance(bg)
    hi, lo = max(l1, l2), min(l1, l2)
    return (hi + 0.05) / (lo + 0.05)


def compute_contrast_rows():
    with open(TOKENS_JSON, "r", encoding="utf-8") as fh:
        tokens = json.load(fh)
    light = {k: v["value"] for k, v in tokens["color"]["light"].items()}
    dark = {k: v["value"] for k, v in tokens["color"]["dark"].items()}

    checks = [
        ("Light primary text on ground", light["color-text"], light["color-ground"], 4.5),
        ("Light primary text on surface", light["color-text"], light["color-surface"], 4.5),
        ("Light direct link on surface", light["color-link-direct"], light["color-surface"], 4.5),
        ("Light on-primary on direct button", light["color-on-primary"], light["color-link-direct"], 4.5),
        ("Light relay text on surface", light["color-link-relay-text"], light["color-surface"], 4.5),
        ("Light relay line graphic on surface", light["color-link-relay"], light["color-surface"], 3.0),
        ("Light ok status on surface", light["color-ok"], light["color-surface"], 4.5),
        ("Light danger on surface", light["color-danger"], light["color-surface"], 4.5),
        ("Light on-primary on danger button", light["color-on-primary"], light["color-danger"], 4.5),
        ("Dark primary text on ground", dark["color-text"], dark["color-ground"], 4.5),
        ("Dark primary text on surface", dark["color-text"], dark["color-surface"], 4.5),
        ("Dark direct link on surface", dark["color-link-direct"], dark["color-surface"], 4.5),
        ("Dark on-primary on direct button", dark["color-on-primary"], dark["color-link-direct"], 4.5),
        ("Dark relay text on surface", dark["color-link-relay-text"], dark["color-surface"], 4.5),
        ("Dark relay line graphic on surface", dark["color-link-relay"], dark["color-surface"], 3.0),
        ("Dark ok status on surface", dark["color-ok"], dark["color-surface"], 4.5),
        ("Dark danger on surface", dark["color-danger"], dark["color-surface"], 4.5),
        ("Dark on-primary on danger button", dark["color-on-primary"], dark["color-danger"], 4.5),
    ]
    rows = []
    failures = []
    for name, fg, bg, req in checks:
        ratio = contrast_ratio(fg, bg)
        passed = ratio >= req
        if not passed:
            failures.append((name, fg, bg, ratio, req))
        rows.append((name, fg, bg, ratio, req, passed))
    return rows, failures


def audit():
    color_violations = []
    material_color_violations = []
    fake_data_violations = []
    dart_files = []

    for root, _, files in os.walk(APP_LIB):
        if os.path.abspath(root).startswith(os.path.abspath(DEV_DIR)):
            continue
        for f in files:
            if f.endswith(".dart"):
                path = os.path.join(root, f)
                dart_files.append(path)

    for path in sorted(dart_files):
        rel = os.path.relpath(path, ROOT)
        is_tokens = os.path.abspath(path) == os.path.abspath(TOKENS_DART)
        with open(path, "r", encoding="utf-8") as fh:
            for lineno, line in enumerate(fh, 1):
                if not is_tokens:
                    if HEX_REGEX.search(line) or COLOR_CONSTRUCTOR_REGEX.search(line):
                        color_violations.append((rel, lineno, line.strip()))
                    if MATERIAL_COLORS_REGEX.search(line):
                        material_color_violations.append((rel, lineno, line.strip()))
                stripped = line.strip()
                if not stripped.startswith("//") and FAKE_DATA_REGEX.search(line):
                    fake_data_violations.append((rel, lineno, stripped))

    contrast_rows, contrast_failures = compute_contrast_rows()
    total_violations = (
        len(color_violations)
        + len(material_color_violations)
        + len(fake_data_violations)
        + len(contrast_failures)
    )
    score = "100.0%" if total_violations == 0 else "0.0%"

    report = [
        "# Design Token & Data Integrity Audit Report",
        "",
        "Generated automatically by `design/audit.py` from `design/tokens.json` and `app/lib/`.",
        "",
        "## Summary",
        f"- **Hard-coded color violations outside tokens.dart:** {len(color_violations)}",
        f"- **Material `Colors.*` usages outside tokens.dart:** {len(material_color_violations)}",
        f"- **Fake or placeholder data hits outside `app/lib/dev/`:** {len(fake_data_violations)}",
        f"- **WCAG contrast failures (`tokens.json`):** {len(contrast_failures)}",
        f"- **Dart files scanned:** {len(dart_files)}",
        f"- **Overall Component Completeness Score:** {score}",
        "",
        "## WCAG 2.1 Contrast Verification (`design/tokens.json`)",
        "",
        "| Pair | Foreground | Background | Ratio | Required | Status |",
        "|---|---|---|---|---|---|",
    ]
    for name, fg, bg, ratio, req, passed in contrast_rows:
        status = "PASS" if passed else "FAIL"
        report.append(
            f"| {name} | `{fg}` | `{bg}` | {ratio:.2f}:1 | >= {req:.1f}:1 | {status} |"
        )
    report.append("")

    if color_violations:
        report.append("## Hard-coded Color Violations")
        for rel, ln, txt in color_violations:
            report.append(f"- `{rel}:{ln}` -> `{txt}`")
        report.append("")

    if material_color_violations:
        report.append("## Material `Colors.*` Violations")
        for rel, ln, txt in material_color_violations:
            report.append(f"- `{rel}:{ln}` -> `{txt}`")
        report.append("")

    if fake_data_violations:
        report.append("## Fake / Placeholder Data Violations")
        for rel, ln, txt in fake_data_violations:
            report.append(f"- `{rel}:{ln}` -> `{txt}`")
        report.append("")

    with open(AUDIT_MD, "w", encoding="utf-8") as out:
        out.write("\n".join(report))

    print(
        f"Audit complete: {len(color_violations)} color violations, "
        f"{len(material_color_violations)} Colors.* violations, "
        f"{len(fake_data_violations)} fake-data hits, "
        f"{len(contrast_failures)} contrast failures."
    )
    if total_violations > 0:
        for group_name, items in (
            ("color", color_violations),
            ("Colors.*", material_color_violations),
            ("fake-data", fake_data_violations),
        ):
            for rel, ln, txt in items:
                print(f"[{group_name}] {rel}:{ln}: {txt}", file=sys.stderr)
        for name, fg, bg, ratio, req in contrast_failures:
            print(
                f"[contrast] {name} ({fg} on {bg}) = {ratio:.2f}:1 < {req:.1f}:1",
                file=sys.stderr,
            )
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(audit())
