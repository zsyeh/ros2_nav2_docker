# ROS2 Nav2 Docker 仿真安装与调试完整记录

本文档记录本次在宿主机 `/home/eh` 上使用 Docker 安装 ROS2 Humble、构建 Nav2 + TurtleBot3 + Gazebo 仿真环境、运行 Nav2 仿真、排查启动失败并最终跑通的全过程。

记录时间：2026-07-05  
宿主机工作目录：`/home/eh/ros2_nav2_docker`  
Docker 镜像名：`ros2-nav2-humble:local`  
Docker 容器名：`ros2_nav2_humble_sim`

## 1. 目标

本次目标是：

1. 在宿主机上使用 Docker 安装 ROS2 环境。
2. 构建一个包含 ROS2 Humble、Navigation2、TurtleBot3、Gazebo Classic、RViz2 的镜像。
3. 运行 Nav2 官方 TurtleBot3 仿真。
4. 验证 Gazebo、RViz、TurtleBot3、Nav2 lifecycle、关键 ROS2 topic/service 是否正常。
5. 解决启动过程中出现的卡住、缺库、Gazebo spawn 失败等问题。

## 2. 最终目录结构

最终工作目录：

```text
/home/eh/ros2_nav2_docker
├── Dockerfile
├── README.md
├── ROS2_NAV2_DOCKER_DEBUG_RECORD.md
├── build_image.sh
└── run_nav2_sim.sh
```

## 3. Docker 安装与系统准备

开始时宿主机没有可用的 Docker 环境，因此先安装 Docker。

### 3.1 APT 源调整

宿主机原先的 Ubuntu APT 源访问不稳定，曾将 `/etc/apt/sources.list` 从国内镜像切换到官方 Ubuntu 源。

备份文件：

```text
/etc/apt/sources.list.bak.codex
```

最终使用的源内容大致为：

```text
deb http://archive.ubuntu.com/ubuntu/ focal main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ focal-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ focal-backports main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu focal-security main restricted universe multiverse
```

### 3.2 APT 代理问题

用户说明宿主机 `198` 是 Clash 的 TUN 模式，问题不在这里。实际调试中发现，主要问题是 `sudo apt` 默认没有正确使用本地代理。

成功使用的 APT 代理方式：

```bash
sudo apt-get \
  -o Acquire::http::Proxy=http://127.0.0.1:7890 \
  -o Acquire::https::Proxy=http://127.0.0.1:7890 \
  update
```

安装 Docker 时也使用了同样的代理参数：

```bash
sudo apt-get \
  -o Acquire::http::Proxy=http://127.0.0.1:7890 \
  -o Acquire::https::Proxy=http://127.0.0.1:7890 \
  install -y docker.io
```

### 3.3 Docker 安装结果

Docker 安装完成后执行：

```bash
sudo systemctl start docker
sudo usermod -aG docker eh
```

验证过 Docker 版本：

```text
Client/Server Docker version: 26.1.3
Storage Driver: overlay2
containerd: 1.7.24
runc: 1.1.12
```

### 3.4 Docker daemon 代理配置

为了让 Docker build / pull 能够访问外网，配置了 Docker daemon 代理：

文件：

```text
/etc/systemd/system/docker.service.d/http-proxy.conf
```

内容：

```ini
[Service]
Environment=HTTP_PROXY=http://127.0.0.1:7890
Environment=HTTPS_PROXY=http://127.0.0.1:7890
Environment=NO_PROXY=localhost,127.0.0.1
```

然后重载并重启 Docker：

```bash
sudo systemctl daemon-reload
sudo systemctl restart docker
```

之后通过 `sudo docker info` 确认 Docker daemon 已识别 HTTP/HTTPS proxy。

## 4. Docker 工作空间创建

创建工作目录：

```text
/home/eh/ros2_nav2_docker
```

该目录用于保存 Dockerfile、构建脚本、运行脚本和文档。

## 5. Dockerfile 设计

基础镜像选用：

