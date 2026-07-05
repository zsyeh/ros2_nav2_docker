#!/usr/bin/env bash
set -euo pipefail

FASTLIO_WS="${FASTLIO_WS:-/home/eh/livo_ws}"
FASTLIO_LAUNCH="${FASTLIO_LAUNCH:-mapping_mid360.launch}"
RUN_RVIZ="${RUN_RVIZ:-false}"

if [ ! -f /opt/ros/noetic/setup.bash ]; then
  echo "ROS Noetic not found at /opt/ros/noetic/setup.bash" >&2
  exit 1
fi

if [ ! -f "$FASTLIO_WS/devel/setup.bash" ]; then
  echo "FAST_LIO workspace not built: $FASTLIO_WS/devel/setup.bash" >&2
  exit 1
fi

source /opt/ros/noetic/setup.bash
source "$FASTLIO_WS/devel/setup.bash"

if ! pgrep -x roscore >/dev/null 2>&1; then
  roscore >/tmp/fastlio_roscore.log 2>&1 &
  sleep 3
fi

roslaunch fast_lio "$FASTLIO_LAUNCH" rviz:="$RUN_RVIZ"
