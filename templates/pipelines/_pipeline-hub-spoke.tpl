{{/*
Hub-spoke flavor: hub and spoke provision in parallel (pool claim or Hive deploy).
*/}}
{{- define "pipelines.provision.hub-spoke" -}}
{{- $hubParams := merge (deepCopy .) (dict
      "clusterBaseName" (printf "%s" .patternName)
      "clusterRole" "hub"
      "namespace" (printf "%s" .pipelineNamespace)
    ) -}}
{{- $spokeParams := merge (deepCopy .) (dict
      "clusterBaseName" (printf "%s" .patternName)
      "clusterRole" "spoke"
      "namespace" (printf "%s" .pipelineNamespace)
    ) -}}
- name: provision-hub
  runAfter:
    - validate-pattern-metadata
  taskRef:
    name: provision-cluster
  params:
{{ include "pipelines.provision.cluster.hive.params" $hubParams | nindent 4 }}
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
      subPath: install-config/{{ $hubParams.clusterBaseName }}-hub
- name: provision-spoke
  runAfter:
    - validate-pattern-metadata
  taskRef:
    name: provision-cluster
  params:
{{ include "pipelines.provision.cluster.hive.params" $spokeParams | nindent 4 }}
    - name: ocp-version
      value: {{ .ocpVersion | quote }}
    - name: control-plane-config
      value: $(tasks.validate-pattern-metadata.results.spoke-control-plane[*])
    - name: compute-nodes-config
      value: $(tasks.validate-pattern-metadata.results.spoke-compute-nodes[*])
  workspaces:
    - name: kubeconfig
      workspace: shared-data
      subPath: spoke-kubeconfig
    - name: install-config
      workspace: shared-data
      subPath: install-config/{{ $spokeParams.clusterBaseName }}-spoke
{{- end }}

{{- define "pipelines.cleanup.hub-spoke" -}}
{{- $hubParams := merge (deepCopy .) (dict
      "clusterBaseName" (printf "%s" .patternName)
      "clusterRole" "hub"
      "namespace" (printf "%s" .pipelineNamespace)
    ) -}}
{{- $spokeParams := merge (deepCopy .) (dict
      "clusterBaseName" (printf "%s" .patternName)
      "clusterRole" "spoke"
      "namespace" (printf "%s" .pipelineNamespace)
    ) -}}
- name: delete-spoke-if-succeeded
  when:
    - input: $(tasks.status)
      operator: in
      values: ["Completed"]
  taskRef:
    name: delete-cluster
  params:
{{ include "pipelines.provision.cluster.hive.params" $spokeParams | nindent 4 }}
- name: delete-hub-if-succeeded
  when:
    - input: $(tasks.status)
      operator: in
      values: ["Completed"]
  taskRef:
    name: delete-cluster
  params:
{{ include "pipelines.provision.cluster.hive.params" $hubParams | nindent 4 }}
{{- end }}
