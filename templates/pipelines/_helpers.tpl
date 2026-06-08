{{/*
Resolve supported flavors for a pattern.

Like supportedPlatforms, the result is always a map keyed by flavor name.
Pattern-level flavors may be a map (hub: {}) or a list ([hub, hub-spoke]).
When unset, defaults.flavors (a list) is converted to the same map shape.
*/}}
{{- define "pipelines.supportedFlavors" -}}
{{- $root := .root -}}
{{- $app := .app -}}
{{- $flavors := dict -}}
{{- if $app.flavors -}}
  {{- if kindIs "map" $app.flavors -}}
    {{- $flavors = $app.flavors -}}
  {{- else if kindIs "slice" $app.flavors -}}
    {{- range $app.flavors -}}
      {{- $_ := set $flavors . (dict) -}}
    {{- end -}}
  {{- end -}}
{{- else -}}
  {{- range $root.Values.pipelines.defaults.flavors -}}
    {{- $_ := set $flavors . (dict) -}}
  {{- end -}}
{{- end -}}
{{- toJson $flavors -}}
{{- end }}

{{/*
Convert a version list or map to a map keyed by version string.
*/}}
{{- define "tekton.versionsToMap" -}}
{{- $versions := dict -}}
{{- if kindIs "map" . -}}
  {{- $versions = . -}}
{{- else if kindIs "slice" . -}}
  {{- range . -}}
    {{- $_ := set $versions . (dict) -}}
  {{- end -}}
{{- end -}}
{{- toJson $versions -}}
{{- end }}

{{/*
OCP versions for a pipeline matrix cell.

Priority:
1. clusterpools.<platform>.<profile>.versions (only when clusterpools are defined)
2. defaults.ocp_versions
*/}}
{{- define "tekton.poolVersions" -}}
{{- $root := .root -}}
{{- $platformName := .platformName -}}
{{- $poolProfile := .poolProfile -}}
{{- $clusterpools := default dict $root.Values.pipelines.clusterpools -}}
{{- if and $clusterpools (hasKey $clusterpools $platformName) -}}
  {{- $platformPools := index $clusterpools $platformName -}}
  {{- if and $platformPools (hasKey $platformPools $poolProfile) -}}
    {{- $poolCfg := index $platformPools $poolProfile -}}
    {{- if $poolCfg.versions -}}
      {{- include "tekton.versionsToMap" $poolCfg.versions -}}
    {{- else -}}
      {{- include "tekton.versionsToMap" $root.Values.pipelines.defaults.ocp_versions -}}
    {{- end -}}
  {{- else -}}
    {{- include "tekton.versionsToMap" $root.Values.pipelines.defaults.ocp_versions -}}
  {{- end -}}
{{- else -}}
  {{- include "tekton.versionsToMap" $root.Values.pipelines.defaults.ocp_versions -}}
{{- end -}}
{{- end }}

{{/*
OCP versions for a pattern on a specific platform/pool profile.

Starts from pool versions, then optionally intersects with pattern ocp_versions.
*/}}
{{- define "tekton.supportedOcpVersions" -}}
{{- $root := .root -}}
{{- $app := .app -}}
{{- $platformName := .platformName -}}
{{- $poolProfile := .poolProfile -}}
{{- $poolVersions := include "tekton.poolVersions" (dict "root" $root "platformName" $platformName "poolProfile" $poolProfile) | fromJson -}}
{{- $versions := dict -}}
{{- if $app.ocp_versions -}}
  {{- $filter := include "tekton.versionsToMap" $app.ocp_versions | fromJson -}}
  {{- range $version, $_ := $poolVersions -}}
    {{- if hasKey $filter $version -}}
      {{- $_ := set $versions $version (dict) -}}
    {{- end -}}
  {{- end -}}
{{- else -}}
  {{- $versions = $poolVersions -}}
{{- end -}}
{{- toJson $versions -}}
{{- end }}

{{/*
Resolve sizing profile name (default, beefy, metal, ...).

Used for labels and cluster-pool naming when pools are enabled.
Priority:
1. app.platforms.<platform>.clusterPool
2. app.clusterPool
3. defaults.platforms.<platform>.defaultClusterPool
*/}}
{{- define "tekton.poolProfile" -}}
{{- $root := .root -}}
{{- $app := .app -}}
{{- $platformName := .platformName -}}
{{- $platform := index $root.Values.pipelines.defaults.platforms $platformName -}}
{{- if and $app.platforms (hasKey $app.platforms $platformName) -}}
  {{- $platformCfg := index $app.platforms $platformName -}}
  {{- if $platformCfg.clusterPool -}}
    {{- $platformCfg.clusterPool -}}
  {{- else if $app.clusterPool -}}
    {{- $app.clusterPool -}}
  {{- else -}}
    {{- $platform.defaultClusterPool -}}
  {{- end -}}
{{- else if $app.clusterPool -}}
  {{- $app.clusterPool -}}
{{- else -}}
  {{- $platform.defaultClusterPool -}}
{{- end -}}
{{- end }}

