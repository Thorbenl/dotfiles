# Engineering standards

How code gets written. Identical for LEGO work and personal projects, and read by
every harness: Claude Code, opencode and Codex. If a project needs to deviate, the
project's own `AGENTS.md` says so explicitly and says why — silence means these apply.

Language-agnostic on purpose. This spans TypeScript, Swift, Python, ABAP, shell and
Ansible, so each rule states the intent first and the per-language form second.

## Tests

- **TDD by default.** Write or update the test before the implementation. When that
  is genuinely not feasible, say so in the change rather than skipping it silently.
- **BDD only where behaviour is the interesting part** — user-facing flows, event
  and API contracts, anything a non-engineer would describe in one sentence. Not
  for a pure function; a unit test is the right tool there.
- **Define explicit success criteria before starting.** "Page loads" is not one.
- **Every test asserts something meaningful.** Value, not coverage percentage.
- **All tests pass before committing.** Not "will fix in the next commit".
- **A test you could not run is not a passing test.** Integration tests needing
  Docker, a real SAP system or credentials you do not have locally: say they were
  not run, and say which ones. Never imply green.

## Evidence, never assumption

- **Verify before claiming.** Read the file, run the command, look at the response.
  "Should work" is not a result.
- **Absence of evidence is not evidence of absence.** A search that finds nothing
  may be a bad search — a tool that skips hidden files, a fallback index that never
  held the data. State whether you established a fact or failed to find one.
- **Never assume one repo follows another's conventions.** Read its own rules first.
- **Say what was not tested**, explicitly, in the same breath as what was.
- When a tool reports low confidence in its own answer, pass that on. Do not
  launder a weak signal into a firm claim.

## Immutability by default

Intent: a binding that never changes should not be allowed to change.

- Never `var`.
- TypeScript / JavaScript: `const`; `let` only where genuinely reassigned.
- Swift: `let` over `var`.
- Python: do not rebind a name to mean something different.
- ABAP: prefer inline `DATA(x) = ...` at first use over a separate `DATA:` block.
- Mark it `readonly` / `final` / `immutable` wherever the language offers it.

## Types

- Strict mode on.
- Never `any` unless genuinely unavoidable, and write the reason next to it.
- Business language in code — the domain's words, not technical shorthand.

## Errors

- Never swallow an error silently.
- Log with context before re-throwing.
- An exit code of 0 must mean it worked. A step that skipped its own work has not
  succeeded, and must not report success.

## Shape

Triggers to stop and consider splitting, not hard gates:

- A file past ~300 lines or a function past ~50 is a smell worth a moment's thought,
  not an automatic failure. Judgement over arithmetic.
- Follow existing patterns in the codebase before inventing new ones.
- Three similar lines beat a premature abstraction.
- Avoid over-engineering. Solve the problem in front of you.

## Context upkeep is part of "done"

In the same commit as the change, never a follow-up:

- Touched code that an existing doc describes → fix that doc.
- Made a significant decision, changed behaviour, or hit a gotcha that cost real
  time → dated entry in the repo's `recent-context.md`.
- Established or changed a convention → update the relevant `.agents/rules/*.md`.

## Secrets

- Never commit a credential, and never print one to a transcript or a log.
- Before echoing anything that might contain one, redact by construction and verify
  the redaction held — check the output, not the intent.
- Credentials belong in a gitignored file or an env reference, never inline in
  config that is tracked.

## Session hygiene

- Plan mode for anything larger than a simple fix.
- `/clear` between unrelated tasks.
- Quality over speed. Ask when unsure rather than guessing.
- Never deploy without explicit approval. "Yes, deploy" or nothing.