```dockerfile
FROM osrf/ros:humble-desktop-full
```

原因：

1. 该镜像已经包含 ROS2 Humble desktop 基础环境。
2. desktop-full 适合 Gazebo / RViz 图形仿真。
3. 后续只需要安装 Nav2、TurtleBot3 和缺失运行库。

最终 Dockerfile 的关键内容：

```dockerfile
FROM osrf/ros:humble-desktop-full

ENV DEBIAN_FRONTEND=noninteractive
ENV ROS_DISTRO=humble
ENV TURTLEBOT3_MODEL=waffle
ENV GAZEBO_MODEL_DATABASE_URI=
ENV GAZEBO_MODEL_PATH=/opt/ros/humble/share/turtlebot3_gazebo/models:/usr/share/gazebo-11/models

RUN apt-get update && apt-get install -y --no-install-recommends \
    ros-humble-navigation2 \
    ros-humble-nav2-bringup \
    ros-humble-diagnostic-updater \
    ros-humble-turtlebot3 \
    ros-humble-turtlebot3-gazebo \
    ros-humble-turtlebot3-msgs \
    ros-humble-turtlebot3-navigation2 \
    x11-apps \
    && rm -rf /var/lib/apt/lists/*

RUN echo "source /opt/ros/humble/setup.bash" >> /root/.bashrc && \
    echo "export TURTLEBOT3_MODEL=waffle" >> /root/.bashrc

WORKDIR /root
CMD ["bash"]
```

## 6. 构建脚本

构建脚本路径：

```text
/home/eh/ros2_nav2_docker/build_image.sh
```

最终构建命令使用了 host 网络和代理 build args：

```bash
sudo docker build \
  --network=host \
  --build-arg http_proxy=http://127.0.0.1:7890 \
  --build-arg https_proxy=http://127.0.0.1:7890 \
  --build-arg HTTP_PROXY=http://127.0.0.1:7890 \
  --build-arg HTTPS_PROXY=http://127.0.0.1:7890 \
  -t ros2-nav2-humble:local .
```

### 6.1 为什么需要 `--network=host`

第一次构建时，Docker build 内部容器如果使用默认 bridge 网络，`127.0.0.1:7890` 指向的是构建容器自身，而不是宿主机的 Clash 代理。

因此代理不可达，APT 下载失败。

改为：

```bash
--network=host
```

后，构建容器可以通过 `127.0.0.1:7890` 访问宿主机代理。

### 6.2 构建过程中的失败记录

构建过程中遇到过以下问题：

1. Docker daemon 初始未安装或未启动。
2. APT 源访问不稳定。
3. `sudo apt` 没有使用 Clash 代理。
4. Docker build 默认 bridge 网络下代理不可达。
5. 中途曾遇到 `freeglut3` 相关下载 `502`，属于 transient 网络错误。
6. 初始镜像缺少 `diagnostic_updater` 运行库，导致 Nav2 节点加载失败。

### 6.3 `diagnostic_updater` 缺库问题

第一次运行 Nav2 时出现过类似缺库问题：

```text
missing libdiagnostic_updater.so
```

原因是 Nav2 或相关组件运行时需要 `diagnostic_updater`，但初始 Dockerfile 没有显式安装。

修复方式是在 Dockerfile 中加入：

```dockerfile
ros-humble-diagnostic-updater
```

重新构建镜像后该问题解决。

## 7. 运行脚本

运行脚本路径：

```text
/home/eh/ros2_nav2_docker/run_nav2_sim.sh
```

最终脚本逻辑：

1. 检查镜像 `ros2-nav2-humble:local` 是否存在。
2. 执行 `xhost +local:docker` 允许 Docker 容器访问 X11。
3. 清理同名旧容器。
4. 启动带 GUI 的 Nav2 TurtleBot3 仿真。

关键 docker run 参数：

