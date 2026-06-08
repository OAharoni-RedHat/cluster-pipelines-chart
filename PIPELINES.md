# Pattern test pipelines

This chart renders Tekton `Pipeline` resources (and optional scheduled `CronJob` triggers) that exercise [Validated Patterns](https://validatedpatterns.io/) against real OpenShift clusters. Each pipeline is a fixed combination of **pattern**, **cloud platform**, **OCP version**, and **topology flavor**. Helm expands a Cartesian product from `values.yaml` into many named pipelines in `qeCIPipelines.defaults.namespace`.

Running pipelines from the OpenShift Pipelines UI or CLI, and debugging or connecting to provisioned clusters, are documented separately.

---

## How pipelines are generated

Rendering is driven by `templates/pipelines/standard-pipelines.yaml`. For every entry under `qeCIPipelines.patterns`, Helm computes three axes and emits one `Pipeline` per combination.

| Axis | Values source | Resolution order |
|------|----------------|------------------|
| **Platforms** | `defaults.platforms` | Pattern may set `platforms:` (map). If set, only those platform keys are used (pattern map replaces the default set, it is not merged). If unset, all keys from `defaults.platforms` are used. |
| **OCP versions** | `defaults.ocp_versions` | Pattern may set `ocp_versions:` (list or map). If unset, `defaults.ocp_versions` is used. |
| **Flavors** | `defaults.flavors` | Pattern may set `flavors:` as a **map** (`single: { clusterGroup: ci }`) or **list** (`[single, multi]`). If unset, `defaults.flavors` is used (also map or list). |

Nested loops: **pattern** × **platform** × **ocp_version** × **flavor**.

### Pipeline naming

```text
<pattern>-<platform>-<ocp-major-minor-with-dashes>-<flavor>
```

Examples: `mcg-aws-4-21-multi`, `ansible-edge-aws-4-20-single`.

Labels on each pipeline: `pattern.name`, `pattern.platform`, `pattern.ocp-version`, `pattern.flavor`.

### Global defaults (`qeCIPipelines.defaults`)

Shared configuration used across generated pipelines:

- **`platforms`** — per-cloud `region`, `baseDomain`, and provider-specific fields (`projectId`, `resourceGroup`, …).
- **`ocp_versions`** — list of short versions (e.g. `"4.21"`).
- **`flavors`** — map or list of topology types (`single`, `multi`, `hosted`). Map entries may set `clusterGroup` (see below).
- **`networking`**, **`mustGatherImg`**, **`utilityContainerImg`**, **`provisionTaskTimeout`** — used by provision and post-provision tasks.
- **`imageSets`** (sibling key under `pipelines`, not under `defaults`) — maps each short OCP version to a Hive `ClusterImageSet` name on the hub.

Each pattern entry typically sets:

- **`repo`** — default Git URL (`pattern-repo-url` param).
- **`revision`** — default branch/tag/SHA (`pattern-repo-revision` param).
- Optional overrides for platforms, versions, flavors, and **`secrets`**.

### Pipeline parameters

Every generated pipeline exposes:

| Param | Purpose |
|-------|---------|
| `pattern-repo-url` | Override pattern Git URL (forks). |
| `pattern-repo-revision` | Override Git revision for this run. |
| `force-skip-cleanup` | When `"true"`, a **successful** run skips Tekton-driven cluster deletion in `finally` for Hive flavors. See [Cluster cleanup and deprovisioning](#cluster-cleanup-and-deprovisioning). |
| `cluster-name-postfix` | Optional 4–8 character lowercase alphanumeric suffix on the Hive cluster name. Empty (default): random suffix from the `PipelineRun` name after `{pipeline}-`. Set to that suffix (e.g. from the console) to reuse a `ClusterDeployment`. |

### End-to-end task layout

All flavors share the same high-level shape:

```text
setup → provision (flavor-specific) → post-provision → finally (cleanup + reporting)
```

- **Setup** — `qeCIPipelines.tasks.setup` in `_pipeline-common.tpl`
- **Provision** — `qeCIPipelines.provision.<flavor>` (`single`, `multi`, `hosted`)
- **Post-provision** — `qeCIPipelines.tasks.post-provision`
- **Finally** — `qeCIPipelines.cleanup.<flavor>` plus `qeCIPipelines.finally.common` (Slack on failure, aggregate status, CI badge)

---

## Flavors: pre-provision, provision, post-provision

### Pre-provision (all flavors)

Runs before any cluster exists for this run:

1. **`checkout-pattern-repo`** — Clones the pattern repository into the `shared-data` workspace (`pattern-repo` subpath). URL and revision come from pipeline params (defaults from the pattern entry in values).
2. **`validate-pattern-metadata`** — Reads `pattern-metadata.yaml` in the repo. Confirms the pipeline’s baked **platform** and **flavor** are supported (for example `extra_features.spoke_support` for `multi`, `extra_features.hypershift_support` for `hosted`). For Hive flavors, it checks that hub (and spoke, when applicable) have non-empty sizing for that platform—control plane `type` and replica counts—and passes those values through to provision. It does **not** validate yet that cloud-specific fields are correct (for example whether a machine **type** exists or is allowed in that region on AWS, GCP, or Azure); invalid types may only surface during Hive install.

If validation fails, provisioning does not start.

### Provision by flavor

#### `single`

One Hive-managed cluster acting as the pattern target (metadata role **hub**).

- **`provision-cluster`** — After validation: builds `install-config` and `ClusterDeployment` from pattern name, platform, OCP version, role, flavor, and a per-run suffix (`cluster-name-postfix` or the `PipelineRun` name tail); applies them in `qeCIPipelines.defaults.namespace`; waits until the deployment is Ready; exports admin kubeconfig (and password when present) into `shared-data` / `kubeconfig`.

Cluster name pattern:

```text
<pattern>-<platform>-<version-dashed>-hub-single
```

#### `multi`

Hub-and-spoke topology: two Hive clusters provisioned **in parallel** after validation (both depend only on `validate-pattern-metadata`).

- **`provision-hub`** — Same as single, role `hub`, sizing from `hub-*` metadata results.
- **`provision-spoke`** — Role `spoke`, sizing from `spoke-*` metadata results.

Naming uses `-hub-multi` and `-spoke-multi` suffix segments (role and flavor in the deterministic name).

#### `hosted`

HyperShift **hosted cluster** on a management hub (not a full Hive standalone/spoke pair for the workload).

- **`provision-hosted-cluster`** — Params: pattern name (`application`), platform, OCP version. Uses the `hcp-cli` image path configured in chart values. *(Implementation is still being wired; the task documents the intended deploy chain.)*

Cleanup uses **`destroy-hosted-cluster`** instead of Hive `delete-cluster`.

### Post-provision (all flavors)

Runs after the relevant provision task(s) complete:

1. **`install-pattern`** — Uses kubeconfig for the primary cluster (single: provisioned cluster; multi: **hub**; hosted: hosted cluster). Sets `TARGET_CLUSTERGROUP` from resolved `clusterGroup` (see below). Runs `./pattern.sh make install` in the checked-out repo. Optional pattern **secrets** are mounted as workspaces and copied into the task home directory for `values-secrets.yaml` references.
2. **`import-spoke`** — **Multi only.** After install on the hub, when install succeeded, runs `./pattern.sh make import-default-spoke` in the pattern repo (hub and spoke kubeconfigs supplied via `VP_HUBCONFIG` / `VP_SPOKECONFIG`).
3. **`interop-test`** — When install (and on multi, import) succeeded, runs `./pattern.sh make run-ci-tests` with the same `TARGET_CLUSTERGROUP` as install. Skipped with outcome `skipped` if a prior step failed.
4. **`must-gather-hub`** / **`must-gather-spoke`** — On install or test failure (multi gathers both).
5. **`upload-must-gather`** — Uploads archives when gather steps succeed.

Install and interop tasks use `onError: continue` so failures can still trigger diagnostics and `finally`.

### `clusterGroup` (install / test target)

Resolved by `qeCIPipelines.targetClusterGroup`:

1. `qeCIPipelines.patterns.<name>.flavors.<flavor>.clusterGroup`
2. Else `qeCIPipelines.defaults.flavors.<flavor>.clusterGroup` (when defaults flavors are a map)
3. Else **`hub`**

Example: `mcg` sets `single.clusterGroup: standalone` so install/tests target the standalone group even though the cluster is one Hive deployment.

### Finally (cleanup and reporting)

Tekton `finally` tasks always run reporting steps; cluster teardown is flavor-specific and gated on success. See **[Cluster cleanup and deprovisioning](#cluster-cleanup-and-deprovisioning)** for the full policy.

- **Hive (`single` / `multi`)** — `delete-cluster` in `finally` when the run **Completed** successfully and `force-skip-cleanup` is `"false"`.
- **`hosted`** — `destroy-hosted-cluster` when the run **Completed** successfully (does not consult `force-skip-cleanup` today).
- **Common** — Slack notification on failure, `pipeline-failure-check`, `generate-ci-badge`.

### Cluster cleanup and deprovisioning

**Default on a fully green run** — If the `PipelineRun` finishes with status **Completed** (provision, install, and tests all succeeded; nothing left the pipeline in a failed aggregate state), Hive **`single`** and **`multi`** pipelines **tear down** the cluster(s) in `finally` via `delete-cluster` (spoke then hub on multi). No extra action is required.

**Keeping clusters after success** — Set pipeline param `force-skip-cleanup` to `"true"` on the `PipelineRun` (several schedules in `values.yaml` do this for faster reruns or investigation). That **skips** the `finally` delete tasks for Hive flavors only; clusters remain until something else removes them.

**Hive safety net (8 hours)** — Every Hive `ClusterDeployment` created by `provision-cluster` is annotated with `hive.openshift.io/delete-after: "8h"`. Hive deprovisions the cluster automatically after that interval even when `force-skip-cleanup` is `"true"` or Tekton cleanup was skipped. Plan debugging windows accordingly; you do not get indefinite cloud VMs from the default provision path.

**Failed runs** — Cleanup tasks that depend on `tasks.status == Completed` do **not** run when install or tests fail, so clusters often **remain** after a red run (useful for must-gather and manual debugging). They are still subject to the same **8h** `delete-after` annotation unless you remove or change it on the `ClusterDeployment`.

**Hosted flavor** — Successful runs trigger `destroy-hosted-cluster` in `finally`; there is no `force-skip-cleanup` gate on that path today. Hosted lifecycle details may differ from Hive once HyperShift provisioning is fully implemented.

---

## Diverging from defaults per pattern

Defaults minimize duplication; each pattern under `qeCIPipelines.patterns` can narrow or override any axis.

### Platform

Set a `platforms` map on the pattern. **Only listed platforms** get pipelines. Keys match `defaults.platforms` (`aws`, `gcp`, `azure`). Values can be empty maps (`aws:`) to inherit region/baseDomain from defaults for that key—but you must still list the platform if you want it.

```yaml
qeCIPipelines:
  patterns:
    ansible-edge:
      platforms:
        aws:
```

Omit `platforms` entirely to use every platform defined in `defaults.platforms`.

### OCP version

Set `ocp_versions` on the pattern (list or map). Omit to use `defaults.ocp_versions`.

```yaml
    medical-diag:
      ocp_versions:
        - "4.20"
        - "4.21"
```

### Flavor

Set `flavors` as a **list** (enable those flavors with empty config) or a **map** (per-flavor options).

```yaml
    mcg:
      flavors:
        single:
          clusterGroup: standalone
        multi:
        # hosted omitted → no hosted pipeline for mcg
```

Omit `flavors` to use all entries from `defaults.flavors`.

To expose only one flavor, list or map only that key—other default flavors are not included.

### Git source per pattern

```yaml
    layered-zero:
      repo: https://github.com/example/layered-zero-trust.git
      revision: pipeline_test
```

Overrides apply as pipeline param defaults; runs can still override via `pattern-repo-url` / `pattern-repo-revision` on the `PipelineRun`.

---

## Secrets in pipelines

Some patterns need files at install time (extra values, manifests, SSH keys). The chart wires these as **optional Tekton workspaces** on `install-pattern`, not as Kubernetes env vars in the chart.

### Declaring secrets (values)

Under the pattern:

```yaml
pipelines:
  patterns:
    ansible-edge:
      secrets:
        - aeg-secret-values-file
        - aeg-aap-manifest-file
        - aeg-aap-ssh-file
```

Entries are either a string (Secret name) or an object with `name:`.

Helm validates:

- No duplicate secrets for one pattern.
- No two different secret names mapping to the same workspace name.

### Creating secrets on the cluster

Create `Secret` objects in **`qeCIPipelines.defaults.namespace`** before running the pipeline. The Secret **name** must match the values entry. Example comments in `values.yaml`:

```bash
oc create secret generic aeg-secret-values-file \
  -n <qeCIPipelines.defaults.namespace> \
  --from-file=values-secret.yaml=path/to/values-secret.yaml
```

### Workspace binding

- Workspace name = secret name with **underscores replaced by hyphens** (DNS-1123), truncated to 63 characters.
- Generated pipelines declare one workspace per pattern secret.
- `install-pattern` mounts them as `values-secret-0`, `values-secret-1`, … and copies file contents into the task home directory so pattern `values-secrets.yaml` can reference them.

### Manual `PipelineRun`

When starting a run yourself, bind each secret workspace in addition to `shared-data`:

```yaml
workspaces:
  - name: shared-data
    volumeClaimTemplate: # ...
  - name: aeg-secret-values-file   # hyphenated name
    secret:
      secretName: aeg-secret-values-file
```

Scheduled runs (below) auto-attach workspaces for secrets belonging to the pipeline’s pattern (longest matching pattern prefix on the pipeline name).

---

## Scheduled pipeline runs

File: `templates/pipelines/standard-schedules.yaml`. Enabled when `qeCIPipelines.schedules` is non-empty.

For each schedule entry, the chart creates:

1. A **ConfigMap** holding a `PipelineRun` manifest (`pipelinerun.yaml`).
2. A **CronJob** that runs `oc create -f` that manifest on the cron schedule.

### `scheduleDefaults`

Under `qeCIPipelines.scheduleDefaults` (merged per entry):

| Field | Typical purpose |
|-------|------------------|
| `suspend` | Pause all schedules when `true`. |
| `concurrencyPolicy` | Default `Forbid` — skip a new run if the previous is still active. |
| `successfulJobsHistoryLimit` / `failedJobsHistoryLimit` | CronJob history retention. |
| `workspaceStorage` | PVC size for `shared-data` on scheduled runs. |
| `timeout` / `taskTimeout` / `finallyTimeout` | Tekton `PipelineRun` timeout fields. |
| `triggerImage` | Image for the CronJob container (defaults to `toolsImage`). |

### Per-schedule entries

```yaml
qeCIPipelines:
  schedules:
    - pipeline: mcg-aws-4-21-multi
      cron: "0 6 * * 1"
      params:
        - name: force-skip-cleanup
          value: true
    - pipeline: ansible-edge-aws-4-21-single
      cron: "0 6 * * 3"
      timeout: 4h
      taskTimeout: 3h
      finallyTimeout: 30m
```

- **`pipeline`** — Must match an existing generated pipeline name.
- **`cron`** — Standard cron syntax; **UTC**.
- **`params`** — Optional `PipelineRun` param overrides.
- Any `scheduleDefaults` field can be overridden per entry (`suspend`, `concurrencyPolicy`, timeouts, storage, …).

CronJob name: `schedule-<pipeline-name>` (truncated to 63 characters). Scheduled runs use the `pipeline` ServiceAccount and label `pipelines.cluster-provisioning/schedule: "true"`.

Pattern secrets for that pipeline are injected into the embedded `PipelineRun` the same way as in the generated `Pipeline` spec.

---

## Cluster identity and reuse

### Cluster name suffix

Hive provisioning builds the `ClusterDeployment` name from pattern, platform, OCP version, cluster role, flavor, and a **suffix**:

```text
<pattern>-<platform>-<ocp-version>-<role>-<flavor>-<suffix>
```

- **Default (`cluster-name-postfix` empty)** — Suffix is the part of `$(context.pipelineRun.name)` after `$(context.pipeline.name)-` (the random segment from `generateName`, e.g. `srfbxw` in `layered-zero-aws-4-21-single-srfbxw`). If the run name does not match that pattern, the first five hex digits of the `PipelineRun` UID are used instead. Hub and spoke in **multi** share the same suffix for one run.
- **Override** — Set `cluster-name-postfix` on the `PipelineRun` to a 4–8 character `[a-z0-9]` value (typically the suffix from a prior run’s name). The run targets that `ClusterDeployment`: `oc apply` waits until Ready again (reuse). Concurrent runs with the **same** override still race on the same cluster.

Re-applying the same `ClusterDeployment` name does not create a second cluster; an existing deployment is waited on again.

### Tradeoffs

**Pros**

- Concurrent runs of the same pipeline no longer collide on the default suffix.
- Intentional reuse: set `cluster-name-postfix` to the random suffix from a prior `PipelineRun` name (same token as the end of the cluster name).

**Cons**

- A retry with an empty postfix provisions a **new** cluster unless you pass the previous suffix.
- Concurrent runs with the same postfix override can still interleave install/test and secret updates.
- More unique clusters per schedule increases provision cost unless `finally` cleanup runs.

Mitigations: use `concurrencyPolicy: Forbid` on schedules when overlap is still a concern; pass `cluster-name-postfix` for deliberate reuse; use `force-skip-cleanup` only when keeping a cluster for investigation.

---

## Related chart resources

Brief pointers for operators:

| Resource | Role |
|----------|------|
| `qeCIPipelines.defaults.namespace` | Namespace for Pipelines, Tasks, PipelineRuns, Hive `ClusterDeployment`s, and pattern Secrets. |
| `serviceAccount` / RBAC | Provisioner identity for Hive, secrets, and cluster operations. |
| `externalSecrets` + `platform-creds` / `global-pull-secret` | Cloud and pull credentials consumed during provision. |
| `hypershift` / `hcpImage` | Hosted-cluster flavor configuration. |
| `hive` | Default replica counts where metadata does not override. |

Task implementations live under `templates/tasks/`; flavor-specific pipeline fragments under `templates/pipelines/_pipeline-*.tpl`.

---

## Quick reference: values → pipelines

```yaml
pipelines:
  defaults:
    platforms: { aws: { region: ..., baseDomain: ... } }
    ocp_versions: ["4.18", "4.20", "4.21"]
    flavors:
      single: { clusterGroup: hub }
      multi: { clusterGroup: hub }
      hosted: { clusterGroup: hub }
  imageSets:
    "4.21": img4.21.6-x86-64-appsub
  patterns:
    my-pattern:
      repo: https://github.com/org/pattern.git
      revision: main
      platforms: { aws: {} }      # optional subset
      ocp_versions: ["4.21"]      # optional subset
      flavors: { single: {} }       # optional subset + clusterGroup
      secrets: [my-secret-name]   # optional
  scheduleDefaults: { ... }
  schedules:
    - pipeline: my-pattern-aws-4-21-single
      cron: "0 6 * * 1"
```

After `helm upgrade`, list pipelines with:

```bash
oc get pipeline -n <qeCIPipelines.defaults.namespace> -l pattern.name=my-pattern
```
