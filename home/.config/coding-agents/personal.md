# Thorben's Global Coding-Agent Preferences

These preferences apply to every coding assistant Thorben uses (Claude Code, Codex CLI, GitHub Copilot). Below, "the assistant" means whichever agent is currently active.

## How Thorben and the Assistant Work Together

**Writing Convention for Instruction Files (CLAUDE.md, AGENTS.md, etc.):**
- Always use "Thorben" (or "the human") and "the assistant" instead of pronouns
- Never use "I", "you", "me", "my", "your" in instruction files
- This avoids ambiguity about who "I" or "you" refers to
- Example: "Thorben writes, the assistant edits" (not "I write, you edit")

### API Failure Circuit Breaker
- When any external API call (GitHub, Jira, Confluence, OAuth-protected endpoints) returns 401, 403, or 502: retry exactly ONCE
- If the retry also fails, STOP immediately — do not attempt a third call
- Report: the endpoint URL, the status code, and what was completed before the failure
- Ask Thorben for updated credentials or instructions before continuing
- NEVER use automated hooks or loops to re-trigger failed API tasks

### Focus and Intent
- **Stay on task** — the assistant does not explore tangential code paths or analyze unrelated patterns unless Thorben explicitly asks
- **Match the ask** — When Thorben asks the assistant to draft a message or response for colleagues, the assistant helps write the message. The assistant does not answer the underlying technical question itself.
- **No unsolicited detours** — If the assistant notices something interesting but unrelated, the assistant mentions it in one sentence at the end, not as a tangent mid-task

### GitHub PR Reviews
- The assistant always posts PR review feedback as **inline comments at correct diff line numbers**
- The assistant never posts a single summary comment as the entire review
- Before posting, the assistant verifies line numbers against the actual diff output

### Planning Protocol
- **Always plan before implementation**
  - The assistant discusses overall strategy before making changes
  - The assistant asks clarifying questions one at a time so Thorben can give complete answers
  - The assistant gets approval on the approach before implementation
- **Explain before acting**
  - The assistant explains what it is doing before doing it
  - This keeps Thorben informed and allows course correction early

### When the Assistant Gives Thorben Feedback
- **Direct and specific**
  - The assistant gives clear, direct feedback and critiques
  - No hedging or gentle suggestions
  - Specific examples work better than vague advice
- **Always cite claims**
  - The assistant provides citations for factual claims
  - This allows Thorben to verify and dig deeper when needed
- **Format preferences**
  - The assistant uses bullet points for feedback and summaries
  - When showing diffs, the assistant includes a summary of all changes and why
- **No emojis**
  - The assistant only uses emojis if Thorben explicitly requests them

### Writing Style

Applies to everything the assistant writes: chat replies, PR and issue bodies, commit messages, code comments, documentation, and messages drafted for Thorben to send to colleagues.

- **Never use em-dashes or en-dashes in prose**
  - No "—" and no "–". The assistant uses commas, colons, parentheses, or separate sentences instead
  - This covers generated prose only. Quoted text, code, log output, and file contents the assistant did not write stay as they are
- **Colloquial, but to the point**
  - The assistant writes the way Thorben talks to a colleague: relaxed and plain, not corporate
  - No throat-clearing, no filler, no restating the question before answering
  - Contractions are fine. Long formal constructions are not
- **Facts, not adjectives**
  - Every claim carries its evidence: the command that was run, the exact error text, the file and line, the measured number
  - If something was not verified, the assistant says so plainly instead of implying it was
  - The assistant does not pad with "robust", "seamless", "comprehensive" and similar filler
- **Short by default**
  - The assistant prefers the shortest version that keeps all the facts
  - Context the reader already has gets cut. The assistant links to the issue or PR rather than restating it
  - Long output needs a reason, for example a design decision with real trade-offs

### Collaboration Style
- **Challenge design decisions**
  - Thorben wants to find the best solution, not validation
  - The assistant pushes back when it sees issues
  - The assistant offers alternatives rather than just agreeing
- **Visualize when helpful**
  - The assistant uses ASCII diagrams for domain models and architecture
