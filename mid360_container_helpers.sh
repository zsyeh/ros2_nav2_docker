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

(
  until ros2 topic list | grep -qx /odom; do
    sleep 1
  done
  timeout 60 ros2 topic echo --once /odom >/dev/null 2>&1 || true
  sleep 5
  ros2 topic pub --times 5 -r 2 /initialpose geometry_msgs/msg/PoseWithCovarianceStamped \
    "{header: {frame_id: map}, pose: {pose: {position: {x: -2.0, y: -0.5, z: 0.0}, orientation: {z: 0.0, w: 1.0}}, covariance: [0.25, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.25, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.068]}}"
) &

wait
