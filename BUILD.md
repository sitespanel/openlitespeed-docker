# How this image is built

This repository is the source of SitesPanel's `openlitespeed` image. **GitHub Actions** builds it and publishes it to the **GitHub Container Registry** as `ghcr.io/sitespanel/openlitespeed` (the SitesPanel panel's ADR-0065, amended 2026-11-04). The workflow is `.github/workflows/image.yml`.

## What runs

| Event | What happens |
|---|---|
| Push to `main` touching the image's files, the weekly rebuild (Mondays 03:00 UTC), or a manual run | build, scan with Trivy (a fixable critical vulnerability stops the job before any push), push with the workflow's own `GITHUB_TOKEN`, then a signed **build-provenance attestation** and an **SBOM attestation** (SPDX, from Trivy) on each digest, pushed to the registry |
| Pull request to `main` | build and scan only; no push, no write permission |

Tags: `8.4`, `8.4-<commit>`. SitesPanel's image manifest picks **digests**, never tags. Verify an image and its attestation with:

```
gh attestation verify oci://ghcr.io/sitespanel/openlitespeed@sha256:DIGEST --owner sitespanel
```

## Why GitHub Actions

GitHub-hosted runners are free for public repositories, a standard Linux runner has 4 CPUs and 16 GB of memory, the workflow's token pushes to ghcr.io without a stored secret and links the package to this repository, and the attestations give signed provenance (SLSA v1.0 Build Level 2). The GitHub Container Registry's storage and bandwidth are currently free (GitHub promises at least a month's notice before any change). All read on docs.github.com on 2026-11-04.

## One-time steps (by the founder)

1. After the first successful push, open the package `openlitespeed` in the `sitespanel` organisation's packages and set its visibility to **public** (a new package starts private); confirm it shows this repository as linked.
2. In this repository's settings, Actions: allow GitHub Actions, and keep "Read repository contents" as the default workflow permission (the workflow asks for package and attestation write itself).

## Notes

- Actions are pinned to the commit of their release (version in a comment), the newest release of each on 2026-11-04; Trivy (0.76.1) and Hadolint (2.15.1) run from their images pinned by digest. Dependabot opens a pull request every week when a newer action or base image exists (`.github/dependabot.yml`); merge it after its checks pass, so the pins stay current.
- Each runner has 14 GB of disk; every matrix entry runs on its own runner.
- Base images come from Docker Hub's official images; anonymous pull limits apply per runner address.