{{/*
Full ClusterPool resource name: <platform>-<profile>-<version-with-dots-as-dashes>
*/}}
{{- define "tekton.clusterPoolName" -}}
{{- printf "%s-%s-%s" .platformName .poolProfile (.version | replace "." "-") -}}
{{- end }}

{{/*
Install-config / ClusterPool secret name for a pool profile (version-independent).
*/}}
{{- define "tekton.installConfigSecretName" -}}
{{- printf "%s-%s-install-config" .platformName .poolProfile -}}
{{- end }}

{{/*
ClusterImageSet name for a short OCP version.
*/}}
{{- define "tekton.imageSetRef" -}}
{{- $root := .root -}}
{{- $version := .version -}}
{{- $imageSets := default dict $root.Values.pipelines.imageSets -}}
{{- if hasKey $imageSets $version -}}
  {{- index $imageSets $version -}}
{{- else -}}
  {{- printf "img%s.0-x86-64-appsub" $version -}}
{{- end -}}
{{- end }}

{{/*
Platform defaults (region, baseDomain, ...) merged with optional pool profile overrides.
*/}}
{{- define "tekton.platformSettings" -}}
{{- $root := .root -}}
{{- $platformName := .platformName -}}
{{- $poolCfg := .poolCfg -}}
{{- $defaults := index $root.Values.pipelines.defaults.platforms $platformName -}}
{{- $settings := dict -}}
{{- $_ := set $settings "region" (default $defaults.region $poolCfg.region) -}}
{{- $_ := set $settings "baseDomain" (default $defaults.baseDomain $poolCfg.baseDomain) -}}
{{- $_ := set $settings "credentialsSecret" (printf "%s-creds" $platformName) -}}
{{- toJson $settings -}}
{{- end }}

{{/*
Supported platforms for the pipeline matrix.

Sources pattern platforms or defaults.platforms. When requireClusterPools is
true, intersects with clusterpools keys (legacy gate for pool-backed testing).
*/}}
{{- define "tekton.supportedPlatforms" -}}
{{- $root := .root -}}
{{- $app := .app -}}
{{- $source := dict -}}
{{- if and (kindIs "map" $app.platforms) $app.platforms -}}
  {{- $source = $app.platforms -}}
{{- else -}}
  {{- $source = $root.Values.pipelines.defaults.platforms -}}
{{- end -}}
{{- $requirePools := default false $root.Values.pipelines.requireClusterPools -}}
{{- $clusterpools := default dict $root.Values.pipelines.clusterpools -}}
{{- $platforms := dict -}}
{{- range $name, $cfg := $source -}}
  {{- if and $requirePools (not (hasKey $clusterpools $name)) -}}
  {{- else -}}
    {{- $_ := set $platforms $name $cfg -}}
  {{- end -}}
{{- end -}}
{{- toJson $platforms -}}
{{- end }}

{{/*
install-config.yaml body for a pool profile (platform-specific machine stanzas).
*/}}
{{- define "tekton.installConfigYaml" -}}
{{- $platformName := .platformName -}}
{{- $poolCfg := .poolCfg -}}
{{- $settings := .settings | fromJson -}}
{{- $networking := .root.Values.pipelines.defaults.networking -}}
{{- $cp := $poolCfg.control_plane -}}
{{- $compute := $poolCfg.compute -}}
apiVersion: v1
baseDomain: {{ $settings.baseDomain }}
controlPlane:
  architecture: amd64
  hyperthreading: Enabled
  name: master
  replicas: {{ $cp.replica }}
  platform:
    {{ $platformName }}:
      type: {{ $cp.size }}
      {{- if eq $platformName "aws" }}
      rootVolume:
        size: 200
        type: gp3
      {{- end }}
compute:
- architecture: amd64
  hyperthreading: Enabled
  name: worker
  replicas: {{ $compute.replica }}
  platform:
    {{ $platformName }}:
      type: {{ $compute.size }}
      {{- if eq $platformName "aws" }}
      rootVolume:
        size: 200
        type: gp3
      {{- end }}
networking:
  networkType: {{ $networking.networkType }}
  clusterNetwork:
  {{- range $networking.clusterNetwork }}
  - cidr: {{ .cidr }}
    hostPrefix: {{ .hostPrefix }}
  {{- end }}
  machineNetwork:
  {{- range $networking.machineNetwork }}
  - cidr: {{ .cidr }}
  {{- end }}
  serviceNetwork:
  {{- range $networking.serviceNetwork }}
  - {{ . }}
  {{- end }}
platform:
  {{ $platformName }}:
    region: {{ $settings.region }}
pullSecret: ""
{{- end }}
