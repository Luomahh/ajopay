# Agensi use in AjoPay

Reviewed 2026-10-22. The owner confirmed https://www.agensi.io after dictation produced other spellings. Agensi replaces Awesome Copilot as the preferred discovery source. It does not replace Codex, the project-specific roles, or the five-part system design.

## What was actually checked
The public marketplace and MCP service were inspected. The public endpoint accepted an MCP initialize request, tool discovery and a focused code-review search. A broader search timed out; narrower search succeeded. The free Database Design Engine was retrieved for assessment. No credentials, source files, user records or financial data were uploaded; only generic search terms and a public skill slug were sent. No purchase, account sign-in or permanent external skill installation occurred. A project-scoped connector definition was subsequently added in `.codex/config.toml`.

| Candidate | Fit decision |
|---|---|
| Database Design Engine (free listing) | Useful review prompts for entities, constraints, query plans and restore testing. Not adopted as a governing skill: mixes database dialects and contains generic performance percentages, blanket indexing rules and numeric thresholds without AjoPay measurements. Our PostgreSQL schema and measured workload remain authoritative. |
| Flutter Cross Master (paid listing) | Description emphasizes BLoC. Not selected because AjoPay already uses Riverpod and no migration benefit has been demonstrated. Full paid content was not acquired. |
| Code-review search results | Paid candidates returned; not purchased or evaluated beyond listing metadata. Existing independent reviewer and deterministic tests remain in place. |

## How future skills are selected
Start with an actual task and gap: Flutter/Riverpod work, Postgres authorization, payment verification, deployment/recovery, or independent review. Inspect instructions and any executable resources before running them. Check compatibility, provenance, permissions and licensing. Record the source and review date, and recheck changed content when loaded again. Ranking, price and a marketplace security badge do not prove correctness. Do not install scripts or switch state management merely to follow a template.

Retain the three local AjoPay skills and six specialist roles. They encode our real invariants: integer kobo, frozen membership/terms, private receipts, authenticated server authority, test-only provider boundaries and redacted checks. Marketplace instructions are subordinate to the user's scope and repository rules. No broad marketplace downloader or auto-purchase workflow is required.

## Connection state and optional next setup
Agensi has been used through its public MCP API for research. The project now contains `.codex/config.toml` with the Agensi connection and a three-tool allowlist: search, popularity and skill retrieval. Retrieval requests require approval because the same provider tool can purchase when `confirm=true`; no purchase is authorized by this configuration. Restart Codex from the AjoPay workspace to load project settings. The current running conversation has not hot-loaded this connector, and successful activation inside VS Code remains unverified. Its documented public MCP address is `https://mcp.agensi.io/mcp`; authenticated access is separately advertised at `/mcp/auth`. Confirm the current setup guide when registering a connector. Register only needed discovery/retrieval tools, do not enable purchases or publishing by implication, and complete any required sign-in in the provider's UI. No API keys belong in repository configuration.

## Sources
- https://www.agensi.io/mcp
- https://www.agensi.io/docs/mcp-setup
- https://www.agensi.io/skills/database-design-engine
- https://www.agensi.io/skills/flutter-cross-master
- https://developers.openai.com/codex/mcp

This review explains why a marketplace change does not require an application rewrite. The engineering baseline is [AjoPay system design](system-design/README.md).
