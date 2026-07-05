#!/usr/bin/env bash
set -euo pipefail

IMAGE="ros2-nav2-fastlio-humble:local"
CONTAINER_NAME="ros2_nav2_mid360_truth_reloc_sim"
WORKDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HEADLESS="${HEADLESS:-false}"
USE_RVIZ="${USE_RVIZ:-true}"
case "${HEADLESS,,}" in
  true|1|yes|on) HEADLESS_LAUNCH="True" ;;
  *) HEADLESS_LAUNCH="False" ;;
esac
case "${USE_RVIZ,,}" in
  false|0|no|off) USE_RVIZ_LAUNCH="False" ;;
  *) USE_RVIZ_LAUNCH="True" ;;
esac

if ! sudo docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "Image $IMAGE not found. Run ./build_fastlio_image.sh first." >&2
  exit 1
fi

for required in \
  waffle_mid360.model \
  nav2_mid360_fastlio_params.yaml \
  nav2_mid360_external_lio_launch.py \
  lio_container_helpers.sh \
  gazebo_truth_to_nav2_tf.py; do
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
  -e HEADLESS_LAUNCH="$HEADLESS_LAUNCH" \
  -e USE_RVIZ_LAUNCH="$USE_RVIZ_LAUNCH" \
  -e RMW_IMPLEMENTATION=rmw_cyclonedds_cpp \
  -e GAZEBO_MODEL_DATABASE_URI= \
  -e GAZEBO_MODEL_PATH=/opt/ros/humble/share/turtlebot3_gazebo/models:/usr/share/gazebo-11/models \
  -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
  -v "$WORKDIR:/root/nav2_mid360:ro" \
  "$IMAGE" \
  bash -lc '\
    source /opt/ros/humble/setup.bash; \
    /root/nav2_mid360/lio_container_helpers.sh & \
    ros2 launch /root/nav2_mid360/nav2_mid360_external_lio_launch.py \
      params_file:=/root/nav2_mid360/nav2_mid360_fastlio_params.yaml \
      headless:=${HEADLESS_LAUNCH} \
      use_rviz:=${USE_RVIZ_LAUNCH} & \
    NAV2_PID=$!; \
    sleep 4; \
    python3 /root/nav2_mid360/gazebo_truth_to_nav2_tf.py --ros-args -p use_sim_time:=true & \
    RELOC_PID=$!; \
    wait $NAV2_PID; \
    kill $RELOC_PID >/dev/null 2>&1 || true'
