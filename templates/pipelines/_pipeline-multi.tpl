{{/*
Multi cluster flavor: hub and spoke provision in parallel (pool claim or Hive deploy).
*/}}
{{- define "qeCIPipelines.provision.multi" -}}
{{- $hubParams := merge (deepCopy .) (dict
      "clusterBaseName" (printf "%s" .patternName)
      "clusterRole" "hub"
      "namespace" (printf "%s" .namespace)
    ) -}}
{{- $spokeParams := merge (deepCopy .) (dict
      "clusterBaseName" (printf "%s" .patternName)
      "clusterRole" "spoke"
      "namespace" (printf "%s" .namespace)
    ) -}}
- name: provision-hub
  runAfter:
    - validate-pattern-metadata
  timeout: {{ default "2h" .root.Values.qeCIPipelines.defaults.provisionTaskTimeout | quote }}
  taskRef:
    name: provision-cluster
  params:
{{ include "qeCIPipelines.provision.cluster.hive.params" $hubParams | nindent 4 }}
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
  timeout: {{ default "2h" .root.Values.qeCIPipelines.defaults.provisionTaskTimeout | quote }}
  taskRef:
    name: provision-cluster
  params:
{{ include "qeCIPipelines.provision.cluster.hive.params" $spokeParams | nindent 4 }}
    - name: ocp-version
      value: {{ .ocpVersion | quote }}
    - name: control-plane-config
      value: $(tasks.validate-pattern-metadata.results.spoke-control-plane[*])
    - name: compute-nodes-config
      value: $(tasks.validate-pattern-metadata.results.spoke-compute-nodes[*])
  workspaces:
    - name: kubeconfig
      workspace: shared-data
      subPath: kubeconfig
    - name: install-config
      workspace: shared-data
      subPath: install-config/{{ $spokeParams.clusterBaseName }}-spoke
{{- end }}

{{- define "qeCIPipelines.cleanup.multi" -}}
- name: delete-spoke-if-succeeded
  when:
    - input: $(tasks.status)
      operator: in
      values: ["Completed"]
    - input: "$(params.force-skip-cleanup)"
      operator: in
      values: ["false"]
  taskRef:
    name: delete-cluster
  params:
    - name: cluster-name
      value: $(tasks.provision-spoke.results.cluster-name)
- name: delete-hub-if-succeeded
  when:
    - input: $(tasks.status)
      operator: in
      values: ["Completed"]
    - input: "$(params.force-skip-cleanup)"
      operator: in
      values: ["false"]
  taskRef:
    name: delete-cluster
  params:
    - name: cluster-name
      value: $(tasks.provision-hub.results.cluster-name)
{{- end }}
