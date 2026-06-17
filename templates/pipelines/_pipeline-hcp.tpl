{{/*
HCP flavor: HyperShift hosted cluster (after metadata validation).
*/}}
{{- define "pipelines.provision.hcp" -}}
- name: provision-hosted-cluster
  runAfter:
    - validate-pattern-metadata
  taskRef:
    name: provision-hosted-cluster
  params:
    - name: application
      value: {{ .appName | quote }}
    - name: platform
      value: {{ .platformName | quote }}
    - name: ocpVersion
      value: {{ .ocpVersion | quote }}
  workspaces:
    - name: kubeconfig
      workspace: shared-data
      subPath: kubeconfig
{{- end }}

{{- define "pipelines.cleanup.hcp" -}}
- name: destroy-hosted-cluster-if-succeeded
  when:
    - input: $(tasks.status)
      operator: in
      values: ["Completed"]
  taskRef:
    name: destroy-hosted-cluster
  params:
    - name: application
      value: {{ .appName | quote }}
{{- end }}
