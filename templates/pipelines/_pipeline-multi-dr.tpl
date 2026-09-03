{{/*
Multi-DR cluster flavor: hub + spoke-primary + spoke-secondary, provisioned in parallel.
Each cluster receives non-overlapping CIDRs to support Submariner and ODF multicluster replication.
*/}}
{{- define "qeCIPipelines.provision.multi-dr" -}}
{{- $hubParams := merge (deepCopy .) (dict
      "clusterBaseName" (printf "%s" .patternName)
      "clusterRole" "hub"
      "namespace" (printf "%s" .pipelineNamespace)
    ) -}}
{{- $spokePrimaryParams := merge (deepCopy .) (dict
      "clusterBaseName" (printf "%s" .patternName)
      "clusterRole" "pri"
      "namespace" (printf "%s" .pipelineNamespace)
    ) -}}
{{- $spokeSecondaryParams := merge (deepCopy .) (dict
      "clusterBaseName" (printf "%s" .patternName)
      "clusterRole" "sec"
      "namespace" (printf "%s" .pipelineNamespace)
    ) -}}
{{- $patternNet := default dict .app.networking -}}
{{- $hubNet := default dict $patternNet.hub -}}
{{- $spokePrimaryNet := default dict $patternNet.spokePrimary -}}
{{- $spokeSecondaryNet := default dict $patternNet.spokeSecondary -}}
- name: provision-hub
  runAfter:
    - validate-pattern-metadata
  retries: 3
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
    - name: cluster-network-cidr
      value: {{ $hubNet.clusterNetworkCidr | quote }}
    - name: cluster-host-prefix
      value: {{ $hubNet.clusterHostPrefix | quote }}
    - name: machine-network-cidr
      value: {{ $hubNet.machineNetworkCidr | quote }}
    - name: service-network-cidr
      value: {{ $hubNet.serviceNetworkCidr | quote }}
  workspaces:
    - name: kubeconfig
      workspace: shared-data
      subPath: kubeconfig
    - name: install-config
      workspace: shared-data
      subPath: install-config/{{ $hubParams.clusterBaseName }}-hub
- name: provision-spoke-primary
  runAfter:
    - validate-pattern-metadata
  retries: 3
  timeout: {{ default "2h" .root.Values.qeCIPipelines.defaults.provisionTaskTimeout | quote }}
  taskRef:
    name: provision-cluster
  params:
{{ include "qeCIPipelines.provision.cluster.hive.params" $spokePrimaryParams | nindent 4 }}
    - name: ocp-version
      value: {{ .ocpVersion | quote }}
    - name: control-plane-config
      value: $(tasks.validate-pattern-metadata.results.spoke-control-plane[*])
    - name: compute-nodes-config
      value: $(tasks.validate-pattern-metadata.results.spoke-compute-nodes[*])
    - name: cluster-network-cidr
      value: {{ $spokePrimaryNet.clusterNetworkCidr | quote }}
    - name: cluster-host-prefix
      value: {{ $spokePrimaryNet.clusterHostPrefix | quote }}
    - name: machine-network-cidr
      value: {{ $spokePrimaryNet.machineNetworkCidr | quote }}
    - name: service-network-cidr
      value: {{ $spokePrimaryNet.serviceNetworkCidr | quote }}
    - name: region
      value: {{ default "" ((.app.platforms).aws).spokePrimaryRegion | quote }}
    - name: skip-acm-auto-import
      value: "true"
  workspaces:
    - name: kubeconfig
      workspace: shared-data
      subPath: kubeconfig
    - name: install-config
      workspace: shared-data
      subPath: install-config/{{ $spokePrimaryParams.clusterBaseName }}-spoke-primary
- name: provision-spoke-secondary
  runAfter:
    - validate-pattern-metadata
  retries: 3
  timeout: {{ default "2h" .root.Values.qeCIPipelines.defaults.provisionTaskTimeout | quote }}
  taskRef:
    name: provision-cluster
  params:
{{ include "qeCIPipelines.provision.cluster.hive.params" $spokeSecondaryParams | nindent 4 }}
    - name: ocp-version
      value: {{ .ocpVersion | quote }}
    - name: control-plane-config
      value: $(tasks.validate-pattern-metadata.results.spoke-control-plane[*])
    - name: compute-nodes-config
      value: $(tasks.validate-pattern-metadata.results.spoke-compute-nodes[*])
    - name: cluster-network-cidr
      value: {{ $spokeSecondaryNet.clusterNetworkCidr | quote }}
    - name: cluster-host-prefix
      value: {{ $spokeSecondaryNet.clusterHostPrefix | quote }}
    - name: machine-network-cidr
      value: {{ $spokeSecondaryNet.machineNetworkCidr | quote }}
    - name: service-network-cidr
      value: {{ $spokeSecondaryNet.serviceNetworkCidr | quote }}
    - name: region
      value: {{ default "" ((.app.platforms).aws).spokeSecondaryRegion | quote }}
    - name: skip-acm-auto-import
      value: "true"
  workspaces:
    - name: kubeconfig
      workspace: shared-data
      subPath: kubeconfig
    - name: install-config
      workspace: shared-data
      subPath: install-config/{{ $spokeSecondaryParams.clusterBaseName }}-spoke-secondary
{{- end }}

{{- define "qeCIPipelines.cleanup.multi-dr" -}}
- name: delete-spoke-secondary-if-succeeded
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
      value: $(tasks.provision-spoke-secondary.results.cluster-name)
- name: delete-spoke-primary-if-succeeded
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
      value: $(tasks.provision-spoke-primary.results.cluster-name)
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
