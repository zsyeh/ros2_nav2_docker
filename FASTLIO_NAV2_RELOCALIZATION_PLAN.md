# MID360 + Voxel Nav2: AMCL-Free FAST-LIO Relocalization Plan

This workspace now keeps the Nav2 stack independent from AMCL. The active
Nav2 entry point is:

```bash
/home/eh/ros2_nav2_docker/run_nav2_mid360_external_lio_sim.sh
```

It launches Gazebo, the MID360-like point cloud sensor, voxel costmaps, and
Nav2 navigation nodes without `amcl` or `map_server`.

## Current State

- Removed AMCL from the new LIO-oriented Nav2 parameter file.
- Removed static map server dependency from the new LIO-oriented Nav2 setup.
- Kept voxel costmaps consuming `/mid360/points`.
- Set Nav2 odometry input to `/Odometry`.
- Set local and global costmap frames to `map`.
- Added a ROS2 odometry/TF adapter:
  - input: `/fastlio/Odometry`
  - output: `/Odometry`
  - TF: `map -> base_link`

The adapter is:

```bash
/home/eh/ros2_nav2_docker/fastlio_odom_to_nav2_tf.py
```

Run it inside the running Nav2 container with:

```bash
/home/eh/ros2_nav2_docker/run_fastlio_odom_adapter_in_container.sh
```

## Why AMCL Is No Longer Used

AMCL estimates 2D pose by matching laser scans against a prebuilt occupancy
grid map. It is suitable for planar 2D navigation, but it is weak when the
robot needs LiDAR-inertial 3D motion consistency, aggressive motion handling,
or relocalization quality closer to modern LIO systems.

The replacement architecture expects a FAST-LIO-class tool to own localization
and publish the global robot pose. Nav2 then only consumes the pose and plans
with costmaps.

## FAST-LIO Role

FAST-LIO fuses LiDAR and IMU data with a tightly coupled iterated Kalman
filter. The upstream FAST-LIO README describes it as a robust, real-time
LiDAR-inertial odometry package, and FAST-LIO2 adds direct raw-point scan to
map registration with an incremental kd-tree map.

In this setup, FAST-LIO-class localization must provide:

- `/fastlio/Odometry` or `/Odometry`: `nav_msgs/Odometry`
- a valid global pose in the `map` frame
- a TF path ending at `base_link`

The adapter converts bridged FAST_LIO odometry into the Nav2 contract:

```text
/fastlio/Odometry  ->  /Odometry
camera_init/body   ->  map/base_link
```

## Voxel Layer Role

The voxel layer is not localization. It builds a 3D obstacle representation
from point clouds for collision checking. In this workspace it subscribes to:

```text
/mid360/points
```

The voxel layer lets Nav2 react to 3D obstacles from the MID360-like cloud,
while FAST-LIO handles robot pose estimation.

## Existing Local FAST_LIO Package

Local FAST_LIO exists here:

```text
/home/eh/livo_ws/src/FAST_LIO
/home/eh/driver_ws/livox_ws/src/FAST_LIO
```

It is ROS1/catkin, not ROS2. The MID360 launch file is:

```text
/home/eh/livo_ws/src/FAST_LIO/launch/mapping_mid360.launch
```

It expects:

```text
/livox/lidar
/livox/imu
```

It publishes:

```text
/Odometry
/path
TF camera_init -> body
```

Host-side ROS1 FAST_LIO launcher:

```bash
/home/eh/ros2_nav2_docker/run_host_fastlio_mid360_ros1.sh
```

## Remaining Integration Gap

The current Docker image is ROS2 Humble and does not contain `ros1_bridge`.
The host contains ROS Noetic and the ROS1 FAST_LIO workspace, but host ROS2 is
not installed. Therefore ROS1 FAST_LIO cannot yet talk to ROS2 Nav2 directly.

One of these must be added:

1. A working ROS1/ROS2 bridge that remaps ROS1 `/Odometry` to ROS2
   `/fastlio/Odometry`.
2. A ROS2 FAST-LIO or FAST-LIO-localization port built inside the Docker image.
3. A full ROS1 Noetic + ROS2 bridge container paired with the current ROS2 Nav2
   container over host networking.

After the bridge or ROS2 port is present, start order should be:

```bash
# Terminal 1: ROS2 Nav2 + Gazebo, no AMCL
/home/eh/ros2_nav2_docker/run_nav2_mid360_external_lio_sim.sh

# Terminal 2: adapter inside the running Nav2 container
/home/eh/ros2_nav2_docker/run_fastlio_odom_adapter_in_container.sh

# Terminal 3: ROS1 FAST_LIO on host, after LiDAR/IMU topics exist in ROS1
/home/eh/ros2_nav2_docker/run_host_fastlio_mid360_ros1.sh
```

## Important Sensor Note

FAST-LIO for Livox sensors relies on per-point timing. The upstream FAST-LIO
README notes that missing per-point `time` fields harm motion undistortion.
The current Gazebo MID360-like sensor publishes ROS2 `PointCloud2`; before
claiming real FAST-LIO quality, the point fields must be checked and converted
to the exact format expected by the selected FAST-LIO implementation.
