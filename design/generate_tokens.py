#!/usr/bin/env python3
"""
Generates Flutter Dart theme code from design/tokens.json.
Enforces zero hard-coded tokens by emitting compile-time constants.
"""

import json
import os
import sys

def hex_to_flutter(hex_code):
    clean = hex_code.lstrip('#')
    return f"Color(0xFF{clean.upper()})"

def main():
    tokens_path = os.path.join(os.path.dirname(__file__), "tokens.json")
    out_dir = os.path.join(os.path.dirname(__file__), "..", "app", "lib", "theme")
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, "tokens.dart")

    with open(tokens_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    code = []
    code.append("// AUTO-GENERATED FROM design/tokens.json - DO NOT MODIFY DIRECTLY")
    code.append("import 'package:flutter/material.dart';\n")
    code.append("class TandemTokens {\n")

    # Light Colors
    code.append("  // Light Theme Colors")
    for name, obj in data["color"]["light"].items():
        var_name = name.replace("-", "_")
        code.append(f"  static const Color {var_name} = {hex_to_flutter(obj['value'])};")
    code.append("")

    # Dark Colors
    code.append("  // Dark Theme Colors")
    for name, obj in data["color"]["dark"].items():
        var_name = name.replace("-", "_") + "_dark"
        code.append(f"  static const Color {var_name} = {hex_to_flutter(obj['value'])};")
    code.append("")

    # Spacing
    code.append("  // Spacing (4pt base)")
    for name, obj in data["spacing"].items():
        var_name = name.replace("-", "_")
        code.append(f"  static const double {var_name} = {obj['value']}.0;")
    code.append("")

    # Radius
    code.append("  // Radius")
    for name, obj in data["radius"].items():
        var_name = name.replace("-", "_")
        code.append(f"  static const double {var_name} = {obj['value']}.0;")
    code.append("")

    # Targets
    code.append("  // Hit Targets")
    for name, obj in data["targets"].items():
        var_name = name.replace("-", "_")
        code.append(f"  static const double {var_name} = {obj['value']}.0;")
    code.append("")

    # Typography
    code.append("  // Typography Scales")
    for name, obj in data["typography"]["scale"].items():
        var_name = name.replace("-", "_")
        size = obj["fontSize"]
        weight = obj["fontWeight"]
        code.append(f"  static const TextStyle {var_name} = TextStyle(")
        code.append(f"    fontFamily: 'Atkinson Hyperlegible Next',")
        code.append(f"    fontSize: {size}.0,")
        code.append(f"    fontWeight: FontWeight.w{weight},")
        code.append(f"  );")

    code.append("}\n")

    with open(out_path, "w", encoding="utf-8") as f:
        f.write("\n".join(code))

    print(f"Generated {out_path} from tokens.json")

if __name__ == "__main__":
    main()
