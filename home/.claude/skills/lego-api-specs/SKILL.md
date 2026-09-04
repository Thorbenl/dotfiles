---
name: lego-api-specs
description: Find, download and read LEGO AMMA API specs (OpenAPI) from a local mirror, and switch between the integration and production environments. Use when asked which API exposes a given field or concept ("find me what API exposes machine type", "where can I get workcenter data"), when asked to implement or call a named LEGO API (qm-mics-api, material-odata-service, ...), when a spec needs downloading into the local api-specs mirror, or whenever the `lego` CLI, AMMA, or baseplate API discovery comes up.
---

# LEGO AMMA API specs

Wraps the `lego` CLI (github.com/LEGO/cli) with a local mirror of every published
OpenAPI spec so you can answer "which API exposes X?" without guessing, and read
the real contract before implementing against it.

The driver is `legospec`, in this skill's directory. Call it by absolute path:

```bash
~/.claude/skills/lego-api-specs/legospec <command>
```

## Commands

| Command | What it does |
|---|---|
| `legospec search <term> [--all]` | which APIs expose `<term>` (the main one) |
| `legospec show <api>` | endpoints, schemas, server URL, contact, permissions |
| `legospec list [pattern]` | API names in the current environment |
| `legospec get <api>` | download one spec, print its path |
| `legospec path <api>` | where the spec lives on disk |
| `legospec env [production\|integration]` | show / switch the default environment |
| `legospec sync [--all] [--force]` | refresh the mirror |
| `legospec doctor` | config + prerequisites + mirror status |

Any command takes `-e production` / `-e integration` (or `--prod` / `--dev`) to
override the environment for that one call, without changing the default.

## Answering "what API exposes X?"

```bash
legospec search "machine type"          # current environment
legospec search "machine type" --all    # production + integration
```

Search is offline over the mirror and takes ~1s. It reports *where* each hit is,
ranked so that real contract surface beats prose:

```
mould-card-api-odata  [production]
  - path          /MachineTypeSet
  - schema-field  YPLM_MOULDCARD_SRV.MachineType.Machinetype
material-odata-service  [production]
  - schema-field  YPLM_MAT_SRV.MaterialData.MachineType
  - parameter     GET /MaterialDataSet (param $select)
```

Hit kinds, strongest first: `path`, `schema-field`, `schema-name`, `parameter`,
`body-field`, `channel`, `operation`, `doc`, `metadata`.

The query is normalised, so `machine type`, `machineType`, `machine_type` and
`Machine-Type` all become the same case-insensitive pattern. Use `--regex` to
pass a raw regex instead, `--json` for structured output, `--limit N` for more
APIs and `--hits N` for more hits per API.

**Report the API name and the specific field/endpoint you found — never claim an
API exposes something without a hit to point at.**

## Implementing against an API

```bash
legospec show qm-mics-api
```

gives the endpoint list with permission scopes, the `servers` base URL, the
owning team's contact, and the schema names. Read the full spec at
`legospec path <api>` when you need request/response bodies.

Prefer `show` over dumping the whole spec into context — some specs are 1.6 MB.
Use `jq` on the file for targeted digging:

```bash
jq '.paths["/api/v1/masterInspectionCharacteristics"].get' "$(legospec path qm-mics-api)"
jq -r '.components.schemas | keys[]' "$(legospec path material-odata-service)"
```

## Environments

`production` is the default. Integration is a *different, larger* set (~1550 vs
~700 APIs) with its own naming — an API often exists in one and not the other,
usually with a `-dev`, `-qa` or `-pc` suffix in integration. If a name is not
found, `legospec` says so and points at the other environment and near matches;
pass that suggestion on rather than guessing.

## Mirror layout

`$LEGO_SPECS_DIR` (default `~/work/api-specs`):

```
production/<api>.json      ~700 specs
integration/<api>.json     ~1550 specs
_legacy/                   hand-downloaded specs from before the mirror
.state/                    name lists, filename index, failure logs
```

Names that collide only by case (AMMA publishes both `Status` and `status`) get a
short hash suffix, because macOS filesystems are case-insensitive. Use
`legospec path` rather than constructing filenames yourself.

## Keeping it fresh

The mirror is a snapshot. `legospec sync` fetches only what is missing;
`--force` re-downloads everything (~4.5 min for both environments). The API name
list refreshes itself daily. Re-sync if a search comes up empty for something
that should exist, or if an API was published recently.

## Requirements and gotchas

- `lego` CLI + `az login` (the CLI uses Azure CLI credentials). `legospec` finds
  `lego` via `LEGO_BIN`, then `PATH`, then `~/work/cli/lego`. On another machine
  set `LEGO_BIN` and `LEGO_SPECS_DIR`.
- **AMMA rate-limits spec downloads**: ~5000 req/hour, and bursts above ~8
  concurrent get `429`. Sync uses 4 parallel jobs with backoff — don't raise
  `LEGO_SYNC_JOBS` much above that, and don't loop `lego apis spec` yourself.
- ~54 APIs are in the index but return `409` and have no fetchable spec (mostly
  dev/test entries). Logged in `.state/<env>.failures.tsv`; not a bug.
- `lego apis list-apis` is hardcoded to production. `legospec` calls the index
  server directly so both environments list correctly.
- Run `legospec doctor` first if anything behaves unexpectedly.
