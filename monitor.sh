#!/bin/bash

set -e

slack_template='{"text": "the auto-scaling group `\($asg_name)` has \($n_suspended) suspended process(es): `\($suspended_processes)`", "username": "asg monitor", "icon_emoji": ":ghost:"}'

for asg_name in ${ASG_NAMES}; do
  echo "checking ${asg_name}"

  suspended_processes="$(
    aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "${asg_name}" \
    | jq -c '.AutoScalingGroups[].SuspendedProcesses|map(.ProcessName)'
  )"
  n_suspended="$(
    aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "${asg_name}" \
    | jq '.AutoScalingGroups[].SuspendedProcesses|length'
  )"

  re='^[0-9]+$'
  if ! [[ $n_suspended =~ $re ]]; then
     echo "error: expected a number, got '${n_suspended}'" >&2
     exit 1
  fi

  if (( ${n_suspended} > 0 )); then
    echo "we have suspended processes, sending message to slack"

    data="$(
      echo '{}' | jq -c \
        --arg asg_name "${asg_name}" \
        --arg n_suspended "${n_suspended}" \
        --arg suspended_processes "${suspended_processes}" \
        "${slack_template}"
    )"
    curl -X POST \
         -H 'Content-type: application/json' \
         --data "${data}" \
         --silent \
         --show-error \
         --fail \
         ${SLACK_WEBHOOK_URL} \
      > /dev/null
  fi
done
