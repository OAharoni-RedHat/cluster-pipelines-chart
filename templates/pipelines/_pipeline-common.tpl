{{/*
Checkout, metadata validation, and sizing (always first).
*/}}
{{- define "qeCIPipelines.tasks.setup" -}}
- name: checkout-pattern-repo
  taskRef:
    kind: Task
    name: clone-git-repo
  workspaces:
    - name: output-repo
      workspace: shared-data
  params:
    - name: URL
      value: $(params.pattern-repo-url)
    - name: REVISION
      value: $(params.pattern-repo-revision)
- name: validate-pattern-metadata
  runAfter:
    - checkout-pattern-repo
  taskRef:
    kind: Task
    name: validate-pattern-metadata
  params:
    - name: platform
      value: {{ .platformName | quote }}
    - name: flavor
      value: {{ .flavorName | quote }}
  workspaces:
    - name: pattern-repo
      workspace: shared-data
      subPath: pattern-repo
{{- end }}

{{/*
Install, optional spoke import, tests, and diagnostics (after provisioning).
*/}}
{{- define "qeCIPipelines.tasks.post-provision" -}}
{{- $patternSecrets := list -}}
{{- if and (kindIs "map" .app)  .app.secrets -}}
{{- range $i, $entry := .app.secrets -}}
{{- $name := include "qeCIPipelines.patternSecretName" $entry -}}
{{- $workspace := include "qeCIPipelines.secretWorkspaceName" $name -}}
{{- $patternSecrets = append $patternSecrets (dict "name" $name "workspace" $workspace "index" $i) -}}
{{- end -}}
{{- end -}}
{{- if eq .flavorName "multi-dr" }}
- name: prepare-dr-secrets
  runAfter:
    - provision-hub
    - provision-spoke-primary
    - provision-spoke-secondary
  taskRef:
    name: prepare-dr-secrets
  params:
    - name: spoke-primary-cluster-name
      value: $(tasks.provision-spoke-primary.results.cluster-name)
    - name: spoke-secondary-cluster-name
      value: $(tasks.provision-spoke-secondary.results.cluster-name)
  workspaces:
    - name: kubeconfig
      workspace: shared-data
      subPath: kubeconfig
    - name: output
      workspace: shared-data
      subPath: prepared-values-secret
    {{- range $i, $secret := $patternSecrets }}
    {{- if eq $i 0 }}
    - name: base-values-secret
      workspace: {{ $secret.workspace }}
    {{- end }}
    {{- end }}
{{- end }}
- name: install-pattern
  onError: continue
  runAfter:
    {{- if eq .flavorName "single" }}
    - provision-cluster
    {{- else if eq .flavorName "multi" }}
    - provision-hub
    - provision-spoke
    {{- else if eq .flavorName "multi-dr" }}
    - prepare-dr-secrets
    {{- else }}
    - provision-hosted-cluster
    {{- end }}
  taskRef:
    kind: Task
    name: install-pattern
  params:
    {{- if eq .flavorName "single" }}
    - name: cluster-name
      value: $(tasks.provision-cluster.results.cluster-name)
    {{- else if or (eq .flavorName "multi") (eq .flavorName "multi-dr") }}
    - name: cluster-name
      value: $(tasks.provision-hub.results.cluster-name)
    {{- else }}
    - name: cluster-name
      value: $(tasks.provision-hosted-cluster.results.cluster-name)
    {{- end }}
    - name: target-clustergroup
      value: {{ include "qeCIPipelines.targetClusterGroup" . | quote }}
    {{- if and (kindIs "map" .app) .app.extraHelmOpts }}
    - name: extra-helm-opts
      value: {{ .app.extraHelmOpts  | quote }}
    {{- end }}
  workspaces:
    - name: pattern-repo
      workspace: shared-data
      subPath: pattern-repo
    - name: kubeconfig
      workspace: shared-data
      subPath: kubeconfig
    - name: install-results
      workspace: shared-data
      subPath: install-results
    {{- if eq .flavorName "multi-dr" }}
    - name: values-secret-0
      workspace: shared-data
      subPath: prepared-values-secret
    {{- else }}
    {{- range $secret := $patternSecrets }}
    - name: values-secret-{{ $secret.index }}
      workspace: {{ $secret.workspace }}
    {{- end }}
    {{- end }}
{{- if eq .flavorName "multi" }}
- name: import-spoke
  onError: continue
  runAfter:
    - install-pattern
  taskRef:
    kind: Task
    name: import-spoke-cluster
  params:
    - name: hub-cluster-name
      value: $(tasks.provision-hub.results.cluster-name)
    - name: spoke-cluster-name
      value: $(tasks.provision-spoke.results.cluster-name)
  workspaces:
    - name: pattern-repo
      workspace: shared-data
      subPath: pattern-repo
    - name: kubeconfig
      workspace: shared-data
      subPath: kubeconfig
    - name: install-results
      workspace: shared-data
      subPath: install-results
{{- else if eq .flavorName "multi-dr" }}
- name: wait-hub-dr
  onError: continue
  runAfter:
    - install-pattern
  taskRef:
    name: wait-hub-dr
  params:
    - name: hub-cluster-name
      value: $(tasks.provision-hub.results.cluster-name)
  workspaces:
    - name: kubeconfig
      workspace: shared-data
      subPath: kubeconfig
    - name: install-results
      workspace: shared-data
      subPath: install-results
{{- end }}
- name: interop-test
  onError: continue
  runAfter:
    {{- if eq .flavorName "multi" }}
    - import-spoke
    {{- else if eq .flavorName "multi-dr" }}
    - wait-hub-dr
    {{- else }}
    - install-pattern
    {{- end }}
  taskRef:
    kind: Task
    name: interop-test
  params:
    {{- if eq .flavorName "single" }}
    - name: hub-cluster-name
      value: $(tasks.provision-cluster.results.cluster-name)
    {{- else if eq .flavorName "multi" }}
    - name: hub-cluster-name
      value: $(tasks.provision-hub.results.cluster-name)
    - name: spoke-cluster-name
      value: $(tasks.provision-spoke.results.cluster-name)
    {{- else if eq .flavorName "multi-dr" }}
    - name: hub-cluster-name
      value: $(tasks.provision-hub.results.cluster-name)
    - name: spoke-cluster-name
      value: $(tasks.provision-spoke-primary.results.cluster-name)
    - name: spoke-secondary-cluster-name
      value: $(tasks.provision-spoke-secondary.results.cluster-name)
    {{- else }}
    - name: hub-cluster-name
      value: $(tasks.provision-hosted-cluster.results.cluster-name)
    {{- end }}
    - name: target-clustergroup
      value: {{ include "qeCIPipelines.targetClusterGroup" . | quote }}
  workspaces:
    - name: test-results
      workspace: shared-data
      subPath: test-results
    - name: pattern-repo
      workspace: shared-data
      subPath: pattern-repo
    - name: kubeconfig
      workspace: shared-data
      subPath: kubeconfig
