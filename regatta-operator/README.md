# Regatta Operator on easy-db-lab (EDL)

This directory contains Kubernetes manifests, CRDs, RBAC rules, and sample configurations for running the **Regatta Distributed Database** and **Regatta Operator** inside [easy-db-lab (`EDL`)](https://github.com/rustyrazorblade/easy-db-lab) ephemeral test clusters.

---

## Directory Overview

```
regatta-operator/
├── crd/
│   └── regatta.dev_regattaclusters.yaml # CustomResourceDefinition for RegattaCluster
├── manager/
│   └── deployment.yaml                  # Operator deployment definition
├── rbac/
│   ├── serviceaccount.yaml              # Operator ServiceAccount
│   ├── role.yaml                        # Namespace-scoped RBAC permissions
│   ├── rolebinding.yaml                 # RoleBinding for operator ServiceAccount
│   └── clusterrole-readonly.yaml        # Read-only cluster role for node discovery
└── samples/
    ├── regatta-sample.yaml              # Basic sample RegattaCluster manifest
    ├── regatta-production.yaml          # Full multi-node sample with sizing
    ├── regatta-static-storage.yaml      # Static PV allocation sample
    ├── regatta-debug.yaml               # Diagnostic configuration
    ├── edl-pv.yaml                      # Template PV definitions for EDL nodes
    ├── sysbench-pod.yaml                # Sysbench benchmark client pod
    └── qa-test-pod.yaml                 # QA / integration test client pod
```

---

## Architecture on EDL

Regatta runs inside EDL's lightweight K3s Kubernetes infrastructure:

1. **Storage Subsystem**:
   - **RDB Block Device**: Direct raw block storage via NVMe SSD / loop devices (`VolumeMode: Block`) mounted onto `/dev/nvmeXn1`.
   - **SM / RDB Repo & Logs**: Local filesystem volumes (`VolumeMode: Filesystem`) located at `/mnt/db1/<kit-name>/...`.
   - Host directories are initialized via a one-shot DaemonSet (`init-dirs-daemonset.yaml`) targeting all DB nodes.

2. **Compute & Thread Sizing**:
   - Dynamic CPU and RAM autodiscovery sizes Sequencer and RDB thread budgets to ~80% of node capacity:
     - **Nodes > 18 cores**: Sequencer = 4 (SM CPU = 6), RDB CPU = $\lfloor 0.80 \times \text{CPU} \rfloor - 6$.
     - **9–18 cores (e.g. 16 cores)**: Sequencer = 2 (SM CPU = 4), RDB CPU = $\lfloor 0.80 \times \text{CPU} \rfloor - 4$.
     - **$\le 8$ cores**: Sequencer = 1 (SM CPU = 3), RDB CPU = $\max(1, \text{CPU} - 3)$.
     - **RAM**: $80\%$ of total node memory allocated to RDB `ram_MB`.

3. **Networking & Discovery**:
   - **Cluster-Internal DNS**:
     - SM: `regatta-sm.<namespace>.svc.cluster.local:8840`
     - RDB Service: `regatta-rdb.<namespace>.svc.cluster.local:8850`
     - RDB Replicas: `regatta-rdb-<index>.<namespace>.svc.cluster.local:8850`
   - **External NodePort Exposure**:
     - SM HTTP: `<db-node-ip>:30840`
     - RDB Native: `<db-node-ip>:30850`

---

## Prerequisites & EDL Setup

### 1. Provisioning Instances

Ensure worker/DB nodes provide local NVMe block devices (e.g. AWS `m6id.8xlarge`, GCP `n2d-standard-32` with Local SSDs).

### 2. ECR Secret Injection

When pulling images from private registries (e.g., AWS ECR), ensure `ecr-secret` is present in the target namespace before applying cluster resources:

```bash
kubectl create secret docker-registry ecr-secret \
  --docker-server=694992585570.dkr.ecr.us-west-2.amazonaws.com \
  --docker-username=AWS \
  --docker-password=$(aws ecr get-login-password --region us-west-2) \
  -n regatta
```

---

## Usage via EDL Kit CLI

The easiest way to run Regatta is via the EDL `regatta` kit:

```bash
# 1. Install CRD, Operator, host directory preparation, and autodiscovery
easy-db-lab kit install regatta \
  --size 500Gi \
  --rdb-device /dev/nvme1n1 \
  --version 26.0.0.789

# 2. Start Regatta cluster (creates Local PVs, applies RegattaCluster CR, starts NodePort)
easy-db-lab regatta start

# 3. Stop Regatta cluster (preserves PV data for restart)
easy-db-lab regatta stop

# 4. Uninstall Regatta (cleans up CRs, PVCs, PVs, and host directories)
easy-db-lab regatta uninstall --force-uninstall
```

### Manual CLI Overrides

You can override auto-detected resources during install:

```bash
easy-db-lab kit install regatta \
  --rdb-threads 12 \
  --rdb-ram-mb 262144 \
  --sequencer-threads 4 \
  --shm-size 40Gi
```

---

## Direct Manifest Deployment (Without EDL Kit)

If managing manifests directly using `kubectl`:

```bash
# 1. Create Namespace & RBAC
kubectl create namespace regatta
kubectl apply -f rbac/serviceaccount.yaml -n regatta
kubectl apply -f rbac/role.yaml -n regatta
kubectl apply -f rbac/rolebinding.yaml -n regatta
kubectl apply -f rbac/clusterrole-readonly.yaml

# 2. Install CRD
kubectl apply -f crd/regatta.dev_regattaclusters.yaml

# 3. Deploy Operator
kubectl apply -f manager/deployment.yaml -n regatta
kubectl rollout status deployment/regatta-operator -n regatta --timeout=120s

# 4. Create PersistentVolumes on DB nodes
kubectl apply -f samples/edl-pv.yaml

# 5. Apply RegattaCluster Custom Resource
kubectl apply -f samples/regatta-sample.yaml -n regatta
```

---

## Running Benchmarks and Tests

Launch benchmark or test client pods directly inside the K3s network:

- **Sysbench**:

  ```bash
  kubectl apply -f samples/sysbench-pod.yaml -n regatta
  ```

- **QA / Test Client Pod**:

  ```bash
  kubectl apply -f samples/qa-test-pod.yaml -n regatta
  ```
