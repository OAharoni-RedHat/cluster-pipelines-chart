{{- define "pipelines.provision.cluster.hive.params" -}}
- name: cluster-base-name
  value: {{ .clusterBaseName | quote }}
- name: platform
  value: {{ .platformName | quote }}
- name: namespace
  value: {{ .namespace | quote }}
- name: cluster-role
  value: {{ .clusterRole | quote }}
- name: flavor
  value: {{ .flavorName | quote }}

{{- end }}
