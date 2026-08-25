#!/usr/bin/env bash
CLUSTER_DIR="clusters/regatta-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$CLUSTER_DIR"
bin/create-easy-db-lab-wrapper "$CLUSTER_DIR"
EDB="$CLUSTER_DIR/easy-db-lab"
echo EDB="$CLUSTER_DIR/easy-db-lab"
$EDB init regatta-debug \
	--db.count 1 \
	--db.instance-type m6id.8xlarge
$EDB up
$EDB kit install regatta
$EDB regatta start

### Specifying a Regatta ECR image
# $EDB kit install regatta \
#   --namespace regatta \
#   --version 26.0.0.816 \
#   --operator-image 611434859749.dkr.ecr.us-east-1.amazonaws.com/kubernetes/operator:26.0.0.816 \
#   --regatta-repo 611434859749.dkr.ecr.us-east-1.amazonaws.com/kubernetes/regatta
