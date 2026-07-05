#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="${CONTAINER_NAME:-ros2_nav2_mid360_lio_sim}"
INPUT_ODOM_TOPIC="${INPUT_ODOM_TOPIC:-/fastlio/Odometry}"
OUTPUT_ODOM_TOPIC="${OUTPUT_ODOM_TOPIC:-/Odometry}"
MAP_FRAME="${MAP_FRAME:-map}"
BASE_FRAME="${BASE_FRAME:-base_link}"

sudo docker exec -it "$CONTAINER_NAME" bash -lc "\
  source /opt/ros/humble/setup.bash; \
  python3 /root/nav2_mid360/fastlio_odom_to_nav2_tf.py \
    --ros-args \
    -p input_odom_topic:=${INPUT_ODOM_TOPIC} \
    -p output_odom_topic:=${OUTPUT_ODOM_TOPIC} \
    -p map_frame:=${MAP_FRAME} \
    -p base_frame:=${BASE_FRAME}"
