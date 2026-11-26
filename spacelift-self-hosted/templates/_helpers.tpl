{{/*
Expand the name of the server.
*/}}
{{- define "spacelift.serverName" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Expand the name of the chart.
*/}}
{{- define "spacelift.drainName" -}}
{{- printf "%s-drain" (default .Values.nameOverride .Chart.Name) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "spacelift.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "spacelift.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Server labels
*/}}
{{- define "spacelift.serverLabels" -}}
helm.sh/chart: {{ include "spacelift.chart" . }}
{{ include "spacelift.serverSelectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Common drain labels
*/}}
{{- define "spacelift.drainLabels" -}}
helm.sh/chart: {{ include "spacelift.chart" . }}
{{ include "spacelift.drainSelectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Server Selector labels
*/}}
{{- define "spacelift.serverSelectorLabels" -}}
app.kubernetes.io/name: {{ include "spacelift.serverName" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Selector drain labels
*/}}
{{- define "spacelift.drainSelectorLabels" -}}
app.kubernetes.io/name: {{ include "spacelift.drainName" . }}
app.kubernetes.io/instance: {{ printf "%s-drain" .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "spacelift.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "spacelift.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the service account to use for the server.
*/}}
{{- define "spacelift.serverServiceAccountName" -}}
{{- if .Values.server.serviceAccount.create }}
{{- .Values.server.serviceAccount.name }}
{{- else }}
{{- include "spacelift.serviceAccountName" . }}
{{- end }}
{{- end }}

{{/*
Create the name of the service account to use for the drain.
*/}}
{{- define "spacelift.drainServiceAccountName" -}}
{{- if .Values.drain.serviceAccount.create }}
{{- .Values.drain.serviceAccount.name }}
{{- else }}
{{- include "spacelift.serviceAccountName" . }}
{{- end }}
{{- end }}

{{/*
The <registry>/<repository>[-fips] part of an image, from a dict with the
registry, repository and fips keys (.Values.shared.backendImage or
.Values.shared.launcherImage).
*/}}
{{- define "spacelift.imageRepository" -}}
	{{- $repository := .repository -}}
	{{- if .fips -}}
		{{- $repository = printf "%s-fips" $repository -}}
	{{- end -}}
	{{- with .registry -}}
		{{- $repository = printf "%s/%s" (trimSuffix "/" .) $repository -}}
	{{- end -}}
	{{- $repository -}}
{{- end -}}

{{- define "spacelift.backendImage" -}}
	{{- if .Values.shared.image -}}
		{{- .Values.shared.image -}}
	{{- else -}}
		{{- $image := .Values.shared.backendImage -}}
		{{- $repository := include "spacelift.imageRepository" $image -}}
		{{- if $image.digest -}}
			{{- printf "%s@%s" $repository $image.digest -}}
		{{- else -}}
			{{- printf "%s:%s" $repository (include "spacelift.backendImageTag" .) -}}
		{{- end -}}
	{{- end -}}
{{- end -}}

{{/*
The tag of .Values.shared.backendImage, which defaults to the chart appVersion.
*/}}
{{- define "spacelift.backendImageTag" -}}
{{- .Values.shared.backendImage.tag | default .Chart.AppVersion -}}
{{- end -}}

{{/*
The LAUNCHER_IMAGE and LAUNCHER_IMAGE_TAG env vars from .Values.shared.launcherImage,
as container env entries. Renders nothing when launcherImage is disabled.

The backend joins the two values as LAUNCHER_IMAGE:LAUNCHER_IMAGE_TAG, which is
why launcherImage has no digest.

Fails when launcherImage is disabled and the deprecated .Values.shared.image is not
set. The secrets from secretRef carry LAUNCHER_IMAGE and LAUNCHER_IMAGE_TAG only
when they also carry the backend image, which goes to shared.image. Without both
env vars the backend builds an empty launcher image, and runs on Kubernetes
workers fail.

The check also fails for users who moved shared.image to shared.backendImage
while their secrets still carry both env vars. The chart cannot read the
secrets, so the error message covers that case too.
*/}}
{{- define "spacelift.launcherImageEnv" -}}
	{{- $image := .Values.shared.launcherImage -}}
	{{- if $image.enabled -}}
- name: LAUNCHER_IMAGE
  value: {{ include "spacelift.imageRepository" $image | quote }}
