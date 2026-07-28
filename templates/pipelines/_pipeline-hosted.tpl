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
    - name: cluster-base-name
      value: {{ .patternName | quote }}
    - name: platform
      value: {{ .platformName | quote }}
    - name: namespace
      value: {{ .pipelineNamespace | quote }}
    - name: cluster-role
      value: "hub"
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
    - name: ocp-version
      value: {{ .ocpVersion | quote }}
    - name: control-plane-config
      value: $(tasks.validate-pattern-metadata.results.hub-control-plane[*])
    - name: compute-nodes-config
      value: $(tasks.validate-pattern-metadata.results.hub-compute-nodes[*])
  workspaces:
    - name: kubeconfig
      workspace: shared-data
      subPath: kubeconfig
    - name: creds
      workspace: shared-data
      subPath: creds

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
