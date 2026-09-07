# How to run Regatta on Easy DB Lab (EDB) from start to finish
- Hard work done by Orr Amsalem
- This doc is a summary of that work by mh
- 2026-09-07


## 1. Background

Terminogoloy
- AMI: Amazon Machine Image
- ECR: Elastic Container Registry
- EDB: Easy DB Lab

If you don't have any experience with Kubernetes, it's highly recommended that you read a backgrounder first.

You will probably need `kubectl`.  Install with `sudo dnf install -y kubectl`.

## 2. Overview

Steps:
1. Get Easy-DB-Lab if you don't already have it
2. Setup AWS creds
3. Tell EDB that there are new AWS creds
4. Build the cluster and get Kubernetes running
5. Prepare the cluster node(s) for running RDB
6. Install RDB
7. Bring up a test pod
8. Log in to the test pod and run tests from there


## 3. Easy DB LAB: git and build
```bash
cd git
git clone git@github.com:eranborovik/easy-db-lab.git
cd easy-db-lab
git checkout mh
git fetch
git pull
./gradlew installDist
```

## 4. Install the AWS SSO on your WSL

Install the `aws` CLI:
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
unzip awscliv2.zip
sudo ./aws/install
```
If the `curl` command doesn't work, copy it from the company OneDrive here: `"...\Engineering\Projects\OLTP Results\Artifacts\2026-09-07 AWS Linux CLI\awscli-exe-linux-x86_64.zip"`
Steps:
1. Run `aws configure sso --use-device-code`.
2. For `SSO session name` give something like `reg-sso`
3. When asked for `SSO start URL` and `SSO region` use the values shown in the AWS access portal
4. For the rest of the setup, you can use the default values until you get to the stage that opens the browser and asks you to login
5. When prompted to, pick the `sandbox-clusters` account ID
6. Continue with default values until the end of the setup

Once the setup is done, set the profile for `edl`:

7. `vim ~/.aws/config`
8. Add a new profile section for `edl` -- copy the existing profile you just set up and replace the profile name and region.  When done, the file should look like this:
```
[sso-session reg-sso]
sso_start_url = https://identitycenter.amazonaws.com/ssoins-7223db127c184e2a
sso_region = us-east-1
sso_registration_scopes = sso:account:access

[profile AdministratorAccess-694992585570]
sso_session = reg-sso
sso_account_id = 694992585570
sso_role_name = AdministratorAccess
region = us-east-1

[profile edl]
sso_session = reg-sso
sso_account_id = 694992585570
sso_role_name = AdministratorAccess
region = us-west-2
```

## 5. Authenticate AWS (daily)

After you install the AWS SSO on your WSL, then all you need to do is `aws sso login --profile edl --use-device-code` every day.

### 5.1. Easy DB Lab: Setup creds (once only)
Replace the default profile of EDL:

Rename `~/.easy-db-lab/profile/default` to a backup folder.

Run `~/git/easy-db-lab/bin/easy-db-lab setup` - skip the AMI creation.  This gives EDB access to the AWS creds.

When asked: these are some of the answers:
```
What's your email? []: mh@regatta.dev
What AWS region do you use? [us-west-2]:
AWS Profile name (or press Enter to enter credentials manually) []: edl
```
Delete any stale buckets

## 6. Build a remote server and start Easy DB Lab kubernetes and pods
Either run `regatta-edb-test.sh` as is, or edit it first, or run it command-by-command.

Example runs:
```bash
~/git/easy-db-lab/regatta-edb-test.sh --db-count 3 --db-instance-type i4i.xlarge

~/git/easy-db-lab/regatta-edb-test.sh --db-count 1 --db-instance-type r8id.8xlarge
```
Run with `--help` to see all the options.

These commands do this:

- Create a workspace directory to store the state files for the server and kubernetes
- Builds a `EDB` convenience wrapper to use that workspace
- Set a session $EDB alias with today's workspace
- Inits a new cluster with `$EDB init ...`
- Spins up infra with `$EDB up`

`regatta-edb-test.sh` stops here to give you the ability to install the ecr secret (permission to download the container images) and to control control over the cluster to install

You still need to:
- Install regatta with `$EDB kit install regatta ...`
- Start the cluster with `$EDB regatta start`

Example commands (if given by hand):
```bash
EDB="$CLUSTER_DIR/easy-db-lab"
$EDB init regatta-orr \
  --db.count 1 \
  --db.instance-type r8id.8xlarge \
  --ami ami-09977077680cafe45 \
  --ebs.type io2 \
  --ebs.size 100 \
  --ebs.iops 4000 \
  --ebs.throughput 300
$EDB up
```
In every shell you plan to run from, it is advisable to do (or wherever your working directory is):
```bash
EDB="$HOME/git/easy-db-lab/clusters/regatta-<date>-<time>/easy-db-lab"
source .../env.sh
```
The `env.sh` does a lot.  It sets up the environment so that you can `ssh control0` and `ssh db0`.  It also sets up `kubectl` to know where the `kubeconfig` is.

## 7. Setup control node

### 7.1. SSH into control0
```bash
ssh control0
```

### 7.2. Create ecr-secret to be able to pull images
These next code block is intended to be copy-pasted into the shell on `control0`.

1. Ensure the namespace exists
2. Get the ECR password token and create/update the Kubernetes Secret

```bash
ACCOUNT_ID="694992585570"
REGION="us-west-2"
NAMESPACE="regatta"
KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | \
  KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl apply -f -