- name: LAUNCHER_IMAGE_TAG
  value: {{ $image.tag | default .Chart.AppVersion | quote }}
	{{- else if not .Values.shared.image -}}
		{{- /* The leading newline puts the message below Helm's "execution error at" prefix. */ -}}
		{{- fail `
shared.image is not set and shared.launcherImage.enabled is false. The chart
then sets no LAUNCHER_IMAGE or LAUNCHER_IMAGE_TAG, and it cannot check whether
your secrets set them. Without them, runs on Kubernetes workers fail.

Pick the case that fits you:

1. Your infrastructure comes from a Spacelift self-hosted Terraform module with
   create_container_registry = false. The module creates no container registry,
   so its kubernetes_secrets output has no LAUNCHER_IMAGE or LAUNCHER_IMAGE_TAG.
   Let the chart set the launcher image:

     shared:
       launcherImage:
         enabled: true

   This pulls oci.spacelift.io/deploy/launcher, tagged with the chart appVersion.
   Set registry, repository, tag or fips to pull another image.

2. You moved shared.image to shared.backendImage, and your secrets still set
   LAUNCHER_IMAGE and LAUNCHER_IMAGE_TAG, for example because the Terraform
   module still creates the container registry. Keep shared.image for now, or
   point shared.launcherImage at the image from your secrets:

     shared:
       launcherImage:
         enabled: true
         registry: <host part of LAUNCHER_IMAGE>
         repository: <LAUNCHER_IMAGE after the host>
         tag: <LAUNCHER_IMAGE_TAG>

The shared.launcherImage values win over LAUNCHER_IMAGE and LAUNCHER_IMAGE_TAG
in your secrets.` -}}
	{{- end -}}
{{- end -}}

{{/*
Expand the name of the VCS Gateway.
*/}}
{{- define "spacelift.vcsGatewayName" -}}
{{- printf "%s-vcs-gateway" (default .Values.nameOverride .Chart.Name) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
VCS Gateway labels
*/}}
{{- define "spacelift.vcsGatewayLabels" -}}
helm.sh/chart: {{ include "spacelift.chart" . }}
{{ include "spacelift.vcsGatewaySelectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
VCS Gateway Selector labels
*/}}
{{- define "spacelift.vcsGatewaySelectorLabels" -}}
app.kubernetes.io/name: {{ include "spacelift.vcsGatewayName" . }}
app.kubernetes.io/instance: {{ printf "%s-vcs-gateway" .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use for the VCS Gateway.
*/}}
{{- define "spacelift.vcsGatewayServiceAccountName" -}}
{{- if .Values.vcsGateway.serviceAccount.create }}
{{- .Values.vcsGateway.serviceAccount.name }}
{{- else }}
{{- include "spacelift.serviceAccountName" . }}
{{- end }}
{{- end }}

{{/*
Validates PodDisruptionBudget configuration
*/}}
{{- define "spacelift.validatePodDisruptionBudget" -}}
{{- if and (hasKey . "minAvailable") (hasKey . "maxUnavailable") }}
{{- fail "pdb.minAvailable and pdb.maxUnavailable are mutually exclusive; set only one" }}
{{- end }}
{{- if and (not (hasKey . "minAvailable")) (not (hasKey . "maxUnavailable")) }}
{{- fail "pdb.enabled is true but neither pdb.minAvailable nor pdb.maxUnavailable is set; set exactly one" }}
{{- end }}
{{- end }}

{{/*
Expand the name of Flows.
*/}}
{{- define "spacelift.flowsName" -}}
{{- printf "%s-flows" (default .Chart.Name .Values.nameOverride) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Flows labels. The server, worker and gateway share them, and each adds its own
app.kubernetes.io/component.
*/}}
{{- define "spacelift.flowsLabels" -}}
helm.sh/chart: {{ include "spacelift.chart" . }}
{{ include "spacelift.flowsSelectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Flows Selector labels
*/}}
{{- define "spacelift.flowsSelectorLabels" -}}
app.kubernetes.io/name: {{ include "spacelift.flowsName" . }}
app.kubernetes.io/instance: {{ printf "%s-flows" .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use for Flows. It never falls back to
the service account of the Spacelift backend, so Flows does not get its
permissions.
*/}}
{{- define "spacelift.flowsServiceAccountName" -}}
{{- if .Values.flows.serviceAccount.create }}
{{- default (printf "%s-flows" (include "spacelift.fullname" .)) .Values.flows.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.flows.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
The Flows backend image from .Values.flows.image. The tag defaults to the chart
appVersion, because Flows is released together with Spacelift.
*/}}
{{- define "spacelift.flowsImage" -}}
	{{- $image := .Values.flows.image -}}
	{{- $repository := include "spacelift.imageRepository" $image -}}
	{{- if $image.digest -}}
		{{- printf "%s@%s" $repository $image.digest -}}
	{{- else -}}
		{{- printf "%s:%s" $repository ($image.tag | default .Chart.AppVersion) -}}
	{{- end -}}
{{- end -}}
