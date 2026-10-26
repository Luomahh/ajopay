# AjoPay agent workflow

Status: repository instructions, project agent definitions and three project skills are added. Their behaviour is reviewed in this task; actual discovery depends on opening this repository in a compatible Codex host. These files are not a claim that seven agents run continuously.

## Who does what
The main Codex conversation is the orchestrator. It reads the request, selects relevant specialists, assigns non-overlapping files, integrates changes and checks the result. It does not delegate away responsibility.

| Agent | Assignment | Handoff |
|---|---|---|
| ajopay-planner | Requirements and design, read-only | Scope, assumptions, acceptance tests, dependencies |
| ajopay-flutter | Presentation and application state | Implementation and user-visible tests |
| ajopay-backend | SQL/RPC/payment boundaries | Migration/contract changes and adversarial tests |
| ajopay-devops | CI/environments/recovery | Reproducible commands, permissions, deployment limits |
| ajopay-reviewer | Independent read-only review | Concrete findings with file/line and reproduction |
| ajopay-security | Secret/privacy/trust-boundary review | Redacted findings and scanner evidence |

For a substantial feature: planner returns a plan; orchestrator assigns implementation; reviewer checks the actual diff; implementer fixes findings; orchestrator verifies the result. Security/DevOps join when their concerns apply. A small typo does not need the whole team. Do not let separate agents edit the same file simultaneously. Read-only is a role instruction, not a separate permission sandbox.

## Files and discovery
- `AGENTS.md`: shared product rules, architecture boundaries and commands.
- `.github/copilot-instructions.md`: Copilot bridge to shared rules.
- `.codex/config.toml`: Agensi discovery/retrieval connection; no credentials or publishing tools. Restart the workspace Codex session to load it.
- `.codex/agents/*.toml`: project-specific Codex roles. No model override, credentials, approval override or extra tools are configured.
- `.agents/skills/*/SKILL.md`: only Flutter delivery, Supabase changes and release review.

Open `/Users/theoneglobal/Documents/Projects/ajopay` as the VS Code workspace and start Codex there so repository-scoped configuration is discoverable. If newly added skills do not appear, restart the Codex session. Do not assume Copilot custom-agent formats configure Codex; this repository uses Codex-native agent TOML. A Copilot agent catalog is not installed.

Example request: “Use the AjoPay planner to scope contribution reconciliation, have the backend agent implement the approved slice, and ask the reviewer and security agent to check the diff. Keep provider calls in test mode.”

Skills can be requested by name, for example `$ajopay-supabase-changes`. Agensi is the preferred discovery source for optional external skills; see [Agensi review](AGENSI_SKILL_REVIEW.md). No additional plugins are required for this baseline. Review third-party instructions before adapting them; never install a broad template collection just for the number of agents it contains.

## Review and secrets
A reviewer must report evidence rather than approve automatically. A scanner is a deterministic gate; a security agent adds contextual review. Neither guarantees that a repository is leak-free. CI workflow definitions only execute after they are committed/pushed to GitHub; branch protection and required checks need separate repository configuration.

## Sources checked 2026-10-16
- https://developers.openai.com/codex/guides/agents-md
- https://developers.openai.com/codex/subagents
- https://developers.openai.com/codex/skills
- https://www.agensi.io/ (preferred marketplace, confirmed by the project owner on 2026-10-22)