- name: must-gather-hub
  runAfter:
    - interop-test
  taskRef:
    kind: Task
    name: must-gather
  params:
    - name: cluster-name
    {{- if eq .flavorName "single" }}
      value: $(tasks.provision-cluster.results.cluster-name)
    {{- else if or (eq .flavorName "multi") (eq .flavorName "multi-dr") }}
      value: $(tasks.provision-hub.results.cluster-name)
    {{- else }}
      value: $(tasks.provision-hosted-cluster.results.cluster-name)
    {{- end }}
  workspaces:
    - name: kubeconfig
      workspace: shared-data
      subPath: kubeconfig
    - name: must-gather
      workspace: shared-data
      subPath: must-gather
    - name: test-results
      workspace: shared-data
      subPath: test-results
    - name: install-results
      workspace: shared-data
      subPath: install-results
{{- if eq .flavorName "multi" }}
- name: must-gather-spoke
  runAfter:
    - interop-test
  taskRef:
    kind: Task
    name: must-gather
  params:
    - name: cluster-name
      value: $(tasks.provision-spoke.results.cluster-name)
  workspaces:
    - name: kubeconfig
      workspace: shared-data
      subPath: kubeconfig
    - name: must-gather
      workspace: shared-data
      subPath: must-gather
    - name: test-results
      workspace: shared-data
      subPath: test-results
    - name: install-results
      workspace: shared-data
      subPath: install-results
{{- else if eq .flavorName "multi-dr" }}
- name: must-gather-spoke-primary
  runAfter:
    - interop-test
  taskRef:
    name: must-gather
  params:
    - name: cluster-name
      value: $(tasks.provision-spoke-primary.results.cluster-name)
  workspaces:
    - name: kubeconfig
      workspace: shared-data
      subPath: kubeconfig
    - name: must-gather
      workspace: shared-data
      subPath: must-gather
    - name: test-results
      workspace: shared-data
      subPath: test-results
    - name: install-results
      workspace: shared-data
      subPath: install-results
