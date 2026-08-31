#!/usr/bin/env bash

if [[ "$1" == "--help" || "$1" == "-h" ]]; then
  echo "Usage: $0 [DB_COUNT [CLUSTER_DIR] ]"
  exit 0
fi

# Use first argument as the database count if there is a first argument,
# else default to one database.
DB_COUNT="${1:-1}"

# Use second argument as the cluster directory if there is a second argument,
# else use CLUSTER_DIR from the environment,
# else default to a timestamped directory under clusters/regatta-YYYYMMDD-HHMMSS
CLUSTER_DIR="${2:-${CLUSTER_DIR:-clusters/regatta-$(date +%Y%m%d-%H%M%S)}}"
mkdir -p "$CLUSTER_DIR"

# Make sure the cluster directory is an absolute path so that the "echo EDB=..." works everywhere
CLUSTER_DIR=$(cd "$CLUSTER_DIR" && pwd)

WRAPPER_SCRIPT="bin/create-easy-db-lab-wrapper"
if [[ ! -e "$WRAPPER_SCRIPT" ]]; then
  WRAPPER_SCRIPT="$HOME/git/easy-db-lab/bin/create-easy-db-lab-wrapper"
fi
"$WRAPPER_SCRIPT" "$CLUSTER_DIR"

EDB="$CLUSTER_DIR/easy-db-lab"

$EDB init regatta-multi \
	--clean \
	--ami ami-09977077680cafe45 \
	--ebs.type io2 \
	--ebs.size 100 \
	--ebs.iops 4000 \
	--ebs.throughput 300 \
	--db.count 3 \
	--db.instance-type r6id.4xlarge

$EDB init regatta-${USER} \
	--clean \
  --db.count "$DB_COUNT" \
  --db.instance-type r8id.8xlarge \
  --ami ami-09977077680cafe45 \
  --ebs.type io2 \
  --ebs.size 100 \
  --ebs.iops 4000 \
  --ebs.throughput 300

$EDB up

echo
echo "Copy the following lines into your shell to set up the environment for using the Regatta cluster:"
echo EDB="$CLUSTER_DIR/easy-db-lab"
echo "source $CLUSTER_DIR/env.sh"


# The rest of the commands here should be executed only after the ecr-secret and RDB environment
# (the storage device) are set up

# $EDB kit install regatta
# $EDB regatta start

### Specifying a Regatta ECR image
# $EDB kit install regatta \
#   --namespace regatta \
#   --operator-image 694992585570.dkr.ecr.us-west-2.amazonaws.com/reg-k8s/operator:26.0.0.789 \
#   --regatta-repo 694992585570.dkr.ecr.us-west-2.amazonaws.com/reg-k8s/regatta \
#   --version 26.0.0.789
# $EDB regatta start

echo EDB="$CLUSTER_DIR/easy-db-lab"
### Specifying a Regatta ECR image