```bash
sudo docker run --rm -it \
  --name ros2_nav2_humble_sim \
  --net=host \
  --ipc=host \
  --privileged \
  -e DISPLAY="${DISPLAY:-:0}" \
  -e QT_X11_NO_MITSHM=1 \
  -e TURTLEBOT3_MODEL=waffle \
  -e GAZEBO_MODEL_DATABASE_URI= \
  -e GAZEBO_MODEL_PATH=/opt/ros/humble/share/turtlebot3_gazebo/models:/usr/share/gazebo-11/models \
  -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
  ros2-nav2-humble:local \
  bash -lc 'source /opt/ros/humble/setup.bash && ros2 launch nav2_bringup tb3_simulation_launch.py headless:=False'
```

## 8. 第一次运行失败：`/spawn_entity` 不可用

第一次完整启动脚本后，Gazebo、RViz、Nav2 进程看起来都启动了：

```text
gzserver
gzclient
spawn_entity.py
robot_state_publisher
rviz2
component_container_isolated
```

但 `spawn_entity.py` 报错：

```text
Service /spawn_entity unavailable. Was Gazebo started with GazeboRosFactory?
Spawn service failed. Exiting.
```

后续 Nav2 local costmap 一直报：

```text
Timed out waiting for transform from base_link to odom
Invalid frame ID "odom" passed to canTransform argument target_frame - frame does not exist
```

这说明 TurtleBot3 没有成功 spawn 到 Gazebo，因此没有 diff drive 插件发布 `/odom`。

## 9. 排查 `/spawn_entity` 不存在

进入正在运行的容器检查服务：

```bash
sudo docker exec ros2_nav2_humble_sim bash -lc '
  source /opt/ros/humble/setup.bash
  ros2 service list | sort | grep -E "spawn|gazebo" || true
'
```

当时只看到：

```text
/gazebo/describe_parameters
/gazebo/get_parameter_types
/gazebo/get_parameters
/gazebo/list_parameters
/gazebo/set_parameters
/gazebo/set_parameters_atomically
```

没有：

```text
/spawn_entity
```

同时检查进程，`gzserver` 确实还在：

```text
gzserver -s libgazebo_ros_init.so -s libgazebo_ros_factory.so /opt/ros/humble/share/nav2_bringup/worlds/world_only.model
gzclient
```

这说明不是 `gzserver` 没启动，而是 Gazebo ROS factory 插件没有完成服务注册，或者 world 加载过程卡住。

## 10. 检查 Gazebo ROS 插件

检查容器内插件文件：

```bash
ls -l /opt/ros/humble/lib/libgazebo_ros_factory.so
ls -l /opt/ros/humble/lib/libgazebo_ros_init.so
```

确认两个文件都存在：

```text
/opt/ros/humble/lib/libgazebo_ros_factory.so
/opt/ros/humble/lib/libgazebo_ros_init.so
```

因此问题不是插件文件缺失。

## 11. 单独启动 `gzserver` 进行隔离测试

为了排除 Nav2 launch 其它节点干扰，单独测试：

```bash
sudo docker run --rm --net=host --ipc=host --privileged ros2-nav2-humble:local bash -lc '
  source /opt/ros/humble/setup.bash
  gzserver --verbose \
    -s libgazebo_ros_init.so \
    -s libgazebo_ros_factory.so \
    /opt/ros/humble/share/nav2_bringup/worlds/world_only.model \
    > /tmp/gzserver.out 2>&1 &
  pid=$!
  sleep 8
  ros2 service list | sort | grep -E "spawn|gazebo" || true
  tail -120 /tmp/gzserver.out
  kill $pid 2>/dev/null || true
'
```

第一次隔离测试失败，因为旧 Gazebo 进程还在，占用了 Gazebo master 端口：

```text
Unable to start server[bind: Address already in use].
There is probably another Gazebo process running.
```

随后停止旧 Nav2 容器，释放端口。

## 12. 发现 Gazebo 在线模型库等待问题

干净环境下再次测试时，`gzserver --verbose` 输出显示：

```text
Getting models from[http://models.gazebosim.org/]. This may take a few seconds.
```

同时服务列表仍然没有 `/spawn_entity`。

