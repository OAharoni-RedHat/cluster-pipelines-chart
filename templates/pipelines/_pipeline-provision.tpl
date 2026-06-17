{{/*
ClusterPool claim provision params (baked at render time).
Expects: clusterPool, clusterClaimName, clusterClaimNamespace, waitTimeoutMinutes
*/}}
{{- define "pipelines.provision.cluster.pool.params" -}}
- name: clusterpool
  value: {{ .clusterPool | quote }}
- name: clusterclaimname
  value: {{ .clusterClaimName | quote }}
- name: clusterclaimnamespace
  value: {{ .clusterClaimNamespace | quote }}
- name: wait-timeout-minutes
  value: {{ .waitTimeoutMinutes | quote }}
{{- end }}

{{/*
Direct Hive deploy provision params (baked at render time).
*/}}
{{- define "pipelines.provision.cluster.hive.params" -}}
- name: cluster-name
  value: {{ .clusterName | quote }}
- name: application
  value: {{ .appName | quote }}
- name: platform
  value: {{ .platformName | quote }}
- name: ocp-version
  value: {{ .ocpVersion | quote }}
- name: namespace
  value: {{ .clusterClaimNamespace | quote }}
- name: cluster-role
  value: {{ .clusterRole | quote }}
{{- end }}

{{/*
ClusterPool claim cleanup params (baked at render time).
*/}}
{{- define "pipelines.cleanup.cluster.pool.params" -}}
- name: clusterClaimName
  value: {{ .clusterClaimName | quote }}
- name: clusterClaimNamespace
  value: {{ .clusterClaimNamespace | quote }}
{{- end }}

{{/*
Direct Hive deploy cleanup params (baked at render time).
*/}}
{{- define "pipelines.cleanup.cluster.hive.params" -}}
- name: cluster-name
  value: {{ .clusterName | quote }}
- name: application
  value: {{ .appName | quote }}
- name: platform
  value: {{ .platformName | quote }}
- name: namespace
  value: {{ .clusterClaimNamespace | quote }}
- name: cluster-role
  value: {{ .clusterRole | quote }}
{{- end }}

{{/*
All params for provision-cluster wrapper task (pool + hive paths).
*/}}
{{- define "pipelines.provision.cluster.wrapper.params" -}}
- name: useClusterPool
  value: $(params.useClusterPool)
{{ include "pipelines.provision.cluster.pool.params" . }}
{{ include "pipelines.provision.cluster.hive.params" . }}
{{- end }}

{{/*
All params for delete-cluster wrapper task (pool + hive paths).
*/}}
{{- define "pipelines.cleanup.cluster.wrapper.params" -}}
- name: useClusterPool
  value: $(params.useClusterPool)
{{ include "pipelines.cleanup.cluster.pool.params" . }}
{{ include "pipelines.cleanup.cluster.hive.params" . }}
{{- end }}
