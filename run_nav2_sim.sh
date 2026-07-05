#!/usr/bin/env bash
set -euo pipefail

IMAGE="ros2-nav2-humble:local"
CONTAINER_NAME="ros2_nav2_humble_sim"

if ! sudo docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "Image $IMAGE not found. Run ./build_image.sh first." >&2
  exit 1
fi

xhost +local:docker >/dev/null 2>&1 || true

sudo docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true

sudo docker run --rm -it \
  --name "$CONTAINER_NAME" \
  --net=host \
  --ipc=host \
  --privileged \
  -e DISPLAY="${DISPLAY:-:0}" \
  -e QT_X11_NO_MITSHM=1 \
  -e TURTLEBOT3_MODEL=waffle \
  -e GAZEBO_MODEL_DATABASE_URI= \
  -e GAZEBO_MODEL_PATH=/opt/ros/humble/share/turtlebot3_gazebo/models:/usr/share/gazebo-11/models \
  -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
  "$IMAGE" \
  bash -lc 'source /opt/ros/humble/setup.bash && ros2 launch nav2_bringup tb3_simulation_launch.py headless:=False'