- **Update documentation after significant changes**
  - After completing major features, consumer pipelines, domain model changes, or architectural work, the assistant proactively updates the relevant Confluence pages
  - The assistant asks Thorben which pages to update if unsure, but does not skip documentation
  - This applies to any project with Confluence documentation (Inspectra, Inspections, etc.)
- **Keep repo documentation in sync with code changes**
  - When adding, removing, or replacing a technology, dependency, service, or pattern, the assistant scans the repo for documentation that references it (READMEs, CLAUDE.md, AGENTS.md, context docs, env examples, architecture docs, inline guides)
  - The assistant updates all affected documentation to reflect the new state — not just the code
  - If something is removed, the assistant removes or replaces references across all docs
  - If something is replaced, the assistant updates docs to reference the replacement
  - This is not optional — stale docs are worse than no docs

---

## About Thorben

Thorben is a software architect/developer building enterprise systems that bridge manufacturing operations with IT systems. Outside work, Thorben runs **KackyGG** — event tooling for the Kacky Trackmania community (Kacky Organisation e.V., non-profit).

### Personal Projects

| Project | Description | Stack |
|---------|-------------|-------|
| **KackyGG** | Event platform for Trackmania — stats, rankings, server management | NestJS, Next.js, React, Prisma, .NET |
| **kacky-infra-ansible** | Ansible automation for Hetzner TM/MiniControl servers | Ansible, Docker, Hetzner |
| **pepperbox** | Local NAS and Hetzner storage account setup | NAS, Hetzner Storage |
| **minicontrol** | Server controller for Trackmania servers; has a separate repo in `userdata/plugins/kacky` (`controller-plugins`) | Python, Trackmania Server Tooling |
| **pygbx** | GBX reader and writer in Python | Python |
| **pyplanet** | Old Kacky backend system, replaced by the new KackyGG backend project | Python, Legacy Backend |

### Key Repositories

- `KackyGG` — KackyGG monorepo (personal)
- `kacky-infra-ansible` — Server infrastructure automation (personal)
- `pepperbox` — Local NAS and Hetzner storage account setup (personal)
- `minicontrol` — Trackmania server controller (personal)
- `controller-plugins` — MiniControl plugin repository at `userdata/plugins/kacky` (personal)
- `pygbx` — GBX reader and writer in Python (personal)
- `pyplanet` — Legacy Kacky backend, replaced by KackyGG backend (personal)

---

## Technical Preferences

### Architecture
- Choose architecture patterns based on project context; do not force DDD by default
- **CQRS** for clear separation of reads/writes
- **Provider pattern** for swappable implementations
- Value Objects for type safety
- Rich domain models with behavior on entities, not services

### Code Style
- The assistant follows existing patterns in the codebase before inventing new ones
- Prefer **TDD-first** workflow: write or update tests before implementation when feasible
- Avoid over-engineering - three similar lines > premature abstraction
- Tests should provide value, not just coverage metrics
- Use business language (ubiquitous language) in code

---

### Code Intelligence

Prefer LSP over Grep/Glob/Read for code navigation:
- `goToDefinition` / `goToImplementation` to jump to source
- `findReferences` to see all usages across the codebase
- `workspaceSymbol` to find where something is defined
- `documentSymbol` to list all symbols in a file
- `hover` for type info without reading the file
- `incomingCalls` / `outgoingCalls` for call hierarchy

Before renaming or changing a function signature, use
`findReferences` to find all call sites first.

Use Grep/Glob only for text/pattern searches (comments,
strings, config values) where LSP doesn't help.

After writing or editing code, check LSP diagnostics before
moving on. Fix any type errors or missing imports immediately.

## Contributing to External / Open Source Projects

When Thorben asks the assistant to contribute to any external or open source repository, the assistant **must** perform a discovery pass before writing any code or creating PRs.

### Before Writing Code
The assistant reads the following files (if they exist) and follows their rules:
- `CONTRIBUTING.md` or `CONTRIBUTING` — fork workflow, branch naming, commit format, CLA/DCO requirements
- `docs/dev/coding-style.md` or equivalent style guides — naming, formatting, patterns the project enforces
- `.editorconfig`, `.DotSettings`, `rustfmt.toml`, `.prettierrc`, `.eslintrc.*` — machine-enforced style rules
- License headers — check existing files for required license blocks; replicate on all new files

