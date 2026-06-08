{{/*
Single cluster flavor: single cluster Hive deploy, after metadata validation.
*/}}
{{- define "qeCIPipelines.provision.single" -}}
{{- $params := merge (deepCopy .) (dict
      "clusterBaseName" (printf "%s" .patternName )
      "clusterRole" "hub"
      "namespace" (printf "%s" .pipelineNamespace)
    ) -}}
- name: provision-cluster
  runAfter:
    - validate-pattern-metadata
  timeout: {{ default "2h" .root.Values.qeCIPipelines.defaults.provisionTaskTimeout | quote }}
  taskRef:
    name: provision-cluster
  params:
{{ include "qeCIPipelines.provision.cluster.hive.params" $params | nindent 4 }}
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
      subPath: install-config/{{ $params.clusterBaseName }}-hub
{{- end }}

{{- define "qeCIPipelines.cleanup.single" -}}
- name: delete-cluster-if-succeeded
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
     value: $(tasks.provision-cluster.results.cluster-name)
{{- end }}

