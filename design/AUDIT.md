# Design Token & Data Integrity Audit Report

Generated automatically by `design/audit.py` from `design/tokens.json` and `app/lib/`.

## Summary
- **Hard-coded color violations outside tokens.dart:** 0
- **Material `Colors.*` usages outside tokens.dart:** 0
- **Fake or placeholder data hits outside `app/lib/dev/`:** 0
- **WCAG contrast failures (`tokens.json`):** 0
- **Dart files scanned:** 30
- **Overall Component Completeness Score:** 100.0%

## WCAG 2.1 Contrast Verification (`design/tokens.json`)

| Pair | Foreground | Background | Ratio | Required | Status |
|---|---|---|---|---|---|
| Light primary text on ground | `#1E3A4F` | `#E8ECEF` | 9.97:1 | >= 4.5:1 | PASS |
| Light primary text on surface | `#1E3A4F` | `#F6F8F9` | 11.12:1 | >= 4.5:1 | PASS |
| Light direct link on surface | `#2358D6` | `#F6F8F9` | 5.73:1 | >= 4.5:1 | PASS |
| Light on-primary on direct button | `#FFFFFF` | `#2358D6` | 6.11:1 | >= 4.5:1 | PASS |
| Light relay text on surface | `#8A5A00` | `#F6F8F9` | 5.56:1 | >= 4.5:1 | PASS |
| Light relay line graphic on surface | `#B97A0B` | `#F6F8F9` | 3.37:1 | >= 3.0:1 | PASS |
| Light ok status on surface | `#2F6B47` | `#F6F8F9` | 5.95:1 | >= 4.5:1 | PASS |
| Light danger on surface | `#A93A48` | `#F6F8F9` | 5.82:1 | >= 4.5:1 | PASS |
| Light on-primary on danger button | `#FFFFFF` | `#A93A48` | 6.20:1 | >= 4.5:1 | PASS |
| Dark primary text on ground | `#E6EDF2` | `#12202B` | 14.02:1 | >= 4.5:1 | PASS |
| Dark primary text on surface | `#E6EDF2` | `#1B2B38` | 12.25:1 | >= 4.5:1 | PASS |
| Dark direct link on surface | `#7FA3FF` | `#1B2B38` | 5.92:1 | >= 4.5:1 | PASS |
| Dark on-primary on direct button | `#0E1A24` | `#7FA3FF` | 7.20:1 | >= 4.5:1 | PASS |
| Dark relay text on surface | `#E0A93B` | `#1B2B38` | 6.84:1 | >= 4.5:1 | PASS |
| Dark relay line graphic on surface | `#E0A93B` | `#1B2B38` | 6.84:1 | >= 3.0:1 | PASS |
| Dark ok status on surface | `#6FC08D` | `#1B2B38` | 6.62:1 | >= 4.5:1 | PASS |
| Dark danger on surface | `#E88A95` | `#1B2B38` | 5.87:1 | >= 4.5:1 | PASS |
| Dark on-primary on danger button | `#0E1A24` | `#E88A95` | 7.13:1 | >= 4.5:1 | PASS |