- name: must-gather-spoke-secondary
  runAfter:
    - interop-test
  taskRef:
    name: must-gather
  params:
    - name: cluster-name
      value: $(tasks.provision-spoke-secondary.results.cluster-name)
  workspaces:
    - name: kubeconfig
      workspace: shared-data
      subPath: kubeconfig
    - name: must-gather
      workspace: shared-data
      subPath: must-gather
    - name: test-results
      workspace: shared-data
      subPath: test-results
    - name: install-results
      workspace: shared-data
      subPath: install-results
{{- end }}
- name: upload-must-gather
  runAfter:
    - must-gather-hub
{{- if eq .flavorName "multi" }}
    - must-gather-spoke
{{- else if eq .flavorName "multi-dr" }}
    - must-gather-spoke-primary
    - must-gather-spoke-secondary
{{- end }}
  when:
    - input: $(tasks.must-gather-hub.results.outcome)
      operator: in
      values: ["success"]
{{- if eq .flavorName "multi" }}
    - input: $(tasks.must-gather-spoke.results.outcome)
      operator: in
      values: ["success"]
{{- else if eq .flavorName "multi-dr" }}
    - input: $(tasks.must-gather-spoke-primary.results.outcome)
      operator: in
      values: ["success"]
    - input: $(tasks.must-gather-spoke-secondary.results.outcome)
      operator: in
      values: ["success"]
{{- end }}
  taskRef:
    kind: Task
    name: upload-must-gather
  workspaces:
    - name: must-gather
      workspace: shared-data
      subPath: must-gather
  params:
    - name: pipeline-name
      value: $(context.pipeline.name)
    - name: pipelinerun-id
      value: $(context.pipelineRun.uid)
{{- end }}

{{/*
Shared finally tasks (not flavor-specific cleanup).
*/}}
{{- define "qeCIPipelines.finally.common" -}}
- name: slack-notify-any-failure
  when:
    - input: $(tasks.status)
      operator: in
      values: ["Failed"]
  taskRef:
    kind: Task
    name: slack-notify-failure
  params:
- name: pipeline-failure-check
  taskRef:
    kind: Task
    name: pipeline-failure-check
  params:
    - name: aggregateTasksStatus
      value: "$(tasks.status)"
- name: generate-ci-badge
  taskRef:
    kind: Task
    name: generate-ci-badge
  params:
    - name: pattern-repo-url
    {{- if eq .patternName "oper" }}
      value: $(params.patterns-operator-repo-url)
    {{- else }}
      value: $(params.pattern-repo-url)
    {{- end }}
    - name: pattern-repo-revision
    {{- if eq .patternName "oper" }}
      value: $(params.patterns-operator-repo-revision)
    {{- else }}
      value: $(params.pattern-repo-revision)
    {{- end }}
    - name: platform
      value: {{ .platformName | quote }}
    - name: ocp-version
      value: {{ .ocpVersion | quote }}
    - name: exact-ocp-version
    {{- if eq .flavorName "single" }}
      value: $(tasks.provision-cluster.results.exact-ocp-version)
    {{- else if or (eq .flavorName "multi") (eq .flavorName "multi-dr") }}
      value: $(tasks.provision-hub.results.exact-ocp-version)
    {{- else }}
      value: $(tasks.provision-hosted-cluster.results.exact-ocp-version)
    {{- end }}
    - name: pattern-name
      value: {{ .patternName | quote }}
    - name: must-gather-status
      value: $(tasks.upload-must-gather.status)
    - name: pipelinerun-ns
      value: $(context.pipelineRun.namespace)
    - name: pipelinerun-name
      value: $(context.pipelineRun.name)
    - name: pipelinerun-id
      value: $(context.pipelineRun.uid)
    - name: pipeline-name
      value: $(context.pipeline.name)
    - name: target-clustergroup
      value: {{ include "qeCIPipelines.targetClusterGroup" . | quote }}
  workspaces:
    - name: results
      workspace: shared-data
    - name: kubeconfig
      workspace: shared-data
      subPath: kubeconfig
    - name: test-results
      workspace: shared-data
      subPath: test-results
    - name: install-results
      workspace: shared-data
      subPath: install-results
{{- end }}
