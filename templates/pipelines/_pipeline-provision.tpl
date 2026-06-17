
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
- name: namespace
  value: {{ .clusterClaimNamespace | quote }}
- name: cluster-role
  value: {{ .clusterRole | quote }}
- name: ocp-version
  value: {{ .ocpVersion | quote }}
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

