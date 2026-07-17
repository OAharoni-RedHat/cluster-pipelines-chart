{{/*
Hosted cluster flavor: HyperShift hosted cluster (after metadata validation).
*/}}
{{- define "pipelines.provision.hosted" -}}
- name: provision-hosted-cluster
  runAfter:
    - validate-pattern-metadata
  timeout: {{ default "2h" .root.Values.pipelines.defaults.provisionTaskTimeout | quote }}
  taskRef:
    name: provision-hosted-cluster
  params:
    - name: application
      value: {{ .patternName | quote }}
    - name: platform
      value: {{ .platformName | quote }}
    - name: ocpVersion
      value: {{ .ocpVersion | quote }}
  workspaces:
    - name: kubeconfig
      workspace: shared-data
      subPath: kubeconfig
{{- end }}

{{- define "pipelines.cleanup.hosted" -}}
- name: destroy-hosted-cluster-if-succeeded
  when:
    - input: $(tasks.status)
      operator: in
      values: ["Completed"]
  taskRef:
    name: destroy-hosted-cluster
  params:
    - name: application
      value: {{ .patternName | quote }}
{{- end }}
