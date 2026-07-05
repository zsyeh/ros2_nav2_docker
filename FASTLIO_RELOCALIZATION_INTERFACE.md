# FAST-LIO 级定位替换 AMCL 的接口说明

当前 Nav2 AMCL 方案已不适合作为 MID360 点云仿真的主定位方案。新的启动入口是：

```bash
/home/eh/ros2_nav2_docker/run_nav2_mid360_external_lio_sim.sh
```

这个版本不启动 AMCL，也不发布 `/initialpose`。Nav2 只负责规划和控制，定位由外部 FAST-LIO/重定位工具链负责。

## 外部 LIO 必须提供的接口

外部 FAST-LIO 级定位节点需要提供：

1. TF：`map -> base_link`，或者等价的连续定位 TF。
2. Odometry：`/Odometry`，类型为 `nav_msgs/msg/Odometry`。
3. 点云输入仍来自仿真 MID360：`/mid360/points`，类型为 `sensor_msgs/msg/PointCloud2`。
4. IMU 输入可来自仿真：`/imu`，类型为 `sensor_msgs/msg/Imu`。

Nav2 参数文件：

```text
/home/eh/ros2_nav2_docker/nav2_mid360_lio_params.yaml
```

该参数文件中：

```yaml
bt_navigator.ros__parameters.odom_topic: /Odometry
local_costmap.local_costmap.ros__parameters.global_frame: map
global_costmap.global_costmap.ros__parameters.global_frame: map
```

并且 local voxel layer 和 global obstacle layer 都继续使用：

```yaml
observation_sources: mid360_cloud
mid360_cloud.topic: /mid360/points
mid360_cloud.data_type: PointCloud2
```

## 为什么不再使用 AMCL

AMCL 是 2D 粒子滤波定位，典型输入是 2D LaserScan 和静态 2D occupancy map。MID360 是 3D LiDAR，点云几何信息远多于 2D scan。把 MID360 降维成 `/scan` 再给 AMCL，会丢掉高度、结构和稠密几何信息，在重定位、遮挡、退化场景中不稳定。

FAST-LIO / FAST-LIO2 级工具使用 LiDAR + IMU 紧耦合估计，核心输出是高频连续位姿，适合作为 Nav2 的外部定位来源。注意 FAST-LIO 本身更偏 odometry/mapping；真正“重定位”通常还需要已有点云地图、scan-to-map 初始化、闭环或全局匹配模块。

## 本机已有 FAST-LIO 代码状态

本机已有源码：

```text
/home/eh/livo_ws/src/FAST_LIO
/home/eh/livo_ws/src/FAST-LIVO2
/home/eh/driver_ws/livox_ws/src/FAST_LIO
```

这些包是 ROS1/catkin 包。当前 Nav2 仿真是 ROS2/Humble Docker。不能直接在同一个 ROS2 launch 里启动这些 ROS1 包。

可选接入路线：

1. 使用 ROS1 FAST_LIO + `ros1_bridge` 桥接 `/Odometry`、TF、点云和 IMU。
2. 换用 ROS2 版本 FAST-LIO/FAST-LIO-Localization，在当前 Docker 内直接编译运行。
3. 将当前 Gazebo MID360 点云转换成 FAST_LIO 需要的 Livox CustomMsg 或带 ring/time 字段的 PointCloud2。

当前已经完成的是 Nav2 侧的 AMCL 移除和外部 LIO 接口预留。
