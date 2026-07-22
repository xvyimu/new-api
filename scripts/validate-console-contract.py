#!/usr/bin/env python3
"""
Validate docs/openapi/console-subset.yaml is machine-readable and contains
the W2 P0 contract surface (probes · status · session · channels RO).

No external deps (stdlib only). Exit:
  0 — valid structure + required paths present
  1 — structural or coverage failure
  2 — missing file / unreadable
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
YAML_PATH = ROOT / "docs" / "openapi" / "console-subset.yaml"

# Minimal OpenAPI surface required for W2 cutover / web-console
REQUIRED_OPS = {
    ("get", "/healthz"),
    ("get", "/livez"),
    ("get", "/readyz"),
    ("get", "/api/status"),
    ("post", "/api/user/login"),
    ("get", "/api/user/logout"),
    ("get", "/api/user/self"),
    ("get", "/api/channel/"),
}

REQUIRED_SCHEMAS = {
    "ProbeOk",
    "SuccessEnvelope",
    "StatusResponse",
    "LoginResponse",
    "ChannelListResponse",
    "ChannelListItem",
}


def extract_paths(text: str) -> set[tuple[str, str]]:
    """Best-effort parse of openapi paths block without PyYAML."""
    ops: set[tuple[str, str]] = set()
    # Match "  /path:" then indented method lines "    get:" etc.
    path_re = re.compile(r"^  (/[^:\n]+):\s*$", re.M)
    method_re = re.compile(r"^    (get|post|put|delete|patch|head|options):\s*$", re.M | re.I)

    paths = list(path_re.finditer(text))
    for i, m in enumerate(paths):
        path = m.group(1).rstrip()
        start = m.end()
        end = paths[i + 1].start() if i + 1 < len(paths) else len(text)
        block = text[start:end]
        # Stop at components: at document level if we overshot
        if "\ncomponents:" in block:
            block = block.split("\ncomponents:")[0]
        for mm in method_re.finditer(block):
            # Only count methods that are direct children of this path
            # (method_re already requires 4-space indent)
            ops.add((mm.group(1).lower(), path))
    return ops


def extract_schemas(text: str) -> set[str]:
    schemas: set[str] = set()
    # Under components.schemas — lines like "    Name:"
    in_schemas = False
    for line in text.splitlines():
        if re.match(r"^  schemas:\s*$", line):
            in_schemas = True
            continue
        if in_schemas:
            if re.match(r"^[a-zA-Z]", line) or re.match(r"^  [a-zA-Z]", line):
                # left schemas section (securitySchemes sibling already passed or next top)
                if not line.startswith("    "):
                    break
            m = re.match(r"^    ([A-Za-z][A-Za-z0-9_]*):\s*$", line)
            if m:
                schemas.add(m.group(1))
    return schemas


def main() -> int:
    if not YAML_PATH.is_file():
        print(f"ERR missing {YAML_PATH.relative_to(ROOT)}", file=sys.stderr)
        return 2

    text = YAML_PATH.read_text(encoding="utf-8")
    if not text.lstrip().startswith("openapi:"):
        print("ERR file does not start with openapi:", file=sys.stderr)
        return 1

    if "openapi: 3." not in text.splitlines()[0] and not re.search(r"^openapi:\s*3\.", text, re.M):
        print("ERR openapi version must be 3.x", file=sys.stderr)
        return 1

    ops = extract_paths(text)
    schemas = extract_schemas(text)

    missing_ops = sorted(REQUIRED_OPS - ops)
    missing_schemas = sorted(REQUIRED_SCHEMAS - schemas)

    print(f"file: {YAML_PATH.relative_to(ROOT)}")
    print(f"ops_found={len(ops)} schemas_found={len(schemas)}")
    for method, path in sorted(ops):
        mark = "OK" if (method, path) in REQUIRED_OPS else "extra"
        print(f"  {mark} {method.upper()} {path}")

    ok = True
    if missing_ops:
        ok = False
        print("MISSING ops:")
        for method, path in missing_ops:
            print(f"  {method.upper()} {path}")
    if missing_schemas:
        ok = False
        print("MISSING schemas:")
        for name in missing_schemas:
            print(f"  {name}")

    # Safety: list response must document that keys are omitted
    if "Omit" not in text and "key MUST NOT" not in text and "keys not present" not in text.lower():
        print("WARN channel list should note key omission (doc hygiene)")

    if "Relay" in text and "/v1/chat" in text:
        print("ERR console-subset must not define relay /v1/chat paths", file=sys.stderr)
        return 1

    if not ok:
        print("FAIL validate-console-contract")
        return 1

    print("PASS validate-console-contract")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
