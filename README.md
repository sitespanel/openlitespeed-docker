# OpenLiteSpeed with LSPHP 8.4

[![image](https://github.com/sitespanel/openlitespeed-docker/actions/workflows/image.yml/badge.svg)](https://github.com/sitespanel/openlitespeed-docker/actions/workflows/image.yml) [![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/sitespanel/openlitespeed-docker/badge)](https://scorecard.dev/viewer/?uri=github.com/sitespanel/openlitespeed-docker)

> **SitesPanel image source.** GitHub Actions builds this image and publishes it to the GitHub Container Registry as `ghcr.io/sitespanel/openlitespeed`; see [BUILD.md](BUILD.md).

The OpenLiteSpeed origin image for SitesPanel sites (the panel's ADR-0044, TASK-0198): Ubuntu 26.04, OpenLiteSpeed and LSPHP 8.4 from LiteSpeed's signed repository (key fingerprint in the `Dockerfile`), with APCu, Imagick, Redis and igbinary. Its history before 2026-11-04 is the panel repository's `images/openlitespeed` folder, kept here with `git subtree split`.

## Files

| Path | What |
|---|---|
| `Dockerfile` | the image |
| `ols-run` | the container's entry point |
| `site/`, `nss/` | the configuration an idle container starts with. They are **copies of the panel's idle render** (the panel owns them in `contracts/openlitespeed-idle/`); `pin.json` lists each file's SHA-256 and the panel commit they came from. After the panel changes its renderer, copy the new files here and update `pin.json`. |

No file of another project is read at build time (the panel's ADR-0066).
