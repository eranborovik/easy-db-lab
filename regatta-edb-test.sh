#!/usr/bin/env bash
CLUSTER_DIR="clusters/regatta-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$CLUSTER_DIR"
bin/create-easy-db-lab-wrapper "$CLUSTER_DIR"
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
# $EDB up
# $EDB kit install regatta \
#   --namespace regatta \
#   --operator-image 694992585570.dkr.ecr.us-west-2.amazonaws.com/reg-k8s/operator:26.0.0.789 \
#   --regatta-repo 694992585570.dkr.ecr.us-west-2.amazonaws.com/reg-k8s/regatta \
#   --version 26.0.0.789
# $EDB regatta start

echo EDB="$CLUSTER_DIR/easy-db-lab"
### Specifying a Regatta ECR image
