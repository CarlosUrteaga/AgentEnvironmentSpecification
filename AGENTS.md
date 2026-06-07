<!-- BEGIN AGENT-ENV: AGENTS -->
# Agent Environment Specification Agent Instructions

## Project Context

- **Purpose:** Provide a repeatable stack-neutral workspace bootstrap for coding agents
- **Audience:** Software engineers using coding agents for new or existing repositories
- **First milestone:** Ship a portable Bash CLI that initializes validates renders and diagnoses an agent-ready repository
- **Technology constraints:** Bash 3.2 or newer standard Unix tools and Git on macOS and Linux

## Commands

- **Setup:** `No setup required`
- **Tests:** `./tests/run.sh`
- **Lint:** `bash -n agent-env tests/run.sh`

Treat `unknown` as a request to inspect the repository, establish the appropriate command, and update the environment contract.

## Boundaries

- **Allowed actions:** Read repository files; edit task-related files; run syntax checks and integration tests
- **Restricted paths or resources:** Secrets; production credentials; files outside the selected target repository
- **Definition of done:** The CLI safely generates repeatable managed agent instructions and all integration tests pass

## Agent Behavior

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

### 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:

- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them; don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

### 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No flexibility or configurability that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

### 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:

- Don't improve adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it; don't delete it.

When your changes create orphans:

- Remove imports, variables, and functions that your changes made unused.
- Don't remove pre-existing dead code unless asked.

Every changed line should trace directly to the user's request.

### 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:

- "Add validation" becomes "Write tests for invalid inputs, then make them pass."
- "Fix the bug" becomes "Write a test that reproduces it, then make it pass."
- "Refactor X" becomes "Ensure tests pass before and after."

For multi-step tasks, state a brief plan:

```text
1. [Step] -> verify: [check]
2. [Step] -> verify: [check]
3. [Step] -> verify: [check]
```

Strong success criteria let you loop independently. Weak criteria such as "make it work" require clarification.

Project-specific instructions may supplement these guidelines but must not silently weaken them. These are behavioral instructions, not sandbox enforcement.
<!-- END AGENT-ENV: AGENTS -->
