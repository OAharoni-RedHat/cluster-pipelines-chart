{{/*
Resolve supported flavors for a pattern.
Pattern-level flavors may be a map (single: {}) or a list ([single, multi]).
When unset, defaults.flavors (a list) is converted to the same map shape.
*/}}
{{- define "qeCIPipelines.supportedFlavors" -}}
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
  {{- if kindIs "map" $root.Values.qeCIPipelines.defaults.flavors -}}
    {{- $flavors = $root.Values.qeCIPipelines.defaults.flavors -}}
  {{- else if kindIs "slice" $root.Values.qeCIPipelines.defaults.flavors -}}
    {{- range $root.Values.qeCIPipelines.defaults.flavors -}}
      {{- $_ := set $flavors . (dict) -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- toJson $flavors -}}
{{- end }}

{{/*
TARGET_CLUSTERGROUP for install-pattern / interop-test.

Per-flavor override: qeCIPipelines.patterns.*.flavors.<flavor>.clusterGroup
Global default: qeCIPipelines.defaults.flavors.<flavor>.clusterGroup (map form only)
Fallback: -> hub
*/}}
{{- define "qeCIPipelines.targetClusterGroup" -}}
{{- $flavorName := required "flavorName" .flavorName -}}
{{- $flavorCfg := default dict .flavorCfg -}}
{{- $root := .root -}}
{{- if $flavorCfg.clusterGroup -}}
{{- $flavorCfg.clusterGroup -}}
{{- else -}}
{{- $defaultCfg := dict -}}
{{- with $root.Values.qeCIPipelines.defaults.flavors -}}
{{- if kindIs "map" . -}}
{{- with index . $flavorName -}}
{{- $defaultCfg = . -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- if $defaultCfg.clusterGroup -}}
{{- $defaultCfg.clusterGroup -}}
{{- else -}}
hub
{{- end -}}
{{- end -}}
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
OCP versions for the pipeline matrix.

Priority:
1. pattern ocp_versions (e.g. qeCIPipelines.patterns.mcg.ocp_versions)
2. defaults.ocp_versions
*/}}
{{- define "tekton.supportedOcpVersions" -}}
{{- $root := .root -}}
{{- $app := .app -}}
{{- if $app.ocp_versions -}}
  {{- include "tekton.versionsToMap" $app.ocp_versions -}}
{{- else -}}
  {{- include "tekton.versionsToMap" $root.Values.qeCIPipelines.defaults.ocp_versions -}}
{{- end -}}
{{- end }}

{{/*
Supported platforms for the pipeline matrix.

Sources pattern platforms or defaults.platforms.
*/}}
{{- define "tekton.supportedPlatforms" -}}
{{- $root := .root -}}
{{- $app := .app -}}
{{- $source := dict -}}
{{- if and (kindIs "map" $app.platforms) $app.platforms -}}
  {{- $source = $app.platforms -}}
{{- else -}}
  {{- $source = $root.Values.qeCIPipelines.defaults.platforms -}}
{{- end -}}
{{- $platforms := dict -}}
{{- range $name, $cfg := $source -}}
    {{- $_ := set $platforms $name $cfg -}}
{{- end -}}
{{- toJson $platforms -}}
{{- end }}

