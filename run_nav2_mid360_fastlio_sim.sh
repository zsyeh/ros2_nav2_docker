#!/usr/bin/env bash
set -euo pipefail

IMAGE="ros2-nav2-fastlio-humble:local"
CONTAINER_NAME="ros2_nav2_mid360_fastlio_sim"
WORKDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! sudo docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "Image $IMAGE not found. Run ./build_fastlio_image.sh first." >&2
  exit 1
fi

for required in \
  waffle_mid360.model \
  nav2_mid360_fastlio_params.yaml \
  nav2_mid360_external_lio_launch.py \
  lio_container_helpers.sh \
  fastlio_mid360_sim.yaml \
  fastlio_odom_to_nav2_tf.py; do
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
  -e RMW_IMPLEMENTATION=rmw_cyclonedds_cpp \
  -e GAZEBO_MODEL_DATABASE_URI= \
  -e GAZEBO_MODEL_PATH=/opt/ros/humble/share/turtlebot3_gazebo/models:/usr/share/gazebo-11/models \
  -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
  -v "$WORKDIR:/root/nav2_mid360:ro" \
  "$IMAGE" \
  bash -lc '\
    source /opt/ros/humble/setup.bash; \
    source /opt/fastlio_ws/install/setup.bash; \
    /root/nav2_mid360/lio_container_helpers.sh & \
    ros2 launch /root/nav2_mid360/nav2_mid360_external_lio_launch.py \
      params_file:=/root/nav2_mid360/nav2_mid360_fastlio_params.yaml & \
    NAV2_PID=$!; \
    sleep 8; \
    ros2 launch fast_lio mapping.launch.py \
      config_path:=/root/nav2_mid360 \
      config_file:=fastlio_mid360_sim.yaml \
      use_sim_time:=true \
      rviz:=false & \
    FASTLIO_PID=$!; \
    python3 /root/nav2_mid360/fastlio_odom_to_nav2_tf.py \
      --ros-args \
      -p input_odom_topic:=/Odometry \
      -p output_odom_topic:=/nav2_fastlio/Odometry \
      -p map_frame:=map \
      -p base_frame:=base_link & \
    ADAPTER_PID=$!; \
    wait $NAV2_PID; \
    kill $FASTLIO_PID $ADAPTER_PID >/dev/null 2>&1 || true'
