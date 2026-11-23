# Contributing

Thanks for your interest in improving this OpenLiteSpeed image.

## Report a bug

Open an issue with the image tag or digest, what you ran (`docker run` or compose, with secrets removed), what you expected and what happened.

Security problems go through private vulnerability reporting instead (see [SECURITY.md](SECURITY.md)).

## Submit a pull request

1. Fork the repository and branch from `main`.
2. Make the change in the `Dockerfile`, `ols-run` or the configuration it writes. Package versions are pinned in the `ARG` lines at the top; bump a version there, never by removing the pin.
3. Build and run it locally:
   ```bash
   docker build -t test-ols .
   docker run --rm test-ols /usr/local/lsws/bin/openlitespeed -v
   ```
4. Open the pull request against `main` with a clear description. CI lints, builds and scans it (a fixable high or critical vulnerability fails the build); it is published only after the merge.
