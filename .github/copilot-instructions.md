# AjoPay repository guidance

Read and follow the root `AGENTS.md` for architecture, financial/privacy invariants, testing commands and delivery boundaries. Read `docs/system-design/README.md` for the implemented/proposed distinction and `docs/AGENT_WORKFLOW.md` for role handoffs. Keep this file as a bridge to those shared rules rather than duplicating conflicting copies.

Payment code is sandbox-only until explicitly released after the documented readiness gates. Never include server secrets or raw identity data in Flutter assets, logs, examples or commits. Use the repository's security checks; instructions alone cannot prevent leaks.
