#!/usr/bin/env bash
set -eo pipefail

source /opt/ros/humble/setup.bash
set -u

ros2 run tf2_ros static_transform_publisher \
  --x -0.064 --y 0.0 --z 0.235 \
  --roll 0.0 --pitch 0.0 --yaw 0.0 \
  --frame-id base_link \
  --child-frame-id mid360_link &

(
  until ros2 node list | grep -qx /rviz; do
    sleep 1
  done
  ros2 param set /rviz use_sim_time true >/dev/null 2>&1 || true
) &

wait
