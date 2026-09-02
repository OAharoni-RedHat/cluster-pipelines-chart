{{- define "qeCIPipelines.provision.cluster.hive.params" -}}
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
- name: cluster-name-postfix
  value: $(params.cluster-name-postfix)
- name: pipelinerun-name
  value: $(context.pipelineRun.name)
- name: pipeline-name
  value: $(context.pipeline.name)
- name: pipelinerun-uid
  value: $(context.pipelineRun.uid)

{{- end }}
