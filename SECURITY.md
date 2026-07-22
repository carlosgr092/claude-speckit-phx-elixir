# Security Policy

## Supported Versions

`claude-speckit-phx-elixir` is pre-1.0. Security fixes land on the latest
`0.x` release.

| Version | Supported |
|---------|-----------|
| 0.1.x   | ✅        |
| < 0.1   | ❌        |

## Reporting a Vulnerability

**Do not open a public issue for security vulnerabilities.**

Report privately through GitHub Security Advisories:

1. Go to the repository's **Security** tab.
2. Click **Report a vulnerability** (Private vulnerability reporting).
3. Describe the issue, affected files, and reproduction steps.

We aim to acknowledge reports within a few days and to ship a fix or mitigation
as quickly as the severity warrants. Please give us a reasonable window to
respond before any public disclosure.

## Scope and Threat Model

This project is a Claude Code plugin. Please keep the following in mind:

- **Hooks and skills execute shell commands** in the context of your project
  (formatting, verification, git helpers, dependency auditing). Review the
  contents of `hooks/` and any skill's `scripts/` before enabling the plugin in
  a sensitive environment.
- **`hooks/scripts/block-dangerous-ops.sh`** is a defensive guard (it denies
  destructive git/db operations and fails open). It is not a substitute for your
  own review of what the agent is asked to do.
- **The `deps-audit` skill ships defensive detection content** (semgrep and YARA
  rules, plus a supply-chain corpus) used to *scan* your dependencies. These are
  detection rules, not exploits.
- The plugin does not exfiltrate data and ships no secrets. All Elixir-specific
  behavior self-gates on the presence of `mix.exs`.

If you find a way any shipped script can be abused (command injection, path
traversal, privilege issues), that is in scope — please report it privately as
above.
