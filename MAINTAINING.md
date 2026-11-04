# Maintaining this repository

For the SitesPanel maintainers. How the image is built is in [BUILD.md](BUILD.md).

## Repository settings (set once, by an organisation owner)

| Setting | Value | Why |
|---|---|---|
| Visibility | public | free Actions minutes and a free public package |
| Default branch | `main` | the workflows publish only from `main` |
| Ruleset on `main` | pull request required, 1 approving review from code owners, conversations resolved, status check `checks` required and up to date (it passes only when `lint` and every image build passed); organisation owners may merge their own pull request without a second reviewer, never push directly, linear history, no force push, no deletion | nothing reaches the published image without review and a passing scan |
| Actions, workflow permissions | read repository contents by default; workflows may not approve pull requests | each workflow asks for the write permissions it needs |
| Actions, allowed actions | GitHub-owned, verified creators, and `aquasecurity/*`, `ossf/*` (all pinned by commit) | the smallest set the workflows use |
| Code security | secret scanning, push protection, Dependabot alerts, Dependabot security updates, private vulnerability reporting: all on | leaked tokens are blocked, and SECURITY.md's report link works |
| Team | `sitespanel/maintainers` exists, holds the maintainers, and has the maintain role on this repository | CODEOWNERS names it; a review request goes to the team |
| Package `openlitespeed` | public, linked to this repository | servers pull it without credentials |

The same settings with the GitHub CLI (an owner runs them after the first push, because the ruleset blocks direct pushes to `main`):

```
gh api -X POST orgs/sitespanel/teams -f name=maintainers -f privacy=closed   # once for the organisation
gh api -X PUT orgs/sitespanel/teams/maintainers/repos/sitespanel/openlitespeed-docker -f permission=maintain
gh api -X PUT repos/sitespanel/openlitespeed-docker/vulnerability-alerts
gh api -X PUT repos/sitespanel/openlitespeed-docker/automated-security-fixes
gh api -X PUT repos/sitespanel/openlitespeed-docker/private-vulnerability-reporting
gh api -X PATCH repos/sitespanel/openlitespeed-docker -f 'security_and_analysis[secret_scanning][status]=enabled' -f 'security_and_analysis[secret_scanning_push_protection][status]=enabled'
gh api -X PUT repos/sitespanel/openlitespeed-docker/actions/permissions/workflow -f default_workflow_permissions=read -F can_approve_pull_request_reviews=false
gh api -X POST repos/sitespanel/openlitespeed-docker/rulesets --input ruleset-main.json
```

`ruleset-main.json` (in this folder, not used by any build) holds the `main` ruleset above.

## Routine

- **Every Monday:** Dependabot's pull requests for actions and base images; merge them once `checks` passes. The weekly rebuild runs at 03:00 UTC.
- **A failed scan** (a fixable critical vulnerability): update the base image or the package in the `Dockerfile`, open a pull request, merge when green. Nothing was pushed by the failed run.
- **A new upstream version** (PHP, nginx, httpd, Caddy, Adminer, OpenLiteSpeed): bump the `ARG` or `FROM` line in a pull request; the tags follow the `Dockerfile`.
- **Releases:** the image is the release; there are no Git release tags. SitesPanel's servers use only digests listed in the signed SitesPanel image manifest.
- **OpenSSF Scorecard:** the weekly result is public; fix any check that drops.
