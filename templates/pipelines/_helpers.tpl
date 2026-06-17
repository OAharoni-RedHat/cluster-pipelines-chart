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
