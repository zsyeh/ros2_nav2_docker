# Script Usage Guide

This repository contains Docker-based ROS 2 Humble Nav2 simulations, MID360
sensor simulation helpers, and FAST-LIO integration experiments. Run commands
from the repository root unless noted otherwise:

```bash
cd ~/ros2_nav2_docker
```

## Prerequisites

- Ubuntu host with Docker installed.
- X11 desktop session for Gazebo and RViz GUI windows.
- The current user should be in the `docker` group, or run the shell scripts
  with sudo-capable privileges.
- The build scripts assume an HTTP proxy at `127.0.0.1:7890`. Edit the
  `--build-arg` values in the build scripts if your host does not use that
  proxy.

## Build Scripts

### `build_image.sh`

Builds the base ROS 2 Humble Nav2 Docker image:

```bash
./build_image.sh
```

Output image:

```text
ros2-nav2-humble:local
```

Use this image for the standard TurtleBot3 Nav2 simulation and the MID360
voxel/external-LIO launch experiments that do not need FAST-LIO installed in
the container.

### `build_fastlio_image.sh`

Builds the extended ROS 2 Humble image using `Dockerfile.fastlio`:

```bash
./build_fastlio_image.sh
```

Output image:

```text
ros2-nav2-fastlio-humble:local
```

Use this image for the FAST-LIO and Gazebo-truth relocalization flows.

## Simulation Run Scripts

### `run_nav2_sim.sh`

Runs the standard TurtleBot3 Waffle Gazebo + RViz + Nav2 demo using the base
image:

```bash
./build_image.sh
./run_nav2_sim.sh
```

Container name:

```text
ros2_nav2_humble_sim
```

After Gazebo and RViz start, use RViz `2D Goal Pose` to send a navigation goal.

### `run_nav2_mid360_voxel_sim.sh`

Runs a TurtleBot3 Waffle model with the simulated MID360 link and voxel-layer
Nav2 parameters:

```bash
./build_image.sh
./run_nav2_mid360_voxel_sim.sh
```

Container name:

```text
ros2_nav2_mid360_voxel_sim
```

Required files:

- `waffle_mid360.model`
- `nav2_mid360_voxel_params.yaml`
- `mid360_container_helpers.sh`

The helper publishes the static `base_link -> mid360_link` transform, sets RViz
to simulation time, waits for odometry, and publishes an initial pose.

### `run_nav2_mid360_external_lio_sim.sh`

Runs Gazebo + Nav2 using the custom external-LIO launch file and the base image:

```bash
./build_image.sh
./run_nav2_mid360_external_lio_sim.sh
```

Container name:

```text
ros2_nav2_mid360_lio_sim
```

Required files:

- `waffle_mid360.model`
- `nav2_mid360_lio_params.yaml`
- `nav2_mid360_external_lio_launch.py`
- `lio_container_helpers.sh`

This flow starts Gazebo, spawns the MID360 TurtleBot model, starts RViz and
Nav2, and publishes the static MID360 transform. It expects an external LIO
source to provide odometry/TF according to the Nav2 parameter file.

### `run_nav2_mid360_fastlio_sim.sh`

Runs the integrated FAST-LIO experiment inside the FAST-LIO Docker image:

```bash
./build_fastlio_image.sh
./run_nav2_mid360_fastlio_sim.sh
```

Container name:

```text
ros2_nav2_mid360_fastlio_sim
```

Required files:

- `waffle_mid360.model`
- `nav2_mid360_fastlio_params.yaml`
- `nav2_mid360_external_lio_launch.py`
- `lio_container_helpers.sh`
- `fastlio_mid360_sim.yaml`
- `fastlio_odom_to_nav2_tf.py`

The script starts Nav2 first, waits briefly, then launches FAST-LIO with
`fastlio_mid360_sim.yaml` and starts the odometry adapter. The adapter republishes
FAST-LIO odometry into the frame/topic layout expected by Nav2.

