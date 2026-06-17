{{/*
Hub flavor: single cluster (pool claim or Hive deploy, after metadata validation).
*/}}
{{- define "pipelines.provision.hub" -}}
{{- $params := merge (deepCopy .) (dict
      "clusterName" (printf "%s-%s" .appName .platformName)
      "clusterRole" "hub"
      "namespace" (printf "%s" .pipelineNamespace)
    ) -}}
- name: provision-cluster
  runAfter:
    - validate-pattern-metadata
  taskRef:
    name: provision-cluster
  params:
{{ include "pipelines.provision.cluster.hive.params" $params | nindent 4 }}
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
    - name: install-config
      workspace: shared-data
      subPath: install-config/{{ $params.clusterName }}
{{- end }}

{{- define "pipelines.cleanup.hub" -}}
{{- $params := merge (deepCopy .) (dict
      "clusterName" (printf "%s-%s" .appName .platformName)
      "clusterRole" "hub"
      "namespace" (printf "%s" .pipelineNamespace)
    ) -}}
- name: delete-cluster-if-succeeded
  when:
    - input: $(tasks.status)
      operator: in
      values: ["Completed"]
  taskRef:
    name: delete-cluster
  params:
{{ include "pipelines.provision.cluster.hive.params" $params | nindent 4 }}
{{- end }}
