# Building this image with Google Cloud Build

This repository is the source of SitesPanel's `openlitespeed` image. SitesPanel builds it with **Google Cloud Build** and serves it from **Artifact Registry** (`europe` multi-region, repository `sitespanel-images`), as decided in the panel's ADR-0065.

## What runs

| File | When | What it does |
|---|---|---|
| `cloudbuild.yaml` | a push to `main` that touches `Dockerfile`, `ols-run`, `site/**`, `nss/**`; and the weekly rebuild | builds, scans with Trivy (a fixable critical vulnerability stops the build before anything is pushed), writes an SPDX SBOM per image to `gs://<_SBOM_BUCKET>/openlitespeed/<commit>/`, then pushes with SLSA provenance (`requestedVerifyOption: VERIFIED`) |
| `cloudbuild-pr.yaml` | a pull request to `main` | builds and scans only; pushes nothing, uses no secret |

Images and tags pushed to `europe-docker.pkg.dev/<project>/sitespanel-images/openlitespeed`: `8.4`, `8.4-$SHORT_SHA`. The commit-tagged digests carry the provenance; the other tags name the same digests. The SitesPanel image manifest picks digests, never tags.

## One-time setup (Google Cloud, by the founder)

Replace `PROJECT`, `REGION` (the region of the GitHub host connection) and `CONNECTION` (its name).

1. **Link this repository to the host connection** (2nd-generation repositories):

   ```
   gcloud builds repositories create openlitespeed-docker --project=PROJECT --region=REGION --connection=CONNECTION --remote-uri=https://github.com/sitespanel/openlitespeed-docker.git
   ```

2. **Once for all five repositories**: the Artifact Registry repository, the SBOM bucket and a build service account that can only push images and write SBOMs:

   ```
   gcloud artifacts repositories create sitespanel-images --project=PROJECT --location=europe --repository-format=docker --description="SitesPanel first-party images (ADR-0065)"
   gcloud storage buckets create gs://sitespanel-image-sboms-europe --project=PROJECT --location=EU --uniform-bucket-level-access
   gcloud iam service-accounts create sitespanel-image-builder --project=PROJECT --display-name="SitesPanel image builder (Cloud Build)"
   gcloud artifacts repositories add-iam-policy-binding sitespanel-images --project=PROJECT --location=europe --member=serviceAccount:sitespanel-image-builder@PROJECT.iam.gserviceaccount.com --role=roles/artifactregistry.writer
   gcloud storage buckets add-iam-policy-binding gs://sitespanel-image-sboms-europe --member=serviceAccount:sitespanel-image-builder@PROJECT.iam.gserviceaccount.com --role=roles/storage.objectCreator
   gcloud projects add-iam-policy-binding PROJECT --member=serviceAccount:sitespanel-image-builder@PROJECT.iam.gserviceaccount.com --role=roles/logging.logWriter
   ```

   Making the repository public (`allUsers` reader) and its per-client-IP request limit are steps of the panel's TASK-0287, after the first images are in.

3. **Triggers for this repository:**

   ```
   gcloud builds triggers create github --project=PROJECT --region=REGION \
     --name=sitespanel-openlitespeed-docker-image-publish-main-europe \
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
     --name=sitespanel-openlitespeed-docker-image-weekly-rebuild-europe \
     --repository=projects/PROJECT/locations/REGION/connections/CONNECTION/repositories/openlitespeed-docker \
     --branch=main --build-config=cloudbuild.yaml \
     --service-account=projects/PROJECT/serviceAccounts/sitespanel-image-builder@PROJECT.iam.gserviceaccount.com
   ```

4. **Weekly rebuild** (base-image security fixes arrive without a commit here): a Cloud Scheduler job runs the manual trigger every Monday at 03:00 UTC:

   ```
   gcloud scheduler jobs create http sitespanel-openlitespeed-docker-image-weekly-rebuild-europe --project=PROJECT --location=REGION \
     --schedule='0 3 * * 1' --time-zone=Etc/UTC --http-method=POST \
     --uri='https://cloudbuild.googleapis.com/v1/projects/PROJECT/locations/REGION/triggers/sitespanel-openlitespeed-docker-image-weekly-rebuild-europe:run' \
     --message-body='{"source":{"branchName":"main"}}' \
     --oauth-service-account-email=sitespanel-image-builder@PROJECT.iam.gserviceaccount.com
   ```

   The scheduler's service account needs `roles/cloudbuild.builds.editor` on the project (or a narrower custom role with `cloudbuild.builds.create`).

Record every created resource in the SitesPanel cloud-resources register with its delete-by rule.

## Notes

- The scanner is Trivy 0.76.0 pinned by digest. A scan reads the image as a saved archive, so no step needs the Docker socket beyond the Docker builder.
- Base images (`php`, `nginx`, `httpd`, `caddy`, `debian`, `dunglas/frankenphp`) and the scanner come from Docker Hub's official images, which limit anonymous pulls per address; Cloud Build's shared addresses can hit that limit. If builds fail on pulls, add an Artifact Registry **remote repository** for Docker Hub in `europe` and pull base images through it (a later step, not needed to start).
- PHP 8.2 is not built here: SitesPanel offers 8.3 to 8.5 (panel ADR-0034).