### `run_nav2_mid360_truth_relocalization_sim.sh`

Runs Nav2 with a simulated relocalization source based on Gazebo ground truth:

```bash
./build_fastlio_image.sh
./run_nav2_mid360_truth_relocalization_sim.sh
```

Container name:

```text
ros2_nav2_mid360_truth_reloc_sim
```

Optional environment variables:

```bash
HEADLESS=true USE_RVIZ=false ./run_nav2_mid360_truth_relocalization_sim.sh
```

- `HEADLESS`: set to `true`, `1`, `yes`, or `on` to disable the Gazebo client.
- `USE_RVIZ`: set to `false`, `0`, `no`, or `off` to disable RViz.

The script launches Gazebo/Nav2 and then runs `gazebo_truth_to_nav2_tf.py`,
which publishes `map -> odom` and a map-frame odometry topic from Gazebo model
state data. This is useful for validating Nav2 behavior before a real
relocalization source is available.

## Helper Scripts

### `set_mid360_initial_pose.sh`

Publishes the fixed initial pose used by the MID360 experiments into a running
container:

```bash
./set_mid360_initial_pose.sh
```

Default target container:

```text
ros2_nav2_mid360_voxel_sim
```

Pass a different container name as the first argument:

```bash
./set_mid360_initial_pose.sh ros2_nav2_mid360_lio_sim
```

Published pose:

- frame: `map`
- position: `x=-2.0`, `y=-0.5`, `z=0.0`
- orientation: yaw `0.0`

### `run_fastlio_odom_adapter_in_container.sh`

Runs the FAST-LIO odometry adapter inside an already running container:

```bash
./run_fastlio_odom_adapter_in_container.sh
```

Defaults:

- `CONTAINER_NAME=ros2_nav2_mid360_lio_sim`
- `INPUT_ODOM_TOPIC=/fastlio/Odometry`
- `OUTPUT_ODOM_TOPIC=/Odometry`
- `MAP_FRAME=map`
- `BASE_FRAME=base_link`

Override values with environment variables:

```bash
CONTAINER_NAME=ros2_nav2_mid360_fastlio_sim \
INPUT_ODOM_TOPIC=/Odometry \
OUTPUT_ODOM_TOPIC=/nav2_fastlio/Odometry \
./run_fastlio_odom_adapter_in_container.sh
```

### `run_host_fastlio_mid360_ros1.sh`

Starts a ROS 1 Noetic FAST-LIO launch on the host machine:

```bash
./run_host_fastlio_mid360_ros1.sh
```

Defaults:

- `FASTLIO_WS=/home/eh/livo_ws`
- `FASTLIO_LAUNCH=mapping_mid360.launch`
- `RUN_RVIZ=false`

Override values with environment variables:

```bash
FASTLIO_WS=/path/to/catkin_ws \
FASTLIO_LAUNCH=mapping_mid360.launch \
RUN_RVIZ=true \
./run_host_fastlio_mid360_ros1.sh
```

The script requires:

- `/opt/ros/noetic/setup.bash`
- `$FASTLIO_WS/devel/setup.bash`

If no `roscore` process is running, the script starts one automatically.

### `mid360_container_helpers.sh`

Internal helper used by `run_nav2_mid360_voxel_sim.sh`. It is intended to run
inside the Docker container, not directly on the host.

It performs three tasks:

- publishes the static `base_link -> mid360_link` transform;
- sets `/rviz use_sim_time` after RViz starts;
- publishes the initial pose after `/odom` becomes available.

### `lio_container_helpers.sh`

Internal helper used by the external-LIO and FAST-LIO launch scripts. It is
intended to run inside the Docker container, not directly on the host.

It publishes the static `base_link -> mid360_link` transform and sets RViz to
simulation time once RViz starts.

## Python Nodes And Launch Files

