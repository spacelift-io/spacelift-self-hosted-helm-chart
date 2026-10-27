# Spacelift Self-Hosted Helm Chart

[![PR checks](https://github.com/spacelift-io/spacelift-self-hosted-helm-chart/actions/workflows/workflow_pr.yaml/badge.svg)](https://github.com/spacelift-io/spacelift-self-hosted-helm-chart/actions/workflows/workflow_pr.yaml)
[![Publish](https://github.com/spacelift-io/spacelift-self-hosted-helm-chart/actions/workflows/workflow_chart-publish-prod.yaml/badge.svg)](https://github.com/spacelift-io/spacelift-self-hosted-helm-chart/actions/workflows/workflow_chart-publish-prod.yaml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Helm chart for running [Spacelift Self-Hosted](https://docs.spacelift.io/self-hosted/latest) on Kubernetes. It deploys the Spacelift server, drain, VCS Gateway and the supporting services, ingress and service account wiring.

## ✨ Usage

Chart versions follow Spacelift versions, so chart `7.2.0` installs Spacelift `7.2.0`.

The chart needs some infrastructure to exist first (database, object storage, message queue and so on), so start with the [reference architecture guides](https://docs.spacelift.io/self-hosted/latest/installing-spacelift/reference-architecture/guides). They cover each supported cloud and show the values you'll need.

### Install

Add the repository and install the latest version:

```sh
helm repo add spacelift https://downloads.spacelift.io/helm
helm repo update
helm install spacelift spacelift/spacelift-self-hosted --values values.yaml
```

### Upgrade

Refresh the repository and upgrade to the latest version:

```sh
helm repo update
helm upgrade spacelift spacelift/spacelift-self-hosted --values values.yaml
```

To move to a specific version instead, list the available ones and pass `--version`:

```sh
helm search repo spacelift/spacelift-self-hosted --versions
helm upgrade spacelift spacelift/spacelift-self-hosted --version <version> --values values.yaml
```

### Configuration

All options are documented in [`values.yaml`](spacelift-self-hosted/values.yaml) and validated by [`values.schema.json`](spacelift-self-hosted/values.schema.json).

To see what the chart renders before you apply it:

```sh
helm template spacelift spacelift/spacelift-self-hosted --values values.yaml
```

## 🛠 Contributing

Contributions are welcome. A few tips:

- Run the [helm-unittest](https://github.com/helm-unittest/helm-unittest) suite before opening a PR. It runs in Docker, so you don't need the plugin installed:

  ```sh
  make -C spacelift-self-hosted test
  ```

  To run a subset, pass a file pattern: `make -C spacelift-self-hosted test HELM_UNITTEST_FILE='tests/server_ingress_test.yaml'`.

- If you add or change a value, update `values.schema.json` to match. `helm lint --strict` runs on every PR and validates against it.

- Please follow [Conventional Commits](https://www.conventionalcommits.org/) so the changelog stays readable.

### Releasing

Every push to `main` publishes a preprod version of the chart to `downloads.spacelift.dev/helm`.

To release to production, push a tag in the `v<version>` format, for example `v7.2.0`. The publish workflow picks it up and releases the chart to `downloads.spacelift.io/helm`.
