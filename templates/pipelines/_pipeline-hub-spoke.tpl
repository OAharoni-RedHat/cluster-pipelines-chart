{{/*
Hub-spoke flavor: hub + spoke (pool claim or Hive deploy, after metadata validation).
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
- name: provision-hub-from-pool
  runAfter:
    - resolve-pattern-sizing
  when:
    - input: "$(params.useClusterPool)"
      operator: in
      values: ["true"]
  taskRef:
    name: create-clusterclaim-with-kubeconfig
  params:
{{ include "pipelines.provision.cluster.pool.params" $hubParams | nindent 4 }}
  workspaces:
    - name: kubeconfig
      workspace: shared-data
      subPath: kubeconfig
- name: provision-hub-from-hive
  runAfter:
    - resolve-pattern-sizing
  when:
    - input: "$(params.useClusterPool)"
      operator: in
      values: ["false"]
  taskRef:
    name: create-hive-cluster
  params:
{{ include "pipelines.provision.cluster.hive.params" $hubParams | nindent 4 }}
  workspaces:
    - name: kubeconfig
      workspace: shared-data
      subPath: kubeconfig
- name: provision-spoke-from-pool
  runAfter:
    - provision-hub-from-pool
    - provision-hub-from-hive
  when:
    - input: "$(params.useClusterPool)"
      operator: in
      values: ["true"]
  taskRef:
    name: create-clusterclaim-with-kubeconfig
  params:
{{ include "pipelines.provision.cluster.pool.params" $spokeParams | nindent 4 }}
  workspaces:
    - name: kubeconfig
      workspace: shared-data
      subPath: spoke-kubeconfig
- name: provision-spoke-from-hive
  runAfter:
    - provision-hub-from-pool
    - provision-hub-from-hive
  when:
    - input: "$(params.useClusterPool)"
      operator: in
      values: ["false"]
  taskRef:
    name: create-hive-cluster
  params:
{{ include "pipelines.provision.cluster.hive.params" $spokeParams | nindent 4 }}
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
- name: delete-spoke-from-pool-if-succeeded
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
{{ include "pipelines.cleanup.cluster.pool.params" $spokeParams | nindent 4 }}
- name: delete-spoke-from-hive-if-succeeded
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
{{ include "pipelines.cleanup.cluster.hive.params" $spokeParams | nindent 4 }}
- name: delete-hub-from-pool-if-succeeded
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
{{ include "pipelines.cleanup.cluster.pool.params" $hubParams | nindent 4 }}
- name: delete-hub-from-hive-if-succeeded
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
{{ include "pipelines.cleanup.cluster.hive.params" $hubParams | nindent 4 }}
{{- end }}
