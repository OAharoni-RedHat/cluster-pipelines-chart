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
    - name: application
      value: {{ .appName | quote }}
    - name: platform
      value: {{ .platformName | quote }}
    - name: flavor
      value: {{ .flavorName | quote }}
  workspaces:
    - name: pattern-repo
      workspace: shared-data
      subPath: repo
- name: resolve-pattern-sizing
  runAfter:
    - validate-pattern-metadata
  taskRef:
    name: resolve-pattern-sizing
  params:
    - name: hub-control-plane
      value: $(tasks.validate-pattern-metadata.results.hub-control-plane[*])
    - name: hub-compute-nodes
      value: $(tasks.validate-pattern-metadata.results.hub-compute-nodes[*])
    - name: spoke-control-plane
      value: $(tasks.validate-pattern-metadata.results.spoke-control-plane[*])
    - name: spoke-compute-nodes
      value: $(tasks.validate-pattern-metadata.results.spoke-compute-nodes[*])
{{- end }}

{{/*
Install, optional spoke import, tests, and diagnostics (after provisioning).
*/}}
{{- define "pipelines.tasks.post-provision" -}}
- name: install-pattern
  onError: continue
  runAfter:
    {{- if eq .flavorName "hub" }}
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
    - name: application
      value: {{ .appName | quote }}
    - name: platform
      value: {{ .platformName | quote }}
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
    - name: application
      value: {{ .appName | quote }}
- name: must-gather
  runAfter:
    - install-pattern
    - interop-test
  when:
    - cel: "'$(tasks.install-pattern.results.outcome)' == 'failed' || '$(tasks.interop-test.results.outcome)' == 'failed'"
  taskRef:
    name: must-gather
  params:
    - name: application
      value: {{ .appName | quote }}
- name: upload-must-gather
  runAfter:
    - must-gather
  when:
    - cel: "'$(tasks.must-gather.results.outcome)' == 'success'"
  taskRef:
    name: upload-must-gather
  params:
    - name: application
      value: {{ .appName | quote }}
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
    - name: application
      value: {{ .appName | quote }}
    - name: flavor
      value: {{ .flavorName | quote }}
- name: pipeline-failure-check
  taskRef:
    name: pipeline-failure-check
  params:
    - name: aggregateTasksStatus
      value: "$(tasks.status)"
{{- end }}