TOKEN=$(aws ecr get-login-password --region ${REGION})
KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl create secret docker-registry ecr-secret \
  --namespace ${NAMESPACE} \
  --docker-server="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com" \
  --docker-username=AWS \
  --docker-password="${TOKEN}" \
  --dry-run=client -o yaml | \
  KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl apply -f -
```
## 8. Setup DB node

### 8.1. SSH into db0 and create the RDB environment

This is needed only if you did not choose a `r8id.8xlarge` or `i4i.xlarge` for the RDB servers.
```bash
ssh db0
sudo mkdir -p /mnt/db1/regatta
sudo chmod -R 777 /mnt/db1/regatta
sudo fallocate -l 500G /mnt/db1/regatta-block-0
sudo losetup -f --show --direct-io=on /mnt/db1/regatta-block-0
```
### 8.2. Start regatta cluster
```bash
# Use this command for the servers that are not r8id.8xlarge and not i4i.xlarge
$EDB kit install regatta \
  --namespace regatta \
  --regatta-repo "694992585570.dkr.ecr.us-west-2.amazonaws.com/reg-k8s/regatta" \
  --version "26.0.0.789"  \
  --operator-image "694992585570.dkr.ecr.us-west-2.amazonaws.com/reg-k8s/operator:26.0.0.789" \
  --size "500Gi" \
  --rdb-device "/dev/loop3"

# If you are using a r8id.8xlarge, then use this command (--size and --rdb-device).
$EDB kit install regatta \
  --namespace regatta \
  --regatta-repo "694992585570.dkr.ecr.us-west-2.amazonaws.com/reg-k8s/regatta" \
  --version "26.0.0.789"  \
  --operator-image "694992585570.dkr.ecr.us-west-2.amazonaws.com/reg-k8s/operator:26.0.0.789" \
  --size "1.7Ti" \
  --rdb-device "/dev/nvme2n1"

# For i4i.xlarge
$EDB kit install regatta \
  --namespace regatta \
  --regatta-repo "694992585570.dkr.ecr.us-west-2.amazonaws.com/reg-k8s/regatta" \
  --version "26.0.0.789" \
  --operator-image "694992585570.dkr.ecr.us-west-2.amazonaws.com/reg-k8s/operator:26.0.0.789" \
  --size "872Gi" \
  --rdb-device "/dev/nvme2n1"

$EDB regatta start
```

Consider setting the version to `26.0.0.789-debug` if you need more insight into the goings-on inside the Regatta containers.  This should bring up containers with useful tools like `tar` and `less`.  The default image is stripped down to the bare minimum.

## 9. Running a client pod
The commands below presume that you have done `source env.sh` above.

In the Kubernetes world, kind-of-everything is expected to run in a pod running in the same Kubernetes cluster.  It's thought of a "unnatural" for apps to run directly on the host node (or on bare-metal or directly on servers anywhere else, although this is clearly possible).

### 9.1. Bring up a test pod

To create Orr's test-runner-pod, do this:
```bash
kubectl apply -n regatta -f qa-test-pod.yaml
```
This will create a pod that has a `~/cluster/bin` with useful commands like client_cli.

### 9.2. Log in to the test pod

Use this command to log into it:
```bash
kubectl exec -n regatta -it test-runner-pod -- bash
```

### 9.3. Run tests from the test pod

For example, this should work:
```bash
REGATTA_PASS='RegattaDefault1234!' ~/cluster/bin/client_cli --user admin --url regatta-sm:8840
```

### 9.4. Copying files to the test pod

Use `kubectl cp` or a tar-pipe to get other files into the test-runner-pod:
```bash
kubectl cp -n regatta /usr/bin/zstd test-runner-pod:/home/regatta/cluster/bin
kubectl cp -n regatta ~/git/bare-metal-*tar.zst test-runner-pod:/home/regatta
kubectl exec -i -n regatta test-runner-pod -- 'cd /home/regatta ; zstd -d < bare-metal-*tar.zst | tar xvf -'
pushd ~/git
kubectl exec -i -n regatta test-runner-pod -- mkdir /home/regatta/git
tar cf - sysbench_regatta/src/sysbench sysbench_regatta/src/lua sysbench_regatta/third_party/regatta | \
  kubectl exec -i -n regatta test-runner-pod -- tar xvf - -C /home/regatta/git
popd
```

## 10. Trying different configurations on the same server network

```bash
$EDB regatta uninstall
```
Follow this with a `$EDB kit install regatta`, and then the `$EDB regatta start`.

## 11. Cleanup
This kills the cluster and terminates all the servers.
```bash
$EDB down
```
Please do not forget this step.