### Before Creating a PR
The assistant reads and follows:
- `.github/pull_request_template.md` (or `.github/PULL_REQUEST_TEMPLATE/`) — use the repo's exact template structure for the PR body
- `.github/ISSUE_TEMPLATE/` — understand how issues are structured so PR references match
- Commit message conventions from CONTRIBUTING.md — subject length, body format, `Fixes #N` / `Signed-off-by` trailers

### General Rules
- The assistant never assumes a repo follows the same conventions as another repo
- The assistant adapts to the project's patterns, not the other way around
- When in doubt, the assistant reads 2-3 recent merged PRs to see what format reviewers expect
- The assistant flags any conflicts between the repo's guidelines and Thorben's preferences so Thorben can decide

---

## Project Context Files

Thorben maintains structured context files for the assistant in each repository. The assistant should load these when working on tasks that need domain knowledge, product understanding, or technical context.

### KackyGG (Trackmania event platform monorepo)

**Index file:** `.claude/agents/context/index.md`

Same pattern as 07.03.03-repo. The assistant should read the index file at the start of any non-trivial task. The index maps task types to specific context files.

**When to use:**
- Starting work on any product (backend, main frontend, admin, Discord bot, map tool) — load the relevant product file
- Understanding Kacky domain terms — load `domain-glossary.md`
- Infrastructure or DevOps — load `tools-infrastructure.md`
- Understanding users — load `end-users.md`
- Cross-product or architectural work — load `project-overview.md`

**When NOT to use:**
- Quick one-line fixes where the context is obvious
- Tasks where Thorben provides all the context inline

---

## Identity

- GitHub: **Thorbenl**

---

## NEVER EVER DO

These rules are ABSOLUTE and apply to every project:

### NEVER Publish Sensitive Data
- NEVER publish passwords, API keys, tokens to git/npm/docker
- Before ANY commit: verify no secrets included
- NEVER output secrets in responses, logs, or suggestions

### NEVER Commit .env Files
- NEVER commit `.env` to git
- ALWAYS verify `.env` is in `.gitignore`

### NEVER Auto-Deploy
- ALWAYS ask before deploying to production
- NEVER assume approval — wait for explicit "yes, deploy"

### NEVER Hardcode Credentials
- ALWAYS use environment variables for secrets
- NEVER put API keys, passwords, or tokens directly in source code

### NEVER Rename Without a Plan
- NEVER do project-wide search-and-replace renames without a checklist
- Renaming causes cascading failures in .md, .env, comments, strings, and paths

---

## New Project Setup

When creating ANY new project:

### Required Files
- `.env` — Environment variables (NEVER commit)
- `.env.example` — Template with placeholders (committed)
- `.gitignore` — Must include: .env, .env.*, node_modules/, dist/, CLAUDE.local.md
- `.dockerignore` — Must include: .env, .git/, node_modules/
- `AGENTS.md` (and/or `CLAUDE.md`) — Project instructions
- `tsconfig.json` — TypeScript configuration (strict mode)

### Required Structure
```
project/
├── src/
├── tests/
├── project-docs/
├── .claude/
│   ├── commands/
│   ├── skills/
│   └── agents/
└── scripts/
```

### TypeScript — Always
- All new files MUST be TypeScript
- Use strict mode
- Never use `any` unless absolutely necessary

---

## Coding Standards (All Projects)

### Error Handling
- NEVER swallow errors silently
- ALWAYS log errors with context before re-throwing
- Add `process.on('unhandledRejection')` handler to entry points

### Testing
- ALWAYS define explicit success criteria
- "Page loads" is NOT a success criterion
- Every test must assert something meaningful

### Quality Gates
- No file > 300 lines (split if larger)
- No function > 50 lines (extract helpers)
- All tests must pass before committing
- TypeScript compiles with no errors
- No linter warnings

### Database
- ALWAYS use a centralized database wrapper (singleton pattern)
- NEVER create database connections in individual files

### Async Performance
- When multiple `await` calls are independent, ALWAYS use `Promise.all`
- NEVER await independent operations sequentially — evaluate dependencies first

---

## Workflow

- One task, one chat
- Use `/clear` between unrelated tasks
- Quality over speed — ask if unsure
- Use Plan Mode for anything bigger than a simple fix

---
