<!-- BEGIN AGENT-ENV: POLICY -->
# Agent Policy

## Allowed

Read repository files; edit task-related files; run syntax checks and integration tests

## Restricted

Secrets; production credentials; files outside the selected target repository

## Required Evidence

- Summarize changed files.
- Report checks run and their results.
- State any checks that could not be run.

This document guides agent behavior. It does not enforce operating-system permissions or provide a security sandbox.
<!-- END AGENT-ENV: POLICY -->
