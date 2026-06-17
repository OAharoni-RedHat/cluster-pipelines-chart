{{- define "pipelines.provision.cluster.hive.params" -}}
- name: cluster-name
  value: {{ .clusterName | quote }}
- name: application
  value: {{ .appName | quote }}
- name: platform
  value: {{ .platformName | quote }}
- name: namespace
  value: {{ .namespace | quote }}
- name: cluster-role
  value: {{ .clusterRole | quote }}
{{- end }}
