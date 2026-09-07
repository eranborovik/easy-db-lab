#!/usr/bin/env bash

regatta_rdb_threads() {
  local node_cpu="$1"
  local sm_cpu="$2"
  local db_nodes_count="$3"
  local app_nodes_count="$4"

  if [ "$db_nodes_count" -gt 1 ]; then
    echo "$node_cpu"
  elif [ "$app_nodes_count" -gt 0 ]; then
    echo $(( node_cpu - sm_cpu ))
  else
    awk -v c="$node_cpu" -v sm="$sm_cpu" 'BEGIN {
      budget = int(c * 0.8);
      rdb = budget - sm;
      if (c >= 9) {
        if (rdb < 6) rdb = 6;
      } else {
        if (rdb < 1) rdb = int(c - sm);
        if (rdb < 1) rdb = 1;
      }
      print rdb;
    }'
  fi
}