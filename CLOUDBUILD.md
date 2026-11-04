# Building this image with Google Cloud Build

This repository is the source of SitesPanel's `openlitespeed` image. **Google Cloud Build** builds it and publishes it to the **GitHub Container Registry** as `ghcr.io/sitespanel/openlitespeed`, public (the panel's ADR-0065, amended 2026-11-04).

Why this shape: Cloud Build gives 2,500 free build-minutes a month, but only on the default `e2-standard-2` machine, so the builds use that machine and run one image at a time; the GitHub Container Registry's storage and bandwidth are currently free (GitHub promises a month's notice before any change), which suits images every customer server pulls.

## What runs

| File | When | What it does |
|---|---|---|
| `cloudbuild.yaml` | a push to `main` that touches `Dockerfile`, `ols-run`, `site/**`, `nss/**`; and the weekly rebuild | builds each image, scans it with Trivy (a fixable critical vulnerability stops the build before anything is pushed), pushes to `ghcr.io/sitespanel/openlitespeed`, and attaches each image's SPDX SBOM to its digest with ORAS |
| `cloudbuild-pr.yaml` | a pull request to `main` | builds and scans only; pushes nothing, reads no secret |

Tags: `8.4`, `8.4-$SHORT_SHA`. The SitesPanel image manifest picks **digests**, never tags; each image carries the labels `org.opencontainers.image.source`, `org.opencontainers.image.revision` (the commit) and `dev.sitespanel.build.id` (the Cloud Build build).

## One-time setup (by the founder)

Replace `PROJECT`, `REGION` (the region of the GitHub host connection) and `CONNECTION` (its name).

1. **GitHub side, once for all repositories:** a machine account `sitespanel-image-builder` that is a member of the `sitespanel` organisation, and a **classic** personal access token for it with only the `write:packages` scope (GitHub Packages accepts only classic tokens). Create it at `https://github.com/settings/tokens/new?scopes=write:packages`: selecting `write:packages` on the normal page also ticks the broad `repo` scope, this address does not. Set an expiry of at most a year. A package pushed from the command line starts **private**; after the first push of each image, set its visibility to **public** in the package settings. The `org.opencontainers.image.source` label links it to this repository, and the description label shows on the package page.

2. **Google Cloud side, once:** the token in Secret Manager and a build service account that can read only that secret and write logs:

   ```
   printf '%s' 'TOKEN' | gcloud secrets create sitespanel-ghcr-image-push-token-cloudbuild --project=PROJECT --replication-policy=automatic --data-file=-
   gcloud iam service-accounts create sitespanel-image-builder --project=PROJECT --display-name="SitesPanel image builder (Cloud Build)"
   gcloud secrets add-iam-policy-binding sitespanel-ghcr-image-push-token-cloudbuild --project=PROJECT --member=serviceAccount:sitespanel-image-builder@PROJECT.iam.gserviceaccount.com --role=roles/secretmanager.secretAccessor
   gcloud projects add-iam-policy-binding PROJECT --member=serviceAccount:sitespanel-image-builder@PROJECT.iam.gserviceaccount.com --role=roles/logging.logWriter
   ```

   Type the token yourself; never paste it into a chat or a file.

3. **Link this repository to the host connection:**

   ```
   gcloud builds repositories create openlitespeed-docker --project=PROJECT --region=REGION --connection=CONNECTION --remote-uri=https://github.com/sitespanel/openlitespeed-docker.git
   ```

4. **Triggers:**

   ```
   gcloud builds triggers create github --project=PROJECT --region=REGION \
     --name=sitespanel-openlitespeed-docker-image-publish-main-ghcr \
     --repository=projects/PROJECT/locations/REGION/connections/CONNECTION/repositories/openlitespeed-docker \
     --branch-pattern='^main$' --build-config=cloudbuild.yaml --included-files='Dockerfile,ols-run,site/**,nss/**' \
     --service-account=projects/PROJECT/serviceAccounts/sitespanel-image-builder@PROJECT.iam.gserviceaccount.com

   gcloud builds triggers create github --project=PROJECT --region=REGION \
     --name=sitespanel-openlitespeed-docker-image-check-pull-request \
     --repository=projects/PROJECT/locations/REGION/connections/CONNECTION/repositories/openlitespeed-docker \
     --pull-request-pattern='^main$' --comment-control=COMMENTS_ENABLED_FOR_EXTERNAL_CONTRIBUTORS_ONLY \
     --build-config=cloudbuild-pr.yaml \
     --service-account=projects/PROJECT/serviceAccounts/sitespanel-image-builder@PROJECT.iam.gserviceaccount.com

   gcloud builds triggers create manual --project=PROJECT --region=REGION \
     --name=sitespanel-openlitespeed-docker-image-weekly-rebuild-ghcr \
     --repository=projects/PROJECT/locations/REGION/connections/CONNECTION/repositories/openlitespeed-docker \
     --branch=main --build-config=cloudbuild.yaml \
     --service-account=projects/PROJECT/serviceAccounts/sitespanel-image-builder@PROJECT.iam.gserviceaccount.com
   ```

5. **Weekly rebuild** (base-image security fixes arrive without a commit here), Mondays 03:00 UTC:

   ```
   gcloud scheduler jobs create http sitespanel-openlitespeed-docker-image-weekly-rebuild-ghcr --project=PROJECT --location=REGION \
     --schedule='0 3 * * 1' --time-zone=Etc/UTC --http-method=POST \
     --uri='https://cloudbuild.googleapis.com/v1/projects/PROJECT/locations/REGION/triggers/sitespanel-openlitespeed-docker-image-weekly-rebuild-ghcr:run' \
     --message-body='{"source":{"branchName":"main"}}' \
     --oauth-service-account-email=sitespanel-image-builder@PROJECT.iam.gserviceaccount.com
   ```

   The scheduler's service account needs permission to run builds (`roles/cloudbuild.builds.editor`, or a custom role with `cloudbuild.builds.create`).

Record every created resource in the SitesPanel cloud-resources register with its delete-by rule.

## Notes

- **Free tier:** keep the default machine. A larger `machineType` is billed from the first minute. Pull-request builds count against the same minutes, which is why they build a subset where the matrix is large.
- **Egress:** pushing to ghcr.io leaves Google's network and is billed at standard network rates; only new layers are uploaded, so a rebuild that changes little costs little.
- **Provenance:** Cloud Build's signed SLSA provenance is generated only for images pushed to Google's Artifact Registry, so these images do not carry it. Trust comes from the SitesPanel manifest: it pins each approved digest after its own scan and is signed with the SitesPanel manifest key; the labels name the commit and the build.
- **Pinned tools:** Trivy 0.76.0 and ORAS 1.3.5, both by digest. A scan reads the image as a saved archive, so only the Docker builder step touches the Docker daemon.
- **Base images** come from Docker Hub's official images, which limit anonymous pulls per address; Cloud Build's shared addresses can hit that limit. If builds fail on pulls, pull base images through a registry proxy (a later step, not needed to start).
