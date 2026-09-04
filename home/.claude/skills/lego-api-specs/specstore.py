#!/usr/bin/env python3
"""Helpers for the lego-api-specs skill: filename mapping, search, and spec summaries.

Kept dependency-free (stdlib only) so it runs under any python3 >= 3.8.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
from collections import Counter
from pathlib import Path

HTTP_METHODS = {
    "get", "put", "post", "delete", "options", "head", "patch", "trace",
}

# ---------------------------------------------------------------------------
# filename mapping
# ---------------------------------------------------------------------------
# macOS filesystems are case-insensitive by default, and AMMA really does
# publish names that differ only by case (e.g. "Status" and "status" in
# production, "status"/"testapi" in integration). Those would silently
# overwrite each other, so any name in a case-collision group gets a short
# deterministic hash suffix.


def map_names(names: list[str]) -> list[tuple[str, str]]:
    lowered = Counter(n.lower() for n in names)
    out = []
    for name in names:
        if lowered[name.lower()] > 1:
            digest = hashlib.sha1(name.encode()).hexdigest()[:6]
            out.append((name, f"{name}__{digest}.json"))
        else:
            out.append((name, f"{name}.json"))
    return out


def cmd_map_names(args: argparse.Namespace) -> int:
    names = [ln.strip() for ln in sys.stdin if ln.strip()]
    for name, filename in map_names(names):
        print(f"{name}\t{filename}")
    return 0


# ---------------------------------------------------------------------------
# query -> regex
# ---------------------------------------------------------------------------

_WORD = re.compile(r"[A-Z]+(?![a-z])|[A-Z][a-z]*|[a-z]+|\d+")
SEP = r"[^A-Za-z0-9]{0,2}"


def tokenize(query: str) -> list[str]:
    tokens: list[str] = []
    for chunk in re.split(r"[^A-Za-z0-9]+", query):
        if not chunk:
            continue
        tokens.extend(w.lower() for w in _WORD.findall(chunk))
    return tokens


def build_regex(query: str, raw: bool) -> str:
    if raw:
        return query
    tokens = tokenize(query)
    if not tokens:
        raise SystemExit("empty query")
    return SEP.join(re.escape(t) for t in tokens)


# ---------------------------------------------------------------------------
# classification of a JSON pointer into something a human wants to read
# ---------------------------------------------------------------------------


def classify(parts: list[str], is_key: bool, ctx: dict | None = None) -> tuple[int, str, str]:
    """Return (priority, kind, location). Lower priority sorts first."""
    if not parts:
        return (5, "other", "/")
    ctx = ctx or {}

    head = parts[0]

    if head == "paths" and len(parts) >= 2:
        path = parts[1]
        rest = parts[2:]
        method = ""
        if rest and rest[0].lower() in HTTP_METHODS:
            method = rest[0].upper()
            rest = rest[1:]
        where = "/".join(rest)
        label = f"{method + ' ' if method else ''}{path}"
        if len(parts) == 2:
            return (0, "path", label)
        if "parameters" in rest:
            # the raw pointer ends in an array index, so prefer the sibling "name"
            pname = ctx.get("param") or parts[-1]
            # a hit in a parameter's prose (OData $select/$filter list every field)
            # is much weaker evidence than a hit in the parameter name itself
            prio = 2 if rest[-1] in ("description", "summary") else 1
            return (prio, "parameter", f"{label} (param {pname})")
        if "properties" in rest:
            return (1, "body-field", f"{label} (field {parts[-1]})")
        if rest and rest[-1] in ("summary", "description", "operationId"):
            return (3, "doc", f"{label} ({rest[-1]})")
        return (2, "operation", f"{label}{' -> ' + where if where else ''}")

    if head in ("components", "definitions"):
        if "properties" in parts:
            i = parts.index("properties")
            schema = parts[i - 1] if i >= 1 else "?"
            prop = parts[i + 1] if len(parts) > i + 1 else parts[-1]
            return (1, "schema-field", f"{schema}.{prop}")
        if len(parts) >= 3 and parts[1] in ("schemas", "parameters", "headers"):
            return (1, f"{parts[1][:-1]}-name", parts[2])
        return (2, "component", "/".join(parts[1:4]))

    if head in ("channels", "operations", "messages"):
        return (1, "channel", "/".join(parts[1:3]))

    if head in ("info", "tags", "externalDocs", "servers", "security"):
        return (4, "metadata", "/".join(parts[:3]))

    return (3, "other", "/".join(parts[:4]))


def walk(node, regex: re.Pattern, parts: list[str], hits: list, cap: int,
         ctx: dict | None = None) -> None:
    if len(hits) >= cap:
        return
    ctx = ctx or {}
    if isinstance(node, dict):
        # remember the name of the parameter object we are inside, so hits can be
        # reported as "(param $select)" rather than "(param 231)"
        if len(parts) >= 2 and parts[-2] == "parameters" and parts[-1].isdigit():
            name = node.get("name")
            if isinstance(name, str):
                ctx = dict(ctx, param=name)
        for key, value in node.items():
            if len(hits) >= cap:
                return
            if isinstance(key, str) and regex.search(key):
                prio, kind, loc = classify(parts + [key], True, ctx)
                hits.append((prio, kind, loc, key))
            walk(value, regex, parts + [str(key)], hits, cap, ctx)
    elif isinstance(node, list):
        for i, value in enumerate(node):
            walk(value, regex, parts + [str(i)], hits, cap, ctx)
    elif isinstance(node, str):
        if regex.search(node):
            prio, kind, loc = classify(parts, False, ctx)
            snippet = " ".join(node.split())
            if len(snippet) > 90:
                snippet = snippet[:87] + "..."
            # a match in free prose is worth less than a match in a name
            hits.append((min(prio + 1, 4), kind, loc, snippet))


def load_spec(path: Path):
    try:
        with path.open(encoding="utf-8") as fh:
            return json.load(fh)
    except Exception:
        return None


def candidate_files(root: Path, pattern: str) -> list[Path]:
    """Pre-filter with ripgrep when available; fall back to scanning everything."""
    try:
        proc = subprocess.run(
            ["rg", "-l", "-i", "-e", pattern, "--glob", "*.json", str(root)],
            capture_output=True, text=True, check=False,
        )
        if proc.returncode in (0, 1):
            return [Path(p) for p in proc.stdout.splitlines() if p]
    except FileNotFoundError:
        pass
    return sorted(root.glob("*.json"))


def read_index(state: Path, env: str) -> dict[str, str]:
    """filename -> api name"""
    idx = state / f"{env}.index.tsv"
    mapping: dict[str, str] = {}
    if idx.exists():
        for line in idx.read_text(encoding="utf-8").splitlines():
            if "\t" in line:
                name, filename = line.split("\t", 1)
                mapping[filename] = name
    return mapping


def cmd_search(args: argparse.Namespace) -> int:
    pattern = build_regex(args.query, args.regex)
    regex = re.compile(pattern, re.IGNORECASE)
    root = Path(args.specs_dir)
    state = root / ".state"

    results = []
    for env in args.envs:
        env_dir = root / env
        if not env_dir.is_dir():
            continue
        names = read_index(state, env)
        for path in candidate_files(env_dir, pattern):
            spec = load_spec(path)
            if spec is None:
                continue
            hits: list = []
            walk(spec, regex, [], hits, args.max_hits_scan)
            if not hits:
                continue
            seen = set()
            deduped = []
            for hit in sorted(hits, key=lambda h: h[0]):
                key = (hit[1], hit[2])
                if key in seen:
                    continue
                seen.add(key)
                deduped.append(hit)
            api = names.get(path.name, path.stem)
            title = ""
            if isinstance(spec, dict):
                info = spec.get("info")
                if isinstance(info, dict):
                    title = str(info.get("description") or info.get("title") or "")
            results.append({
                "api": api,
                "env": env,
                "file": str(path),
                "title": " ".join(title.split())[:100],
                "best": deduped[0][0],
                "hit_count": len(deduped),
                "hits": [
                    {"kind": k, "where": w, "match": m}
                    for _, k, w, m in deduped[: args.hits]
                ],
                "truncated": len(deduped) > args.hits,
            })

    results.sort(key=lambda r: (r["best"], -r["hit_count"], r["api"].lower()))
    total = len(results)
    shown = results[: args.limit]

    if args.json:
        json.dump({"query": args.query, "regex": pattern,
                   "total_apis": total, "results": shown}, sys.stdout, indent=2)
        print()
        return 0

    if not total:
        print(f'No API matches "{args.query}"  (regex: {pattern})')
        print("If the mirror is empty or stale, run:  legospec sync --all")
        return 1

    print(f'"{args.query}"  ->  {total} matching API(s)   [regex: {pattern}]')
    if total > len(shown):
        print(f"showing the {len(shown)} strongest matches (--limit to see more)")
    for r in shown:
        print()
        print(f"  {r['api']}  [{r['env']}]")
        if r["title"]:
            print(f"    {r['title']}")
        for h in r["hits"]:
            print(f"    - {h['kind']:<13} {h['where']}")
            if h["kind"] in ("doc", "metadata", "other"):
                print(f"        \"{h['match']}\"")
        if r["truncated"]:
            print(f"    ... +{r['hit_count'] - len(r['hits'])} more hits in this API")
    print()
    return 0


# ---------------------------------------------------------------------------
# show: what does this API actually offer
# ---------------------------------------------------------------------------


def cmd_show(args: argparse.Namespace) -> int:
    path = Path(args.file)
    spec = load_spec(path)
    if spec is None:
        print(f"could not parse {path}", file=sys.stderr)
        return 1

    info = spec.get("info", {}) if isinstance(spec, dict) else {}
    print(f"API:         {args.api}  [{args.env}]")
    if info.get("title"):
        print(f"title:       {info['title']}")
    if info.get("description"):
        print(f"description: {' '.join(str(info['description']).split())}")
    if info.get("version"):
        print(f"version:     {info['version']}")
    for k in ("x-audience", "x-application-id", "x-data-pii"):
        if k in info:
            print(f"{k + ':':<13}{info[k]}")
    contact = info.get("contact") or {}
    if contact:
        bits = [str(v) for v in (contact.get("name"), contact.get("url"), contact.get("email")) if v]
        print(f"contact:     {'  |  '.join(bits)}")
    servers = spec.get("servers") or []
    for s in servers:
        if isinstance(s, dict) and s.get("url"):
            print(f"server:      {s['url']}")
    print(f"spec file:   {path}")

    paths = spec.get("paths") or {}
    ops = []
    for p, item in paths.items():
        if not isinstance(item, dict):
            continue
        for method, op in item.items():
            if method.lower() not in HTTP_METHODS:
                continue
            summary = ""
            if isinstance(op, dict):
                summary = str(op.get("summary") or op.get("operationId") or "")
            ops.append((method.upper(), p, " ".join(summary.split())))
    print()
    print(f"endpoints ({len(ops)}):")
    for method, p, summary in sorted(ops, key=lambda o: (o[1], o[0])):
        line = f"  {method:<7} {p}"
        if summary:
            line += f"   - {summary[:80]}"
        print(line)

    schemas = ((spec.get("components") or {}).get("schemas")
               or spec.get("definitions") or {})
    if schemas:
        print()
        print(f"schemas ({len(schemas)}): {', '.join(sorted(schemas)[:40])}"
              + (" ..." if len(schemas) > 40 else ""))
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(prog="specstore.py")
    sub = ap.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("map-names", help="stdin: api names -> stdout: name<TAB>filename")
    p.set_defaults(func=cmd_map_names)

    p = sub.add_parser("search")
    p.add_argument("query")
    p.add_argument("--specs-dir", required=True)
    p.add_argument("--envs", nargs="+", default=["production"])
    p.add_argument("--limit", type=int, default=20)
    p.add_argument("--hits", type=int, default=6)
    p.add_argument("--max-hits-scan", type=int, default=400)
    p.add_argument("--regex", action="store_true", help="treat query as a raw regex")
    p.add_argument("--json", action="store_true")
    p.set_defaults(func=cmd_search)

    p = sub.add_parser("show")
    p.add_argument("--file", required=True)
    p.add_argument("--api", required=True)
    p.add_argument("--env", required=True)
    p.set_defaults(func=cmd_show)

    args = ap.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
