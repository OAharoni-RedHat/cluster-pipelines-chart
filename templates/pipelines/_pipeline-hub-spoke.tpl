{{/*
Hub-spoke flavor: hub and spoke provision in parallel (pool claim or Hive deploy).
*/}}
{{- define "pipelines.provision.hub-spoke" -}}
{{- $hubParams := merge (deepCopy .) (dict
      "clusterName" (printf "%s-%s" .appName .platformName)
      "clusterRole" "hub"
    ) -}}
{{- $spokeParams := merge (deepCopy .) (dict
      "clusterClaimName" (printf "%s-%s-spoke-claim" .appName .platformName)
      "clusterName" (printf "%s-%s-spoke" .appName .platformName)
      "clusterRole" "spoke"
    ) -}}
- name: provision-hub
  runAfter:
    - validate-pattern-metadata
  taskRef:
    name: provision-cluster
  params:
{{ include "pipelines.provision.cluster.hive.params" $hubParams | nindent 4 }}
    - name: control-plane-config
      value: $(tasks.validate-pattern-metadata.results.hub-control-plane[*])
    - name: compute-nodes-config
      value: $(tasks.validate-pattern-metadata.results.hub-compute-nodes[*])
  workspaces:
    - name: kubeconfig
      workspace: shared-data
      subPath: kubeconfig
- name: provision-spoke
  runAfter:
    - validate-pattern-metadata
  taskRef:
    name: provision-cluster
  params:
{{ include "pipelines.provision.cluster.hive.params" $spokeParams | nindent 4 }}
    - name: control-plane-config
      value: $(tasks.validate-pattern-metadata.results.spoke-control-plane[*])
    - name: compute-nodes-config
      value: $(tasks.validate-pattern-metadata.results.spoke-compute-nodes[*])
  workspaces:
    - name: kubeconfig
      workspace: shared-data
      subPath: spoke-kubeconfig
{{- end }}

{{- define "pipelines.cleanup.hub-spoke" -}}
{{- $hubParams := merge (deepCopy .) (dict
      "clusterName" (printf "%s-%s" .appName .platformName)
      "clusterRole" "hub"
    ) -}}
{{- $spokeParams := merge (deepCopy .) (dict
      "clusterClaimName" (printf "%s-%s-spoke-claim" .appName .platformName)
      "clusterName" (printf "%s-%s-spoke" .appName .platformName)
      "clusterRole" "spoke"
    ) -}}
- name: delete-spoke-if-succeeded
  when:
    - input: $(tasks.status)
      operator: in
      values: ["Completed"]
  taskRef:
    name: delete-cluster
  params:
{{ include "pipelines.cleanup.cluster.hive.params" $spokeParams | nindent 4 }}
- name: delete-hub-if-succeeded
  when:
    - input: $(tasks.status)
      operator: in
      values: ["Completed"]
  taskRef:
    name: delete-cluster
  params:
{{ include "pipelines.cleanup.cluster.hive.params" $hubParams | nindent 4 }}
{{- end }}
