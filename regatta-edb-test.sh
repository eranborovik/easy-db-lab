#!/usr/bin/env bash

if [[ "$1" == "--help" || "$1" == "-h" ]]; then
  cat <<'USAGE'
Usage: regatta-edb-test.sh [options]

Options:
  --db-count COUNT                 Number of database nodes (default: 1)
  --db-instance-type TYPE          Database node instance type (default: r6id.4xlarge)
  --cluster-dir DIR                Cluster workspace directory (default: clusters/regatta-YYYYMMDD-HHMMSS)
  --app-count COUNT                Number of application/client nodes (default: 0)
  --app-instance-type TYPE         Application/client node instance type (default: c6i.4xlarge)
  --control-instance-type TYPE     Control node instance type (default: m5d.2xlarge)
  -h, --help                       Show this help text
USAGE
  exit 0
fi

DB_COUNT=1
DB_INSTANCE_TYPE="r6id.4xlarge"
CLUSTER_DIR="${CLUSTER_DIR:-}"
APP_COUNT=0
APP_INSTANCE_TYPE="c6i.4xlarge"
CONTROL_INSTANCE_TYPE="m5d.2xlarge"

require_value() {
  local option="$1"
  local value="${2:-}"

  if [[ -z "$value" || "$value" == --* ]]; then
    echo "Missing value for $option" >&2
    echo "Run $0 --help for usage." >&2
    exit 1
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      "$0" --help
      exit 0
      ;;
    --db-count)
      require_value "$1" "${2:-}"
      DB_COUNT="$2"
      shift 2
      ;;
    --db-count=*)
      DB_COUNT="${1#*=}"
      require_value "--db-count" "$DB_COUNT"
      shift
      ;;
    --db-instance-type)
      require_value "$1" "${2:-}"
      DB_INSTANCE_TYPE="$2"
      shift 2
      ;;
    --db-instance-type=*)
      DB_INSTANCE_TYPE="${1#*=}"
      require_value "--db-instance-type" "$DB_INSTANCE_TYPE"
      shift
      ;;
    --cluster-dir)
      require_value "$1" "${2:-}"
      CLUSTER_DIR="$2"
      shift 2
      ;;
    --cluster-dir=*)
      CLUSTER_DIR="${1#*=}"
      require_value "--cluster-dir" "$CLUSTER_DIR"
      shift
      ;;
    --app-count)
      require_value "$1" "${2:-}"
      APP_COUNT="$2"
      shift 2
      ;;
    --app-count=*)
      APP_COUNT="${1#*=}"
      require_value "--app-count" "$APP_COUNT"
      shift
      ;;
    --app-instance-type)
      require_value "$1" "${2:-}"
      APP_INSTANCE_TYPE="$2"
      shift 2
      ;;
    --app-instance-type=*)
      APP_INSTANCE_TYPE="${1#*=}"
      require_value "--app-instance-type" "$APP_INSTANCE_TYPE"
      shift
      ;;
    --control-instance-type)
      require_value "$1" "${2:-}"
      CONTROL_INSTANCE_TYPE="$2"
      shift 2
      ;;
    --control-instance-type=*)
      CONTROL_INSTANCE_TYPE="${1#*=}"
      require_value "--control-instance-type" "$CONTROL_INSTANCE_TYPE"
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Run $0 --help for usage." >&2
      exit 1
      ;;
  esac
done

# Use --cluster-dir if provided, else CLUSTER_DIR from the environment,
# else default to a timestamped directory under clusters/regatta-YYYYMMDD-HHMMSS.
CLUSTER_DIR="${CLUSTER_DIR:-clusters/regatta-$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$CLUSTER_DIR"

# Make sure the cluster directory is an absolute path so that the "echo EDB=..." works everywhere
CLUSTER_DIR=$(cd "$CLUSTER_DIR" && pwd)

WRAPPER_SCRIPT="bin/create-easy-db-lab-wrapper"
if [[ ! -e "$WRAPPER_SCRIPT" ]]; then
  WRAPPER_SCRIPT="$HOME/git/easy-db-lab/bin/create-easy-db-lab-wrapper"
fi
"$WRAPPER_SCRIPT" "$CLUSTER_DIR"

EDB="$CLUSTER_DIR/easy-db-lab"

#$EDB init regatta-multi \
#	--clean \
#  --db.count "$DB_COUNT" \
#	--db.instance-type r6id.4xlarge \
#	--ami ami-09977077680cafe45 \
#	--ebs.type io2 \
#	--ebs.size 100 \
#	--ebs.iops 4000 \
#	--ebs.throughput 300

$EDB init regatta-${USER} \
  --clean \
  --db.count "$DB_COUNT" \
  --db.instance-type "$DB_INSTANCE_TYPE" \
  --app.count "$APP_COUNT" \
  --app.instance-type "$APP_INSTANCE_TYPE" \
  --control.instance-type "$CONTROL_INSTANCE_TYPE" \
  --ami ami-09977077680cafe45 \
  --ebs.type io2 \
  --ebs.size 100 \
  --ebs.iops 4000 \
  --ebs.throughput 300

#  --db.instance-type r8id.8xlarge \

$EDB up

echo
echo "Copy the following lines into your shell to set up the environment for using the Regatta cluster:"
echo EDB="$CLUSTER_DIR/easy-db-lab"
echo "source $CLUSTER_DIR/env.sh"


# The rest of the commands here should be executed only after the ecr-secret and RDB environment
# (the storage device) are set up

echo "Make sure to set up the ecr-secret and RDB environment before proceeding."
# $EDB kit install regatta
# $EDB regatta start

### Specifying a Regatta ECR image
# $EDB kit install regatta \
#   --namespace regatta \
#   --operator-image 694992585570.dkr.ecr.us-west-2.amazonaws.com/reg-k8s/operator:26.0.0.789 \
#   --regatta-repo 694992585570.dkr.ecr.us-west-2.amazonaws.com/reg-k8s/regatta \
#   --version 26.0.0.789 \
#   --rdb-threads 4
# $EDB regatta start --rdb-threads 4

echo EDB="$CLUSTER_DIR/easy-db-lab"
### Specifying a Regatta ECR image
