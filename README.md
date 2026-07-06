# ROS 2 Nav2 Docker Simulation

This workspace runs ROS 2 Humble Nav2 Docker simulations for TurtleBot3,
MID360-style Gazebo experiments, external LIO wiring, FAST-LIO integration, and
Gazebo-truth relocalization tests.

## Quick Start

Install Docker on the host first:

```bash
sudo apt-get update
sudo apt-get install -y docker.io
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"
```

After adding the user to the `docker` group, log out and log back in. If you do
not log out, run the scripts with `sudo`.

Build the image:

```bash
cd ~/ros2_nav2_docker
./build_image.sh
```

Run Gazebo + RViz + Nav2:

```bash
./run_nav2_sim.sh
```

To send a navigation goal, use RViz's `2D Goal Pose` tool after the map and
robot appear.

## Main Workflows

Build and run the MID360 voxel-layer simulation:

```bash
./build_image.sh
./run_nav2_mid360_voxel_sim.sh
```

Build and run the FAST-LIO Docker experiment:

```bash
./build_fastlio_image.sh
./run_nav2_mid360_fastlio_sim.sh
```

Run the Gazebo-truth relocalization validation:

```bash
./build_fastlio_image.sh
HEADLESS=false USE_RVIZ=true ./run_nav2_mid360_truth_relocalization_sim.sh
```

## Documentation

- [SCRIPT_USAGE.md](SCRIPT_USAGE.md): complete usage guide for every shell
  script, Python helper, launch file, parameter file, and model file.
- [ROS2_NAV2_DOCKER_DEBUG_RECORD.md](ROS2_NAV2_DOCKER_DEBUG_RECORD.md):
  debugging record for the ROS 2 Nav2 Docker setup.
- [FASTLIO_RELOCALIZATION_INTERFACE.md](FASTLIO_RELOCALIZATION_INTERFACE.md):
  FAST-LIO and relocalization interface notes.
- [FASTLIO_NAV2_RELOCALIZATION_PLAN.md](FASTLIO_NAV2_RELOCALIZATION_PLAN.md):
  relocalization integration plan.
- [NAV2_MID360_FASTLIO_EXPERIMENT_REPORT.md](NAV2_MID360_FASTLIO_EXPERIMENT_REPORT.md):
  experiment report for the Nav2 MID360 FAST-LIO work.

## Repository Contents

- Docker images: `Dockerfile`, `Dockerfile.fastlio`
- Run scripts: `run_nav2_sim.sh`, `run_nav2_mid360_voxel_sim.sh`,
  `run_nav2_mid360_external_lio_sim.sh`, `run_nav2_mid360_fastlio_sim.sh`,
  `run_nav2_mid360_truth_relocalization_sim.sh`
- Helper scripts: `set_mid360_initial_pose.sh`,
  `run_fastlio_odom_adapter_in_container.sh`,
  `run_host_fastlio_mid360_ros1.sh`, `mid360_container_helpers.sh`,
  `lio_container_helpers.sh`
- ROS 2 helpers: `nav2_mid360_external_lio_launch.py`,
  `fastlio_odom_to_nav2_tf.py`, `gazebo_truth_to_nav2_tf.py`
- Config/model files: `nav2_mid360_voxel_params.yaml`,
  `nav2_mid360_lio_params.yaml`, `nav2_mid360_fastlio_params.yaml`,
  `fastlio_mid360_sim.yaml`, `waffle_mid360.model`
