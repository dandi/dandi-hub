#!/bin/sh

set -eux

# EFS_PERSIST_MNT = "/mnt/efs-persist"
EFS_PERSIST_MNT="/tmp/efs-script-dump"
EFS_HOME="$EFS_PERSIST_MNT/home"

du -sh $EFS_HOME/* | awk '{print $1, $2}' > $EFS_HOME/size_report.txt
cat $EFS_HOME/size_report.txt
