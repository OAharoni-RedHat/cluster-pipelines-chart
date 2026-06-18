{{/*
Checkout, metadata validation, and sizing (always first).
*/}}
{{- define "pipelines.tasks.setup" -}}
- name: checkout-pattern-repo
  taskRef:
    resolver: cluster
    params:
      - name: kind
        value: task
      - name: namespace
        value: openshift-pipelines
      - name: name
        value: git-clone
  workspaces:
    - name: output
      workspace: shared-data
      subPath: repo
  params:
    - name: URL
      value: $(params.pattern-repo-url)
    - name: REVISION
      value: $(params.pattern-repo-revision)
    - name: DEPTH
      value: "0"
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
      subPath: repo
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
  workspaces:
    - name: pattern-repo
      workspace: shared-data
      subPath: repo
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
  when:
    - cel: "'$(tasks.install-pattern.results.outcome)' != 'failed'"
  onError: continue
  taskRef:
    name: interop-test
  params:
    - name: flavor
      value: {{ .flavorName | quote }}
    - name: test-edge
      value: {{ if eq .flavorName "hub-spoke" }}"true"{{ else }}"false"{{ end }}
  workspaces:
    - name: pattern-repo
      workspace: shared-data
      subPath: repo
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
    - install-pattern
    - interop-test
  when:
    - cel: "'$(tasks.install-pattern.results.outcome)' == 'failed' || '$(tasks.interop-test.results.outcome)' == 'failed'"
  taskRef:
    name: must-gather
  params:
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
