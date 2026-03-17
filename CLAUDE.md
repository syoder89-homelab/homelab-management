# Claude Code Instructions

Read [AGENTS.md](AGENTS.md) for full repository context, architecture, and conventions.

## Critical Rules

- **All commits MUST be GPG-signed.** Never use `--no-gpg-sign`, `-c commit.gpgsign=false`, or any other mechanism to bypass commit signing. If signing fails, stop and ask the user to resolve the issue — do not work around it.
- **Never commit secrets in plaintext** — use External Secrets Operator with 1Password Connect.
- **Do not manually create ArgoCD Application or Kargo Stage manifests** — the `application-generator` chart auto-generates them.