{{/*
Platform allowlist for a flavor (list or map of platform names).

Priority:
1. Pattern flavor config: qeCIPipelines.patterns.*.flavors.<flavor>.platforms
2. Default flavor config: qeCIPipelines.defaults.flavors.<flavor>.platforms
3. Empty → no flavor restriction (use all pattern/default platforms)
*/}}
{{- define "qeCIPipelines.flavorPlatformAllowlist" -}}
{{- $root := .root -}}
{{- $flavorName := .flavorName -}}
{{- $flavorCfg := default dict .flavorCfg -}}
{{- $allow := dict -}}
{{- $source := dict -}}
{{- if $flavorCfg.platforms -}}
  {{- $source = $flavorCfg.platforms -}}
{{- else -}}
  {{- with $root.Values.qeCIPipelines.defaults.flavors -}}
    {{- if kindIs "map" . -}}
      {{- with index . $flavorName -}}
        {{- if .platforms -}}
          {{- $source = .platforms -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- if $source -}}
  {{- if kindIs "map" $source -}}
    {{- range $name, $_ := $source -}}
      {{- $_ := set $allow $name true -}}
    {{- end -}}
  {{- else if kindIs "slice" $source -}}
    {{- range $source -}}
      {{- $_ := set $allow . true -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- toJson $allow -}}
{{- end }}

{{/*
Supported platforms for one flavor in the pipeline matrix.

Starts from tekton.supportedPlatforms, then intersects with the flavor
platform allowlist when qeCIPipelines.defaults.flavors.<flavor>.platforms
(or the pattern-level flavor override) is set.
*/}}
{{- define "qeCIPipelines.supportedPlatformsForFlavor" -}}
{{- $base := include "tekton.supportedPlatforms" (dict "root" .root "app" .app) | fromJson -}}
{{- $allow := include "qeCIPipelines.flavorPlatformAllowlist" (dict
      "root" .root
      "flavorName" .flavorName
      "flavorCfg" .flavorCfg
    ) | fromJson -}}
{{- $platforms := dict -}}
{{- if $allow -}}
  {{- range $name, $cfg := $base -}}
    {{- if hasKey $allow $name -}}
      {{- $_ := set $platforms $name $cfg -}}
    {{- end -}}
  {{- end -}}
{{- else -}}
  {{- $platforms = $base -}}
{{- end -}}
{{- toJson $platforms -}}
{{- end }}

{{/*
Kubernetes Secret name from a qeCIPipelines.patterns.*.secrets entry.
*/}}
{{- define "qeCIPipelines.patternSecretName" -}}
{{- if kindIs "string" . -}}
{{- . -}}
{{- else -}}
{{- required "pattern secret must set name" .name -}}
{{- end -}}
{{- end }}

{{/*
Tekton workspace name for a secret (DNS-1123: underscores -> hyphens).
*/}}
{{- define "qeCIPipelines.secretWorkspaceName" -}}
{{- . | replace "_" "-" | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Validate qeCIPipelines.patterns.*.secrets (duplicates and workspace collisions).
*/}}
{{- define "qeCIPipelines.validatePatternSecrets" -}}
{{- $workspaces := dict -}}
{{- range $patternName, $app := .Values.qeCIPipelines.patterns -}}
{{- if $app.secrets -}}
{{- $seen := dict -}}
{{- range $entry := $app.secrets -}}
{{- $secretName := include "qeCIPipelines.patternSecretName" $entry -}}
{{- $wsName := include "qeCIPipelines.secretWorkspaceName" $secretName -}}
{{- if hasKey $seen $wsName -}}
{{- fail (printf "pattern %q lists duplicate secret %q (workspace %q)" $patternName $secretName $wsName) -}}
{{- end -}}
{{- $_ := set $seen $wsName true -}}
{{- if and (hasKey $workspaces $wsName) (ne (index $workspaces $wsName) $secretName) -}}
{{- fail (printf "secrets %q and %q both map to workspace %q" (index $workspaces $wsName) $secretName $wsName) -}}
{{- end -}}
{{- $_ := set $workspaces $wsName $secretName -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Maximum qeCIPipelines.patterns.*.secrets count across all patterns.
*/}}
{{- define "qeCIPipelines.maxPatternSecrets" -}}
{{- $max := 0 -}}
{{- range $_, $app := .Values.qeCIPipelines.patterns -}}
{{- if $app.secrets -}}
{{- $max = max $max (len $app.secrets) -}}
{{- end -}}
{{- end -}}
{{- $max -}}
{{- end }}