这说明 Gazebo 正在尝试从在线模型库下载模型，world 加载没有完成，factory 服务也没有正常可用。

## 13. 检查 Nav2 world 文件

读取容器内 world 文件：

```text
/opt/ros/humble/share/nav2_bringup/worlds/world_only.model
```

关键内容：

```xml
<include>
  <uri>model://ground_plane</uri>
</include>

<include>
  <uri>model://sun</uri>
</include>

<model name="turtlebot3_world">
  <static>1</static>
  <include>
    <uri>model://turtlebot3_world</uri>
  </include>
</model>
```

该 world 依赖三个 `model://` 模型：

1. `ground_plane`
2. `sun`
3. `turtlebot3_world`

初始 Dockerfile 中只设置了：

```text
GAZEBO_MODEL_PATH=/opt/ros/humble/share/turtlebot3_gazebo/models
```

这能找到 `turtlebot3_world`，但不能找到 Gazebo 自带的 `ground_plane` 和 `sun`。

因此 Gazebo 会尝试访问：

```text
http://models.gazebosim.org/
```

在当前网络环境中该过程会卡住或非常慢，导致 `/spawn_entity` 服务迟迟不可用。

## 14. 关键修复：补全本地 Gazebo 模型路径

修复方式：

```bash
GAZEBO_MODEL_DATABASE_URI=
GAZEBO_MODEL_PATH=/opt/ros/humble/share/turtlebot3_gazebo/models:/usr/share/gazebo-11/models
```

含义：

1. `GAZEBO_MODEL_DATABASE_URI=` 禁用 Gazebo 在线模型数据库。
2. `/opt/ros/humble/share/turtlebot3_gazebo/models` 提供 TurtleBot3 world 模型。
3. `/usr/share/gazebo-11/models` 提供 Gazebo Classic 自带模型，例如 `ground_plane` 和 `sun`。

验证命令：

```bash
sudo docker run --rm \
  --net=host \
  --ipc=host \
  --privileged \
  -e GAZEBO_MODEL_DATABASE_URI= \
  -e GAZEBO_MODEL_PATH=/opt/ros/humble/share/turtlebot3_gazebo/models:/usr/share/gazebo-11/models \
  ros2-nav2-humble:local \
  bash -lc '
    source /opt/ros/humble/setup.bash
    gzserver --verbose \
      -s libgazebo_ros_init.so \
      -s libgazebo_ros_factory.so \
      /opt/ros/humble/share/nav2_bringup/worlds/world_only.model \
      > /tmp/gzserver.out 2>&1 &
    pid=$!
    sleep 12
    ros2 service list | sort | grep -E "spawn|gazebo" || true
    tail -180 /tmp/gzserver.out
    kill -TERM $pid 2>/dev/null || true
    sleep 2
    kill -KILL $pid 2>/dev/null || true
    wait $pid 2>/dev/null || true
  '
```

成功结果：

```text
/gazebo/describe_parameters
/gazebo/get_parameter_types
/gazebo/get_parameters
/gazebo/list_parameters
/gazebo/set_parameters
/gazebo/set_parameters_atomically
/spawn_entity
```

这证明 `/spawn_entity` 问题已经定位并解决。

## 15. 修改文件

### 15.1 修改 Dockerfile

加入：

```dockerfile
ENV GAZEBO_MODEL_DATABASE_URI=
ENV GAZEBO_MODEL_PATH=/opt/ros/humble/share/turtlebot3_gazebo/models:/usr/share/gazebo-11/models
```

### 15.2 修改 run_nav2_sim.sh

在 `docker run` 中加入：

```bash
-e GAZEBO_MODEL_DATABASE_URI= \
-e GAZEBO_MODEL_PATH=/opt/ros/humble/share/turtlebot3_gazebo/models:/usr/share/gazebo-11/models \
```

这样即使旧镜像未重新构建，运行脚本也会把正确环境变量传入容器。

## 16. 重新运行完整 Nav2 仿真

执行：

