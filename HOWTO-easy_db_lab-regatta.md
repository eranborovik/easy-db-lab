# How to run Regatta on Easy DB Lab (EDB) from start to finish
- Hard work done by Orr Amsalem
- This doc summary of that work by mh
- 2026-08-31


## Background

AMI: Amazon Machine Image

ECR: Elastic Container Registry

EDB: Easy DB Lab

If you don't have any experience with Kubernetes, it's highly recommended that you read a backgrounder first.

You will probably need `kubectl`.  Install with `sudo dnf install -y kuberctl`.

## Overview

Steps:
1. Get Easy-DB-Lab if you don't already have it
2. Setup AWS creds
3. Tell EDB that there are new AWS creds
4. Build the cluster and get Kubernetes running
5. Prepare the cluster node(s) for running RDB
6. Install RDB

## Authenticate AWS (daily)

Go to [www.google.com](https://www.google.com/)

Choose 3x3 dots, select `AWS SSO`, choose `sandbox-clusters`, choose `Access keys`, choose `Option 2`.
```
mkdir ~/.aws
cat > ~/.aws/credentials
<paste creds>
^D
chmod 600 ~/.aws/credentials
```
Choose `AdministratorAccess` to open the console.  Go to `EC2`, either in `Recently used` or through the menu by choosing `All services`, then `EC2`.  Select region `us-west-2` in the top right corner.

AWS console: https://us-west-2.console.aws.amazon.com/ec2/home?region=us-west-2#Instances:

## Easy DB LAB: git and build
```
cd git
git clone git@github.com:eranborovik/easy-db-lab.git
cd git/easy-db-lab
git checkout orr/edl-regatta
git fetch
git pull
./gradlew installDist
```

## Easy DB Lab: Setup creds (daily)
Replace the default profile of EDL:

Rename `~/.easy-db-lab/profile/default` to a backup folder.

Run `easy-db-lab setup` - skip the AMI creation.  This gives EDB access to the AWS creds.

The AWS Profile name is the name in square brackets in the first line of `~/.aws/credentials`.  If asked: these are some of the answers:
```
What's your email? []: mh@regatta.dev
What AWS region do you use? [us-west-2]:
AWS Profile name (or press Enter to enter credentials manually) []: 694992585570_AdministratorAccess
```
Delete any stale buckets

## Build a remote server and start Easy DB Lab kubernetes and pods
Either run `regatta-edb-test.sh` as is, or edit it first, or run it command-by-command.

These commands do this:

- Create a workspace directory to store the state files for the server and kubernetes
- Builds a `EDB` convenience wrapper to use that workspace
- Set a session $EDB alias with today's workspace
- Inits a new cluster with `$EDB init ...`
- Spins up infra with `$EDB up`
- Installs regatta with `$EDB kit install regatta ...`

Example commands (if given by hand):
```
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
In every shell you plan to run from, it is advisable to do:
```
EDB="$HOME/git/easy-db-lab/clusters/regatta-<date>-<time>/easy-db-lab"
source $EDB/env.sh
```
The `env.sh` does a lot.  It sets up the environment so that you can `ssh control0` and `ssh db0`.  It also sets up `kubectl` to know where the `kubeconfig` is.

## Setup control node

### SSH into control0
```
ssh control0
```

### Create ecr-secret to be able to pull images
These next few code blocks are intended to be copy-pasted into the shell on `control0`.
```
ACCOUNT_ID="694992585570"
REGION="us-west-2"
NAMESPACE="regatta"
```
#### 1. Ensure the namespace exists
```
KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | \
  KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl apply -f -
```
#### 2. Get the ECR password token and create/update the Kubernetes Secret
Don't miss the `TOKEN=` first line below.
```
TOKEN=$(aws ecr get-login-password --region ${REGION})
KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl create secret docker-registry ecr-secret \
  --namespace ${NAMESPACE} \
  --docker-server="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com" \
  --docker-username=AWS \
  --docker-password="${TOKEN}" \
  --dry-run=client -o yaml | \
  KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl apply -f -
```
## Setup DB node

### SSH into db0 and create the RDB environment
```
ssh db0
sudo mkdir -p /mnt/db1/regatta
sudo chmod -R 777 /mnt/db1/regatta
sudo fallocate -l 500G /mnt/db1/regatta-block-0
sudo losetup -f --show --direct-io=on /mnt/db1/regatta-block-0
```
### Start regatta cluster
```
$EDB kit install regatta   --namespace regatta   --regatta-repo "694992585570.dkr.ecr.us-west-2.amazonaws.com/reg-k8s/regatta" --version "26.0.0.789"  --operator-image "694992585570.dkr.ecr.us-west-2.amazonaws.com/reg-k8s/operator:26.0.0.789" --size "500Gi" --rdb-device "/dev/loop3"

$EDB regatta start
```

## Running a client pod
The commands below presume that you have done `source env.sh` above.

In the Kubernetes world, kind-of-everything is expected to run in a pod running in the same Kubernetes cluster.  It's thought of a "unnatural" for apps to run directly on the host node (or on bare-metal or directly on servers anywhere else, although this is clearly possible).

To create Orr's test-runner-pod, do this:
```
kubectl apply -n regatta -f qa-test-pod.yaml
```
This will create a pod that has a `~/cluster/bin` with useful commands like client_cli.
Use this command to log into it:
```
kubectl exec -n regatta -it test-runner-pod -- bash
```
For example, this should work:
```
REGATTA_PASS='RegattaDefault1234!' ~/cluster/bin/client_cli --user admin --url regatta-rdb-0:8850
```
Use `kubectl cp` or a tar-pipe to get other files into the test-runner-pod:
```
cd git
tar cf - bare-metal | kubectl exec -i -n regatta test-runner-pod -- tar xvf - -C /home/regatta
tar cf - sysbench_regatta/src/sysbench sysbench_regatta/src/lua sysbench_regatta/third_party/regatta | \
  kubectl exec -i -n regatta test-runner-pod -- tar xvf - -C /home/regatta
```
