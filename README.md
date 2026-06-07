# Agent Environment Specification

`agent-env` is a stack-neutral Bash wizard for preparing repositories for coding agents. It records project intent and operational boundaries once, renders portable `AGENTS.md` instructions, and produces a concrete handoff for the agent that will build the application.

The tool prepares the environment. It does not choose an application stack, launch an agent, enforce a sandbox, or collect telemetry.

## Quick Start

Create a new project environment interactively:

```bash
./agent-env init ../weather-logistics-api
```

Include policy, evaluation, and Claude adapter questions:

```bash
./agent-env init ../weather-logistics-api --advanced
```

For automation, initialize from a contract:

```bash
./agent-env init ../weather-logistics-api --from examples/weather-logistics.conf
```

Then give the selected coding agent the prompt in `.agent-env/HANDOFF.md`.

## Commands

```text
./agent-env init [DIR] [--advanced] [--from FILE] [--dry-run] [--adopt]
./agent-env validate [DIR]
./agent-env render [DIR] [--dry-run] [--adopt]
./agent-env doctor [DIR]
```

- `init` creates the contract, initializes Git on `main` when needed, and renders the environment.
- `validate` checks the strict contract grammar and supported keys.
- `render` refreshes managed sections without replacing handwritten content.
- `doctor` reports contract, Git, generated-file, command, and stale-module status.
- `--adopt` appends a managed section to an existing unmarked generated target.
- `--dry-run` reports render changes without writing them.

## Contract

The canonical file is `.agent-env/environment.conf`. It intentionally uses a constrained `KEY=value` format so Bash can parse it safely without Python, Node, `jq`, or `yq`.

- Each value is literal, UTF-8, and single-line.
- Values may contain `=`.
- Keys are versioned and validated.
- Duplicate and unknown keys are rejected.
- The file is never sourced and its values are never evaluated as shell code.

See [`examples/weather-logistics.conf`](examples/weather-logistics.conf) for a complete example.

## Generated Files

The lean baseline contains:

```text
.agent-env/environment.conf
.agent-env/HANDOFF.md
AGENTS.md
docs/PROJECT_BRIEF.md
.gitignore
```

Advanced modules can add:

```text
contracts/AGENT_POLICY.md
evals/acceptance.md
CLAUDE.md
```

`CLAUDE.md` imports `AGENTS.md`, keeping shared behavior in one place. Generated documents contain managed markers. Regeneration only replaces the content between those markers.

## Development

Requirements are Bash 3.2+, standard Unix tools, and Git. Run:

```bash
bash -n agent-env tests/run.sh
./tests/run.sh
./agent-env doctor .
```

The integration tests use temporary directories and do not modify the working repository.
