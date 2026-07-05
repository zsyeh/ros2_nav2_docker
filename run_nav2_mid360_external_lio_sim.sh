#!/usr/bin/env bash
set -euo pipefail

IMAGE="ros2-nav2-humble:local"
CONTAINER_NAME="ros2_nav2_mid360_lio_sim"
WORKDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! sudo docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "Image $IMAGE not found. Run ./build_image.sh first." >&2
  exit 1
fi

for required in waffle_mid360.model nav2_mid360_lio_params.yaml nav2_mid360_external_lio_launch.py lio_container_helpers.sh; do
  if [ ! -f "$WORKDIR/$required" ]; then
    echo "Missing $WORKDIR/$required" >&2
    exit 1
  fi
done

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
  -v "$WORKDIR:/root/nav2_mid360:ro" \
  "$IMAGE" \
  bash -lc 'source /opt/ros/humble/setup.bash; /root/nav2_mid360/lio_container_helpers.sh & ros2 launch /root/nav2_mid360/nav2_mid360_external_lio_launch.py'
