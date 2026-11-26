# Helm chart spacelift-self-hosted

This chart deploys Spacelift Self-Hosted on Kubernetes.

## Backend image

By default the chart pulls `oci.spacelift.io/deploy/backend:<appVersion>`.
Set `shared.backendImage` to change the registry, repository, tag or digest, and
`shared.backendImage.fips` to use the FIPS 140 build. Pulling from
`oci.spacelift.io` needs credentials: set them with `shared.imagePullSecrets`.

`shared.image` still works and takes a full image reference, but it is deprecated.
While it is set, the chart ignores `shared.backendImage`.

## Launcher image

Kubernetes workers run the launcher image that the backend reads from
`LAUNCHER_IMAGE` and `LAUNCHER_IMAGE_TAG`. Set `shared.launcherImage.enabled` to
`true` to let the chart set both on the server and drain, by default
to `oci.spacelift.io/deploy/launcher` and the chart's `appVersion`. These
values win over the same keys in your secrets, because
[`env` takes precedence over `envFrom`](https://kubernetes.io/docs/reference/kubernetes-api/core/pod-v1/#Container).
`shared.launcherImage` takes the
same `registry`, `repository`, `tag` and `fips` keys as `shared.backendImage`, but
no digest: the backend joins the two values as `image:tag`.

Leave `shared.launcherImage.enabled` set to `false` only if you also set the
deprecated `shared.image` and your secrets set both keys. Without `shared.image`,
the chart fails to render and asks you to set `shared.launcherImage.enabled: true`.
Without the keys, the backend cannot build the launcher image, and runs on
Kubernetes workers fail.

If you move `shared.image` to `shared.backendImage` while your secrets still set
both keys, the chart fails to render too, because it cannot read your secrets.
Point `shared.launcherImage` at the image from your secrets, or keep
`shared.image` for now.

## Flows

The chart can also deploy [Spacelift Flows](https://docs.spacelift.io/flows): the
server, the worker and the gateway. It is off by default. To turn it on, set
`flows.enabled` to `true` and `flows.domain` to the domain Flows is served on:

```yaml
flows:
  enabled: true
  domain: flows.mycorp.com
```

Flows reads its configuration from a `config.yaml` in a Secret, `spacelift-flows-secret`
by default. Create it in the release namespace before you enable Flows, and set
`flows.secretName` if yours has another name.

By default the chart pulls `oci.spacelift.io/flows/backend:<appVersion>`, with the
credentials from `shared.imagePullSecrets`. Your license has to include Flows for
them to work on this image. Set `flows.image` to change the registry, repository,
tag or digest.

Flows runs with its own service account, `spacelift-flows`, so it does not share
the permissions of the Spacelift backend. Add the annotations for its cloud role
in `flows.serviceAccount.annotations`.

The Flows Ingress routes `flows.domain` and its `endpoints`, `mcp` and `oauth`
subdomains to the server. Set `flows.ingress.exposeGateway` to `true` to also route
`gateway.<domain>` to the gateway, for agents that run outside the cluster.

The Flows agents are not part of this chart. They have their own,
[`spacelift-flows-agent`](https://github.com/spacelift-io/spacelift-helm-charts/tree/main/spacelift-flows-agent).

## Quick Start

Depending on your environment, you can check the [guides here](https://docs.spacelift.io/self-hosted/latest/installing-spacelift/reference-architecture/guides)
for more details about how to use this chart.