```bash
/home/eh/ros2_nav2_docker/run_nav2_sim.sh
```

启动后看到：

```text
[INFO] [gzserver-1]: process started
[INFO] [gzclient-2]: process started
[INFO] [spawn_entity.py-3]: process started
[INFO] [robot_state_publisher-4]: process started
[INFO] [rviz2-5]: process started
[INFO] [component_container_isolated-6]: process started
```

随后 `spawn_entity.py` 成功：

```text
Waiting for service /spawn_entity
Calling service /spawn_entity
Spawn status: SpawnEntity: Successfully spawned entity [turtlebot3_waffle]
```

Gazebo 插件开始发布 odom：

```text
[turtlebot3_diff_drive]: Subscribed to [/cmd_vel]
[turtlebot3_diff_drive]: Advertise odometry on [/odom]
[turtlebot3_diff_drive]: Publishing odom transforms between [odom] and [base_footprint]
```

这证明 TurtleBot3 已经成功进入 Gazebo。

## 17. AMCL 初始位姿问题

TurtleBot3 spawn 后，Nav2 继续等待 `map -> odom` 变换。

日志显示：

```text
AMCL cannot publish a pose or update the transform. Please set the initial pose...
Timed out waiting for transform from base_link to map
```

原因：AMCL 需要一个初始位姿，否则不会发布 `map -> odom`。

手动发布初始位姿：

```bash
sudo docker exec ros2_nav2_humble_sim bash -lc '
  source /opt/ros/humble/setup.bash
  ros2 topic pub --once /initialpose geometry_msgs/msg/PoseWithCovarianceStamped \
  "{header: {frame_id: map}, pose: {pose: {position: {x: -2.0, y: -0.5, z: 0.0}, orientation: {z: 0.0, w: 1.0}}, covariance: [0.25, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.25, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.068]}}"
'
```

AMCL 接收成功：

```text
[amcl]: initialPoseReceived
[amcl]: Setting pose (79.000000): -2.000 -0.500 -0.000
```

随后 Nav2 继续激活。

## 18. Nav2 lifecycle 激活成功

最终日志显示：

```text
[lifecycle_manager_navigation]: Managed nodes are active
```

这表示 Nav2 navigation stack 已经进入可用状态。

其中激活的组件包括：

1. `controller_server`
2. `smoother_server`
3. `planner_server`
4. `behavior_server`
5. `bt_navigator`
6. `waypoint_follower`
7. `velocity_smoother`

## 19. 最终状态检查

执行容器内检查：

```bash
sudo docker exec ros2_nav2_humble_sim bash -lc '
  source /opt/ros/humble/setup.bash
  echo NODES
  ros2 node list | sort | grep -E "amcl|bt_navigator|controller_server|planner_server|rviz|robot_state_publisher" || true
  echo SERVICES
  ros2 service list | sort | grep -E "spawn_entity|navigate_to_pose|get_state" | head -40
  echo TOPICS
  ros2 topic list | sort | grep -E "^/(odom|scan|map|tf|cmd_vel|initialpose)$"
'
```

检查结果：

```text
NODES
/amcl
/bt_navigator
/bt_navigator_navigate_through_poses_rclcpp_node
/bt_navigator_navigate_to_pose_rclcpp_node
/controller_server
/planner_server
/robot_state_publisher
/rviz
/rviz_navigation_dialog_action_client

SERVICES
/spawn_entity

TOPICS
/cmd_vel
/initialpose
/map
/odom
/scan
/tf
```

该结果说明：

1. Gazebo factory 服务存在。
2. TurtleBot3 已经发布 `/odom`。
3. 激光雷达 `/scan` 存在。
4. 地图 `/map` 存在。
5. TF `/tf` 存在。
6. Nav2 关键节点存在。
7. RViz 已启动。

## 20. 当前已知的非致命日志

运行过程中可能出现以下日志，它们不是本次核心故障：

### 20.1 ALSA 音频错误

