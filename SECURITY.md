# Security Policy

## Supported versions

| Image | Supported |
|-------|-----------|
| `8.4` (OpenLiteSpeed 1.9.4, LSPHP 8.4) | :white_check_mark: |

Older digests stay in the registry for reproducibility but do not receive fixes. Pull the current tag.

## Reporting a vulnerability

**Please report privately**, using GitHub's private vulnerability reporting:

- [Report a vulnerability](https://github.com/sitespanel/openlitespeed-docker/security/advisories/new)

That keeps the details between us until there is a fix to ship. Please do not open a public issue for a security problem.

Include:

- a clear description, and what an attacker gains
- steps to reproduce, ideally as a `docker run` a maintainer can paste
- the image tag or digest affected

Expect a first response within 48 hours.

## Upstream components

OpenLiteSpeed and LSPHP come from LiteSpeed's signed package repository (the key fingerprint is checked in the `Dockerfile`) on Ubuntu. A vulnerability in one of them is fixed by a package bump and a rebuild; report it upstream as well:

- [OpenLiteSpeed](https://github.com/litespeedtech/openlitespeed/security)
