{{/*
Shared install-config.yaml fragments for Hive cluster provisioning.

Bash variables expected at runtime:
  CLUSTER_NAME, BASE_DOMAIN, CLOUD_PROVIDER, CLOUD_REGION
  CP_REPLICAS, CP_TYPE, WORKER_REPLICAS, WORKER_TYPE
  AZ_RG, GCP_PROJECT, SSH_KEY (optional)
  OUT (output file path)
*/}}

{{- define "tasks.installConfig.networking" -}}
networking:
  clusterNetwork:
  - cidr: {{ (index .Values.pipelines.defaults.networking.clusterNetwork 0).cidr }}
    hostPrefix: {{ (index .Values.pipelines.defaults.networking.clusterNetwork 0).hostPrefix }}
  machineNetwork:
  - cidr: {{ (index .Values.pipelines.defaults.networking.machineNetwork 0).cidr }}
  networkType: {{ .Values.pipelines.defaults.networking.networkType }}
  serviceNetwork:
  - {{ index .Values.pipelines.defaults.networking.serviceNetwork 0 }}
{{- end }}

{{- define "tasks.installConfig.machinePlatform.aws" -}}
aws:
  type: ${ {{- .typeVar -}} }
  rootVolume:
    size: 200
    type: gp3
{{- end }}

{{- define "tasks.installConfig.machinePlatform.gcp" -}}
gcp:
  type: ${ {{- .typeVar -}} }
{{- end }}

{{- define "tasks.installConfig.machinePlatform.azure" -}}
azure:
  type: ${ {{- .typeVar -}} }
  osDisk:
    diskSizeGB: 512
    type: Premium_LRS
{{- end }}

{{- define "tasks.installConfig.workerNode" -}}
- architecture: amd64
  hyperthreading: Enabled
  name: worker
  replicas: ${WORKER_REPLICAS}
  platform:
{{- include .platformMachine (dict "typeVar" "WORKER_TYPE") | nindent 4 }}
{{- end }}

{{- define "tasks.installConfig.controlPlaneNode" -}}
controlPlane:
  architecture: amd64
  hyperthreading: Enabled
  name: master
  replicas: ${CP_REPLICAS}
  platform:
{{- include .platformMachine (dict "typeVar" "CP_TYPE") | nindent 4 }}
{{- end }}

{{- define "tasks.installConfig.documentCore" -}}
apiVersion: v1
baseDomain: ${BASE_DOMAIN}
compute:
{{ include "tasks.installConfig.workerNode" . }}
{{ include "tasks.installConfig.controlPlaneNode" . }}
metadata:
  name: ${CLUSTER_NAME}
{{ include "tasks.installConfig.networking" . }}
{{- end }}

{{- define "tasks.installConfig.document.aws" -}}
{{ include "tasks.installConfig.documentCore" (merge (dict "platformMachine" "tasks.installConfig.machinePlatform.aws") .) }}
platform:
  aws:
    region: ${CLOUD_REGION}
pullSecret: ""
{{- end }}

{{- define "tasks.installConfig.document.gcp" -}}
{{ include "tasks.installConfig.documentCore" (merge (dict "platformMachine" "tasks.installConfig.machinePlatform.gcp") .) }}
platform:
  gcp:
    projectID: ${GCP_PROJECT}
    region: ${CLOUD_REGION}
pullSecret: ""
{{- end }}

{{- define "tasks.installConfig.document.azure" -}}
{{ include "tasks.installConfig.documentCore" (merge (dict "platformMachine" "tasks.installConfig.machinePlatform.azure") .) }}
platform:
  azure:
    baseDomainResourceGroupName: ${AZ_RG}
    cloudName: AzurePublicCloud
    region: ${CLOUD_REGION}
pullSecret: ""
{{- end }}

{{- define "tasks.installConfig.generateScript" -}}
PROVIDER="$(echo "${CLOUD_PROVIDER}" | tr '[:upper:]' '[:lower:]')"

case "${PROVIDER}" in
  aws|amazon)
    cat > "${OUT}" <<EOF
{{ include "tasks.installConfig.document.aws" . }}
EOF
    ;;
  gcp|google)
    cat > "${OUT}" <<EOF
{{ include "tasks.installConfig.document.gcp" . }}
EOF
    ;;
  azure)
    cat > "${OUT}" <<EOF
{{ include "tasks.installConfig.document.azure" . }}
EOF
    ;;
  *)
    echo "unsupported cloud-provider: ${CLOUD_PROVIDER}" >&2
    exit 1
    ;;
esac

if [ -n "${SSH_KEY}" ]; then
  printf '\nsshKey: |-\n' >> "${OUT}"
  printf '%s\n' "${SSH_KEY}" | sed 's/^/  /' >> "${OUT}"
fi
{{- end }}

{{/*
Emit bash case arms mapping params.platform to region/baseDomain and cloud-specific fields.
Sourced from pipelines.defaults.platforms in values.yaml.
*/}}
{{- define "tasks.installConfig.platformEnvCase" -}}
{{- range $name, $cfg := .Values.pipelines.defaults.platforms }}
  {{ $name }})
    BASE_DOMAIN={{ $cfg.baseDomain | quote }}
    CLOUD_REGION={{ $cfg.region | quote }}
    {{- if eq $name "gcp" }}
    GCP_PROJECT={{ default "" $cfg.projectId | quote }}
    {{- end }}
    {{- if eq $name "azure" }}
    AZ_RG={{ default "" $cfg.resourceGroup | quote }}
    {{- end }}
    ;;
{{- end }}
  *)
    echo "unsupported platform: ${PLATFORM}" >&2
    exit 1
    ;;
{{- end }}
