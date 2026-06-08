{{/*
Hub flavor: single cluster (pool claim or Hive deploy, after metadata validation).
*/}}
{{- define "pipelines.provision.hub" -}}
{{- $params := merge (deepCopy .) (dict
      "clusterName" (printf "%s-%s" .appName .platformName)
      "clusterRole" "hub"
    ) -}}
- name: provision-from-pool
  runAfter:
    - resolve-pattern-sizing
  when:
    - input: "$(params.useClusterPool)"
      operator: in
      values: ["true"]
  taskRef:
    name: create-clusterclaim-with-kubeconfig
  params:
{{ include "pipelines.provision.cluster.pool.params" $params | nindent 4 }}
  workspaces:
    - name: kubeconfig
      workspace: shared-data
      subPath: kubeconfig
- name: provision-from-hive
  runAfter:
    - resolve-pattern-sizing
  when:
    - input: "$(params.useClusterPool)"
      operator: in
      values: ["false"]
  taskRef:
    name: create-hive-cluster
  params:
{{ include "pipelines.provision.cluster.hive.params" $params | nindent 4 }}
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
- name: delete-from-pool-if-succeeded
  when:
    - input: $(tasks.status)
      operator: in
      values: ["Completed"]
    - input: "$(params.useClusterPool)"
      operator: in
      values: ["true"]
  taskRef:
    name: delete-cluster-claim
  params:
{{ include "pipelines.cleanup.cluster.pool.params" $params | nindent 4 }}
- name: delete-from-hive-if-succeeded
  when:
    - input: $(tasks.status)
      operator: in
      values: ["Completed"]
    - input: "$(params.useClusterPool)"
      operator: in
      values: ["false"]
  taskRef:
    name: delete-hive-cluster
  params:
{{ include "pipelines.cleanup.cluster.hive.params" $params | nindent 4 }}
{{- end }}