### `nav2_mid360_external_lio_launch.py`

ROS 2 launch file for the MID360 external-LIO experiments. It starts:

- Gazebo server and optional Gazebo client;
- robot spawning with `waffle_mid360.model`;
- `robot_state_publisher`;
- optional RViz;
- Nav2 navigation launch.

Typical direct use inside the container:

```bash
source /opt/ros/humble/setup.bash
ros2 launch /root/nav2_mid360/nav2_mid360_external_lio_launch.py \
  params_file:=/root/nav2_mid360/nav2_mid360_lio_params.yaml \
  headless:=False \
  use_rviz:=True
```

Important launch arguments:

- `params_file`: Nav2 parameter file.
- `headless`: whether to skip the Gazebo GUI client.
- `use_rviz`: whether to launch RViz.
- `robot_sdf`: robot SDF/model file.
- `x_pose`, `y_pose`, `z_pose`, `yaw`: spawn pose.

### `fastlio_odom_to_nav2_tf.py`

ROS 2 node that subscribes to FAST-LIO odometry, normalizes the quaternion,
republishes odometry with Nav2-compatible frame IDs, and optionally broadcasts
the `map -> base_link` transform.

Example:

```bash
source /opt/ros/humble/setup.bash
python3 /root/nav2_mid360/fastlio_odom_to_nav2_tf.py \
  --ros-args \
  -p input_odom_topic:=/fastlio/Odometry \
  -p output_odom_topic:=/Odometry \
  -p map_frame:=map \
  -p base_frame:=base_link \
  -p publish_tf:=true
```

Parameters:

- `input_odom_topic`, default `/fastlio/Odometry`
- `output_odom_topic`, default `/Odometry`
- `map_frame`, default `map`
- `base_frame`, default `base_link`
- `publish_tf`, default `true`

### `gazebo_truth_to_nav2_tf.py`

ROS 2 node that reads Gazebo model state data and publishes simulated
relocalization output for Nav2:

- `map -> odom` TF;
- map-frame odometry on the configured output topic.

Example:

```bash
source /opt/ros/humble/setup.bash
python3 /root/nav2_mid360/gazebo_truth_to_nav2_tf.py --ros-args -p use_sim_time:=true
```

Important parameters:

- `robot_name`, default `turtlebot3_waffle`
- `truth_topic`, default `/gazebo/model_states`
- `odom_topic`, default `/odom`
- `output_odom_topic`, default `/nav2_fastlio/Odometry`
- `map_frame`, default `map`
- `odom_frame`, default `odom`
- `base_frame`, default `base_link`
- `initial_x`, `initial_y`, `initial_z`, `initial_yaw`: fallback initial pose
  when Gazebo model states are not yet available.

## Configuration And Model Files

- `nav2_mid360_voxel_params.yaml`: Nav2 parameters for the MID360 voxel-layer
  experiment.
- `nav2_mid360_lio_params.yaml`: Nav2 parameters for external-LIO odometry.
- `nav2_mid360_fastlio_params.yaml`: Nav2 parameters for FAST-LIO-related
  experiments.
- `fastlio_mid360_sim.yaml`: FAST-LIO configuration used by the simulated
  MID360 run.
- `waffle_mid360.model`: TurtleBot3 Waffle Gazebo model extended with the
  simulated MID360 link/sensor frame.

## Suggested Workflows

### Standard Nav2

```bash
./build_image.sh
./run_nav2_sim.sh
```

### MID360 Voxel Nav2

```bash
./build_image.sh
./run_nav2_mid360_voxel_sim.sh
```

### FAST-LIO Integration Test

```bash
./build_fastlio_image.sh
./run_nav2_mid360_fastlio_sim.sh
```

### Gazebo-Truth Relocalization Test

```bash
./build_fastlio_image.sh
HEADLESS=false USE_RVIZ=true ./run_nav2_mid360_truth_relocalization_sim.sh
```
