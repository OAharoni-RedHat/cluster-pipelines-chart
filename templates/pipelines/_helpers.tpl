{{/*
Resolve supported flavors for a pattern.
Pattern-level flavors may be a map (single: {}) or a list ([single, multi]).
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
  {{- if kindIs "map" $root.Values.pipelines.defaults.flavors -}}
    {{- $flavors = $root.Values.pipelines.defaults.flavors -}}
  {{- else if kindIs "slice" $root.Values.pipelines.defaults.flavors -}}
    {{- range $root.Values.pipelines.defaults.flavors -}}
      {{- $_ := set $flavors . (dict) -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- toJson $flavors -}}
{{- end }}

{{/*
TARGET_CLUSTERGROUP for install-pattern / interop-test.

Per-flavor override: pipelines.patterns.*.flavors.<flavor>.clusterGroup
Global default: pipelines.defaults.flavors.<flavor>.clusterGroup (map form only)
Fallback: -> hub
*/}}
{{- define "pipelines.targetClusterGroup" -}}
{{- $flavorName := required "flavorName" .flavorName -}}
{{- $flavorCfg := default dict .flavorCfg -}}
{{- $root := .root -}}
{{- if $flavorCfg.clusterGroup -}}
{{- $flavorCfg.clusterGroup -}}
{{- else -}}
{{- $defaultCfg := dict -}}
{{- with $root.Values.pipelines.defaults.flavors -}}
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
1. pattern ocp_versions (e.g. pipelines.patterns.mcg.ocp_versions)
2. defaults.ocp_versions
*/}}
{{- define "tekton.supportedOcpVersions" -}}
{{- $root := .root -}}
{{- $app := .app -}}
{{- if $app.ocp_versions -}}
  {{- include "tekton.versionsToMap" $app.ocp_versions -}}
{{- else -}}
  {{- include "tekton.versionsToMap" $root.Values.pipelines.defaults.ocp_versions -}}
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
  {{- $source = $root.Values.pipelines.defaults.platforms -}}
{{- end -}}
{{- $platforms := dict -}}
{{- range $name, $cfg := $source -}}
    {{- $_ := set $platforms $name $cfg -}}
{{- end -}}
{{- toJson $platforms -}}
{{- end }}

{{/*
Kubernetes Secret name from a pipelines.patterns.*.secrets entry.
*/}}
{{- define "pipelines.patternSecretName" -}}
{{- if kindIs "string" . -}}
{{- . -}}
{{- else -}}
{{- required "pattern secret must set name" .name -}}
{{- end -}}
{{- end }}

{{/*
Tekton workspace name for a secret (DNS-1123: underscores -> hyphens).
*/}}
{{- define "pipelines.secretWorkspaceName" -}}
{{- . | replace "_" "-" | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Validate pipelines.patterns.*.secrets (duplicates and workspace collisions).
*/}}
{{- define "pipelines.validatePatternSecrets" -}}
{{- $workspaces := dict -}}
{{- range $patternName, $app := .Values.pipelines.patterns -}}
{{- if $app.secrets -}}
{{- $seen := dict -}}
{{- range $entry := $app.secrets -}}
{{- $secretName := include "pipelines.patternSecretName" $entry -}}
{{- $wsName := include "pipelines.secretWorkspaceName" $secretName -}}
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
Maximum pipelines.patterns.*.secrets count across all patterns.
*/}}
{{- define "pipelines.maxPatternSecrets" -}}
{{- $max := 0 -}}
{{- range $_, $app := .Values.pipelines.patterns -}}
{{- if $app.secrets -}}
{{- $max = max $max (len $app.secrets) -}}
{{- end -}}
{{- end -}}
{{- $max -}}
{{- end }}
