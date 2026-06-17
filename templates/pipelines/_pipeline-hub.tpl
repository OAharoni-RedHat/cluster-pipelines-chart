{{/*
Hub flavor: single cluster (pool claim or Hive deploy, after metadata validation).
*/}}
{{- define "pipelines.provision.hub" -}}
{{- $params := merge (deepCopy .) (dict
      "clusterName" (printf "%s-%s" .appName .platformName)
      "clusterRole" "hub"
    ) -}}
- name: provision-cluster
  runAfter:
    - validate-pattern-metadata
  taskRef:
    name: provision-cluster
  params:
{{ include "pipelines.provision.cluster.hive.params" $params | nindent 4 }}
    - name: control-plane-config
      value: $(tasks.validate-pattern-metadata.results.hub-control-plane[*])
    - name: compute-nodes-config
      value: $(tasks.validate-pattern-metadata.results.hub-compute-nodes[*])
  workspaces:
    - name: kubeconfig
      workspace: shared-data
      subPath: kubeconfig
{{- end }}

{{- define "pipelines.cleanup.hub" -}}
{{- $params := merge (deepCopy .) (dict
      "clusterName" (printf "%s-%s" .appName .platformName)
      "clusterRole" "hub"
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
