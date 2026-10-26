# Spacelift Self-Hosted Helm Chart

Helm chart for running [Spacelift Self-Hosted](https://docs.spacelift.io/self-hosted/latest) on Kubernetes. The chart lives in [`spacelift-self-hosted/`](spacelift-self-hosted/README.md).

```sh
helm repo add spacelift https://downloads.spacelift.io/helm
helm repo update
helm upgrade spacelift spacelift/spacelift-self-hosted --install
```

For full setup instructions, see the [reference architecture guides](https://docs.spacelift.io/self-hosted/latest/installing-spacelift/reference-architecture/guides).

## Development

Run the helm-unittest suite (needs Docker):

```sh
make -C spacelift-self-hosted test
```

### Publishing the chart

Push a tag in the format `v<version>`, for example `v0.86.0`, and the publish workflow releases the chart to `downloads.spacelift.io/helm`. Every push to `main` publishes a preprod version to `downloads.spacelift.dev/helm`.
