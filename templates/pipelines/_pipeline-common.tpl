{{/*
Checkout, metadata validation, and sizing (always first).
*/}}
{{- define "pipelines.tasks.setup" -}}
- name: checkout-pattern-repo
  taskRef:
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
{{- define "pipelines.tasks.post-provision" -}}
- name: install-pattern
  onError: continue
  runAfter:
    {{- if eq .flavorName "standalone" }}
    - provision-cluster
    {{- else if eq .flavorName "hub-spoke" }}
    - provision-hub
    - provision-spoke
    {{- else }}
    - provision-hosted-cluster
    {{- end }}
  taskRef:
    name: install-pattern
  params:
    - name: cluster-name
    {{- if eq .flavorName "standalone" }}
      value: $(tasks.provision-cluster.results.cluster-name)
    {{- else if eq .flavorName "hub-spoke" }}
      value: $(tasks.provision-hub.results.cluster-name)
    {{- else }}
      value: $(tasks.provision-hosted-cluster.results.cluster-name)
    {{- end }}
  workspaces:
    - name: pattern-repo
      workspace: shared-data
      subPath: pattern-repo
    - name: kubeconfig
      workspace: shared-data
      subPath: kubeconfig
{{- if eq .flavorName "hub-spoke" }}
- name: import-spoke
  runAfter:
    - install-pattern
  taskRef:
    name: import-spoke-cluster
  params:
  workspaces:
    - name: kubeconfig
      workspace: shared-data
      subPath: kubeconfig
{{- end }}
- name: interop-test
  runAfter:
    {{- if eq .flavorName "hub-spoke" }}
    - import-spoke
    {{- else }}
    - install-pattern
    {{- end }}
  taskRef:
    name: interop-test
  params:
    - name: flavor
      value: {{ .flavorName | quote }}
    - name: test-edge
      value: {{ if eq .flavorName "hub-spoke" }}"true"{{ else }}"false"{{ end }}
    - name: cluster-name
    {{- if eq .flavorName "standalone" }}
      value: $(tasks.provision-cluster.results.cluster-name)
    {{- else if eq .flavorName "hub-spoke" }}
      value: $(tasks.provision-hub.results.cluster-name)
    {{- else }}
      value: $(tasks.provision-hosted-cluster.results.cluster-name)
    {{- end }}
    - name: install-status
    {{- if eq .flavorName "hub-spoke" }}
      value: $(tasks.import-spoke.results.import-status)
    {{- else }}
      value: $(tasks.install-pattern.results.outcome)
    {{- end }}
  workspaces:
    - name: pattern-repo
      workspace: shared-data
      subPath: pattern-repo
    - name: kubeconfig
      workspace: shared-data
      subPath: kubeconfig
    - name: test-results
      workspace: shared-data
      subPath: test-results
- name: upload-test-results
  runAfter:
    - interop-test
  when:
    - input: "$(tasks.interop-test.results.outcome)"
      operator: in
      values: ["success", "failed"]
  taskRef:
    name: upload-test-results
  params:
- name: must-gather
  runAfter:
    - interop-test
  when:
    - cel: "'$(tasks.install-pattern.results.outcome)' == 'failed' || '$(tasks.interop-test.results.outcome)' == 'failed'"
  taskRef:
    name: must-gather
  params:
    - name: cluster-name
    {{- if eq .flavorName "standalone" }}
      value: $(tasks.provision-cluster.results.cluster-name)
    {{- else if eq .flavorName "hub-spoke" }}
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
- name: upload-must-gather
  runAfter:
    - must-gather
  when:
    - cel: "'$(tasks.must-gather.results.outcome)' == 'success'"
  taskRef:
    name: upload-must-gather
  params:
{{- end }}

{{/*
Shared finally tasks (not flavor-specific cleanup).
*/}}
{{- define "pipelines.finally.common" -}}
- name: slack-notify-any-failure
  when:
    - input: $(tasks.status)
      operator: in
      values: ["Failed"]
  taskRef:
    name: slack-notify-failure
  params:
- name: pipeline-failure-check
  taskRef:
    name: pipeline-failure-check
  params:
    - name: aggregateTasksStatus
      value: "$(tasks.status)"
{{- end }}
