#!/usr/bin/env python3
"""Conservative HCL attribute aligner approximating `terraform fmt`.

Aligns the `=` signs of consecutive attribute lines (same indentation,
no blank lines/comments/braces in between) to the longest name + 1 space.
This covers the bulk of what `terraform fmt` enforces; CI runs the real
`terraform fmt -check -diff` as the authoritative gate.
"""
import glob
import re
import sys

ATTR = re.compile(r'^(\s+)([A-Za-z_][A-Za-z0-9_.\-]*)(\s+)=(\s)(\S.*)$')


def align_file(path: str) -> bool:
    with open(path) as fh:
        lines = fh.read().split("\n")

    changed = False
    i = 0
    while i < len(lines):
        m = ATTR.match(lines[i])
        if not m:
            i += 1
            continue
        indent = m.group(1)
        # Collect the consecutive attribute run at this indent.
        j = i
        matches = []
        while j < len(lines):
            mm = ATTR.match(lines[j])
            if not mm or mm.group(1) != indent:
                break
            matches.append((j, mm))
            j += 1
        if len(matches) > 1:
            width = max(len(mm.group(2)) for _, mm in matches)
            for idx, mm in matches:
                aligned = f"{mm.group(1)}{mm.group(2).ljust(width)} = {mm.group(5)}"
                if aligned != lines[idx]:
                    lines[idx] = aligned
                    changed = True
        i = j

    if changed:
        with open(path, "w") as fh:
            fh.write("\n".join(lines))
    return changed


def main() -> int:
    files = sorted(glob.glob("terraform/**/*.tf", recursive=True))
    changed = [f for f in files if align_file(f)]
    print(f"{len(files)} files scanned, {len(changed)} realigned:")
    for f in changed:
        print(f"  {f}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