```text
ALSA lib ... cannot find card '0'
AL lib: Could not open playback device 'default'
Audio will be disabled.
```

原因：容器里没有宿主机音频设备。

影响：不影响 Nav2/Gazebo 仿真。

### 20.2 RViz OpenGL / shader 警告

```text
Stereo is NOT SUPPORTED
GLSL link result
active samplers with a different type refer to the same texture image unit
```

影响：通常不影响基本 RViz 显示和 Nav2 运行。

### 20.3 Gazebo Classic EOL 提示

```text
This version of Gazebo, now called Gazebo classic, reaches end-of-life in January 2025.
```

原因：ROS2 Humble 的很多 TurtleBot3/Nav2 示例仍使用 Gazebo Classic。

影响：提示性质，不影响当前仿真。

## 21. 关键结论

本次最关键的问题不是 SITL，也不是 Clash TUN，也不是 Docker 没启动。

真正导致 Nav2 仿真卡住的直接原因是：

```text
GAZEBO_MODEL_PATH 不完整，Gazebo 找不到 ground_plane 和 sun，本地 world 加载时尝试访问在线模型库，导致 /spawn_entity 服务迟迟没有注册。
```

最终修复：

```bash
GAZEBO_MODEL_DATABASE_URI=
GAZEBO_MODEL_PATH=/opt/ros/humble/share/turtlebot3_gazebo/models:/usr/share/gazebo-11/models
```

## 22. 常用命令

### 22.1 构建镜像

```bash
cd /home/eh/ros2_nav2_docker
./build_image.sh
```

### 22.2 运行仿真

```bash
/home/eh/ros2_nav2_docker/run_nav2_sim.sh
```

### 22.3 停止仿真

```bash
sudo docker rm -f ros2_nav2_humble_sim
```

### 22.4 查看容器是否运行

```bash
sudo docker ps
```

### 22.5 进入容器

```bash
sudo docker exec -it ros2_nav2_humble_sim bash
```

进入后：

```bash
source /opt/ros/humble/setup.bash
```

### 22.6 检查 ROS2 节点

```bash
ros2 node list
```

### 22.7 检查 ROS2 topic

```bash
ros2 topic list
```

重点 topic：

```text
/cmd_vel
/initialpose
/map
/odom
/scan
/tf
```

### 22.8 检查 Gazebo spawn 服务

```bash
ros2 service list | grep spawn
```

期望看到：

```text
/spawn_entity
```

### 22.9 发布 AMCL 初始位姿

```bash
ros2 topic pub --once /initialpose geometry_msgs/msg/PoseWithCovarianceStamped \
'{header: {frame_id: map}, pose: {pose: {position: {x: -2.0, y: -0.5, z: 0.0}, orientation: {z: 0.0, w: 1.0}}, covariance: [0.25, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.25, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.068]}}'
```

## 23. 后续可改进项

1. 把发布 `/initialpose` 的步骤加入一个单独脚本，例如 `set_initial_pose.sh`。
2. 增加一个 headless 模式脚本，只跑 `gzserver` 和 Nav2，不启动 GUI。
3. 增加一个自动健康检查脚本，检测 `/spawn_entity`、`/odom`、`/scan`、Nav2 lifecycle 是否 active。
4. 如果需要长期使用，可把用户加入 docker 组后重新登录，减少 `sudo docker` 的使用。
5. 如果 RViz 图形异常，可继续检查宿主机 X11、OpenGL、NVIDIA/Intel 显卡驱动透传。

## 24. 本次最终状态

最终状态：

```text
Docker 已安装并启动。
ROS2 Humble + Nav2 + TurtleBot3 + Gazebo 镜像已构建。
Nav2 TurtleBot3 Gazebo 仿真已启动。
TurtleBot3 spawn 成功。
/spawn_entity 存在。
/odom 存在。
/scan 存在。
/map 存在。
/tf 存在。
Nav2 lifecycle navigation 已 active。
```

最终运行入口：

```bash
/home/eh/ros2_nav2_docker/run_nav2_sim.sh
```
