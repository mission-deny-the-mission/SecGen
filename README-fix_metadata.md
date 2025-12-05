Fix secgen metadata common issues
=================================

This small helper script attempts to correct common XML issues in `secgen_metadata.xml` files under the `modules/` directory.

It will:
- Normalize license strings (e.g. `Apache-2.0` -> `Apache v2`)
- Wrap direct `<value>` elements inside `<generator>`s with `<input>`
- Escape `&` and `<=` occurrences inside text nodes (not inside attributes or tag names)

Usage
-----
```
python3 scripts/fix_metadata.py --apply --validate
```

Note: The script makes a `.bak` copy of every modified file and will not (currently) try to automatically fix complex mismatched XML tags. It reports remaining validation problems for manual review.

Limitations
-----------
- The tool uses regex-based heuristics; it is conservative and may not fix every edge case.
- Do not rely on it to repair intentionally complex or malformed files.

Suggestions
-----------
- Add this script to CI to surface common issues during pull requests.
- Add additional replacement heuristics for other recurring problems as they are found.

