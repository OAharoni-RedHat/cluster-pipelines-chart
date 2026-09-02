# cluster-pipelines

![Version: 0.0.6](https://img.shields.io/badge/Version-0.0.6-informational?style=flat-square)

A Helm chart that deploys cluster provisioning pipelines

This chart is used to serve as the template for Validated Patterns Charts

## Notable changes

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| awsCliImage | string | `"amazon/aws-cli:latest"` |  |
| clusterGroup | object | `{}` |  |
| externalSecrets.awsCreds.key | string | `"secret/data/hub/aws"` |  |
| externalSecrets.azureCreds.key | string | `"secret/data/hub/azure"` |  |
| externalSecrets.gcpCreds.key | string | `"secret/data/hub/gcp"` |  |
| externalSecrets.pullSecret.key | string | `"pushsecrets/global-pull-secret"` |  |
| externalSecrets.secretStore.kind | string | `"ClusterSecretStore"` |  |
| externalSecrets.secretStore.name | string | `"vault-backend"` |  |
| global.hubClusterDomain | string | `"apps.hcp.aws.validatedpatterns.io"` |  |
| hcpImage | string | `"image-registry.openshift-image-registry.svc:5000/cluster-provisioning/hcp-cli:latest"` |  |
| hive.defaultControlPlaneReplicas | string | `"3"` |  |
| hive.defaultWorkerReplicas | string | `"3"` |  |
| hypershift.baseDomain | string | `""` |  |
| hypershift.defaultInstanceType | string | `"m5.xlarge"` |  |
| hypershift.defaultReplicas | int | `2` |  |
| hypershift.hostedClusterNamespace | string | `"clusters"` |  |
| klusterletAddon | object | `{}` |  |
| pipelineNamespace | string | `"cluster-provisioning"` |  |
| qeCIPipelines.defaults.ciBucket | string | `"vp-qe-ci-badges"` |  |
| qeCIPipelines.defaults.flavors.hosted.clusterGroup | string | `"hub"` |  |
| qeCIPipelines.defaults.flavors.hosted.platforms[0] | string | `"aws"` |  |
| qeCIPipelines.defaults.flavors.multi.clusterGroup | string | `"hub"` |  |
| qeCIPipelines.defaults.flavors.single.clusterGroup | string | `"hub"` |  |
| qeCIPipelines.defaults.hcpARN | string | `"arn:aws:iam::296267305927:role/hypershift_cli_role"` |  |
| qeCIPipelines.defaults.mustGatherBucket | string | `"vp-qe-ci-must-gathers"` |  |
| qeCIPipelines.defaults.mustGatherImg | string | `"quay.io/validatedpatterns/must-gather"` |  |
| qeCIPipelines.defaults.namespace | string | `"vp-qe-ci"` |  |
| qeCIPipelines.defaults.networking.clusterNetwork[0].cidr | string | `"10.128.0.0/14"` |  |
| qeCIPipelines.defaults.networking.clusterNetwork[0].hostPrefix | int | `23` |  |
| qeCIPipelines.defaults.networking.machineNetwork[0].cidr | string | `"10.0.0.0/16"` |  |
| qeCIPipelines.defaults.networking.multiDr.hub.clusterHostPrefix | int | `23` |  |
| qeCIPipelines.defaults.networking.multiDr.hub.clusterNetworkCidr | string | `"10.128.0.0/14"` |  |
| qeCIPipelines.defaults.networking.multiDr.hub.machineNetworkCidr | string | `"10.0.0.0/16"` |  |
| qeCIPipelines.defaults.networking.multiDr.hub.serviceNetworkCidr | string | `"172.30.0.0/16"` |  |
| qeCIPipelines.defaults.networking.multiDr.spokePrimary.clusterHostPrefix | int | `23` |  |
| qeCIPipelines.defaults.networking.multiDr.spokePrimary.clusterNetworkCidr | string | `"10.132.0.0/14"` |  |
| qeCIPipelines.defaults.networking.multiDr.spokePrimary.machineNetworkCidr | string | `"10.1.0.0/16"` |  |
| qeCIPipelines.defaults.networking.multiDr.spokePrimary.serviceNetworkCidr | string | `"172.31.0.0/16"` |  |
| qeCIPipelines.defaults.networking.multiDr.spokeSecondary.clusterHostPrefix | int | `23` |  |
| qeCIPipelines.defaults.networking.multiDr.spokeSecondary.clusterNetworkCidr | string | `"10.136.0.0/14"` |  |
| qeCIPipelines.defaults.networking.multiDr.spokeSecondary.machineNetworkCidr | string | `"10.2.0.0/16"` |  |
| qeCIPipelines.defaults.networking.multiDr.spokeSecondary.serviceNetworkCidr | string | `"172.32.0.0/16"` |  |
| qeCIPipelines.defaults.networking.networkType | string | `"OVNKubernetes"` |  |
| qeCIPipelines.defaults.networking.serviceNetwork[0] | string | `"172.30.0.0/16"` |  |
| qeCIPipelines.defaults.ocp_versions[0] | string | `"4.20"` |  |
| qeCIPipelines.defaults.ocp_versions[1] | string | `"4.21"` |  |
| qeCIPipelines.defaults.ocp_versions[2] | string | `"4.22"` |  |
| qeCIPipelines.defaults.platforms.aws.baseDomain | string | `"aws.validatedpatterns.io"` |  |
| qeCIPipelines.defaults.platforms.aws.computeNodeIAMRole | string | `"vp-ocp-Worker-Role"` |  |
| qeCIPipelines.defaults.platforms.aws.controlPlaneIAMRole | string | `"vp-ocp-ControlPlane-Role"` |  |
| qeCIPipelines.defaults.platforms.aws.credentialName | string | `"qe-ci-aws-creds"` |  |
| qeCIPipelines.defaults.platforms.aws.region | string | `"us-east-1"` |  |
| qeCIPipelines.defaults.platforms.azure.baseDomain | string | `"azure.validatedpatterns.io"` |  |
| qeCIPipelines.defaults.platforms.azure.baseDomainResourceGroup | string | `"os4-common"` |  |
| qeCIPipelines.defaults.platforms.azure.credentialName | string | `"qe-ci-azure-creds"` |  |
| qeCIPipelines.defaults.platforms.azure.region | string | `"westus3"` |  |
| qeCIPipelines.defaults.platforms.gcp.baseDomain | string | `"gcp.validatedpatterns.io"` |  |
| qeCIPipelines.defaults.platforms.gcp.credentialName | string | `"qe-ci-gcp-creds"` |  |
| qeCIPipelines.defaults.platforms.gcp.projectId | string | `"rh-patterns"` |  |
| qeCIPipelines.defaults.platforms.gcp.region | string | `"us-central1"` |  |
| qeCIPipelines.defaults.provisionTaskTimeout | string | `"2h"` |  |
| qeCIPipelines.defaults.utilityContainerImg | string | `"quay.io/validatedpatterns/utility-container"` |  |
| qeCIPipelines.patterns.ansible-edge.flavors.single | string | `nil` |  |
| qeCIPipelines.patterns.ansible-edge.platforms.aws | string | `nil` |  |
| qeCIPipelines.patterns.ansible-edge.repo | string | `"https://github.com/darkdoc/ansible-edge-gitops.git"` |  |
| qeCIPipelines.patterns.ansible-edge.secrets[0] | string | `"aeg-secret-values-file"` |  |
| qeCIPipelines.patterns.ansible-edge.secrets[1] | string | `"aeg-aap-manifest-file"` |  |
| qeCIPipelines.patterns.ansible-edge.secrets[2] | string | `"aeg-aap-ssh-file"` |  |
| qeCIPipelines.patterns.layered-zero.flavors.single.clusterGroup | string | `"ci"` |  |
| qeCIPipelines.patterns.layered-zero.repo | string | `"https://github.com/darkdoc/layered-zero-trust.git"` |  |
| qeCIPipelines.patterns.layered-zero.revision | string | `"pipeline_test"` |  |
| qeCIPipelines.patterns.mcg.flavors.hosted.clusterGroup | string | `"standalone"` |  |
| qeCIPipelines.patterns.mcg.flavors.multi | string | `nil` |  |
| qeCIPipelines.patterns.mcg.flavors.single.clusterGroup | string | `"standalone"` |  |
| qeCIPipelines.patterns.mcg.repo | string | `"https://github.com/validatedpatterns/multicloud-gitops.git"` |  |
| qeCIPipelines.patterns.ramen.awsCredsSecret | string | `"qe-ci-aws-creds"` |  |
| qeCIPipelines.patterns.ramen.flavors.multi-dr.clusterGroup | string | `"odf"` |  |
| qeCIPipelines.patterns.ramen.ocp_versions[0] | string | `"4.20"` |  |
| qeCIPipelines.patterns.ramen.ocp_versions[1] | string | `"4.22"` |  |
| qeCIPipelines.patterns.ramen.platforms.aws.spokePrimaryRegion | string | `"us-west-1"` |  |
| qeCIPipelines.patterns.ramen.platforms.aws.spokeSecondaryRegion | string | `"us-east-2"` |  |
| qeCIPipelines.patterns.ramen.repo | string | `"https://github.com/validatedpatterns/ramendr-starter-kit.git"` |  |
| qeCIPipelines.patterns.ramen.revision | string | `"main"` |  |
| qeCIPipelines.patterns.ramen.secrets[0] | string | `"ramendr-secret-values-file"` |  |
| qeCIPipelines.patterns.ramen.spokePrimaryAcmName | string | `"ocp-primary"` |  |
| qeCIPipelines.patterns.ramen.spokeSecondaryAcmName | string | `"ocp-secondary"` |  |
| qeCIPipelines.scheduleDefaults.concurrencyPolicy | string | `"Forbid"` |  |
| qeCIPipelines.scheduleDefaults.failedJobsHistoryLimit | int | `3` |  |
| qeCIPipelines.scheduleDefaults.finallyTimeout | string | `"30m"` |  |
| qeCIPipelines.scheduleDefaults.successfulJobsHistoryLimit | int | `3` |  |
| qeCIPipelines.scheduleDefaults.suspend | bool | `false` |  |
| qeCIPipelines.scheduleDefaults.taskTimeout | string | `"2h"` |  |
| qeCIPipelines.scheduleDefaults.timeout | string | `"3h"` |  |
| qeCIPipelines.scheduleDefaults.workspaceStorage | string | `"1Gi"` |  |
| qeCIPipelines.schedules[0].cron | string | `"0 6 * * 4"` |  |
| qeCIPipelines.schedules[0].pipeline | string | `"mcg-aws-4-22-multi"` |  |
| qeCIPipelines.schedules[10].cron | string | `"0 6 * * 5"` |  |
| qeCIPipelines.schedules[10].pipeline | string | `"ansible-edge-aws-4-20-single"` |  |
| qeCIPipelines.schedules[11].cron | string | `"0 6 * * 5"` |  |
| qeCIPipelines.schedules[11].pipeline | string | `"ansible-edge-aws-4-21-single"` |  |
| qeCIPipelines.schedules[12].cron | string | `"0 7 * * 5"` |  |
| qeCIPipelines.schedules[12].pipeline | string | `"ansible-edge-aws-4-22-single"` |  |
| qeCIPipelines.schedules[1].cron | string | `"0 6 * * 4"` |  |
| qeCIPipelines.schedules[1].pipeline | string | `"mcg-aws-4-21-multi"` |  |
| qeCIPipelines.schedules[2].cron | string | `"0 7 * * 4"` |  |
| qeCIPipelines.schedules[2].pipeline | string | `"mcg-azure-4-20-multi"` |  |
| qeCIPipelines.schedules[3].cron | string | `"0 7 * * 4"` |  |
| qeCIPipelines.schedules[3].pipeline | string | `"mcg-gcp-4-21-multi"` |  |
| qeCIPipelines.schedules[4].cron | string | `"0 8 * * 4"` |  |
| qeCIPipelines.schedules[4].pipeline | string | `"mcg-aws-4-20-single"` |  |
| qeCIPipelines.schedules[5].cron | string | `"0 8 * * 4"` |  |
| qeCIPipelines.schedules[5].pipeline | string | `"mcg-aws-4-21-single"` |  |
| qeCIPipelines.schedules[6].cron | string | `"0 9 * * 4"` |  |
| qeCIPipelines.schedules[6].pipeline | string | `"mcg-aws-4-22-single"` |  |
| qeCIPipelines.schedules[7].cron | string | `"0 9 * * 4"` |  |
| qeCIPipelines.schedules[7].pipeline | string | `"mcg-aws-4-20-hosted"` |  |
| qeCIPipelines.schedules[8].cron | string | `"0 10 * * 4"` |  |
| qeCIPipelines.schedules[8].pipeline | string | `"mcg-aws-4-21-hosted"` |  |
| qeCIPipelines.schedules[9].cron | string | `"0 10 * * 4"` |  |
| qeCIPipelines.schedules[9].pipeline | string | `"mcg-aws-4-22-hosted"` |  |
| serviceAccount.create | bool | `true` |  |
| serviceAccount.name | string | `"provisioner"` |  |
| serviceAccount.namespace | string | `"cluster-provisioning"` |  |
| toolsImage | string | `"image-registry.openshift-image-registry.svc:5000/openshift/tools"` |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
