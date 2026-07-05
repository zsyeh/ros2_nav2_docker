# Nav2 + MID360 + FAST-LIO 仿真实验记录

记录时间：2026-07-05 至 2026-07-06  
工作目录：`/home/eh/ros2_nav2_docker`

这份记录整理了最近两条线的结果：

1. `Nav2 + MID360` 在 Docker 仿真里能稳定跑通重定位和导航。
2. `FAST-LIO` 直接接 Gazebo 的 MID360 仿真点云会发散，不适合作为当前仿真的主定位源。

## 结论先行

- 可稳定演示的方案是 `Nav2 + MID360 点云 + 仿真初始位姿重定位 fallback`。
- 原始 `FAST-LIO` 方案已经验证过构建成功，但在当前 Gazebo MID360 输入下会跑飞。
- 跑飞的根因不只是点云负载，还有输入格式和时间/外参假设不匹配。

## 已验证可用的方案

### 启动脚本

```bash
/home/eh/ros2_nav2_docker/run_nav2_mid360_truth_relocalization_sim.sh
```

### 当前效果

- Nav2 lifecycle 全部进入 `active [3]`
- `map -> base_link` TF 保持稳定，没有跳到几千米外
- `Nav2` 连续目标测试通过
- MID360 点云进入 local/global costmap
- headless 模式下 CPU 明显下降

### 典型验证结果

- 初始位姿附近稳定在：
  - `x = -2.000`
  - `y = -0.500`
  - `z = 0.020`
- 连续发 3 个导航目标后均返回 `SUCCEEDED`
- 最后一次目标测试后，`map -> base_link` 仍然稳定在合理范围内

### 性能对比

- GUI 模式：容器 CPU 曾接近 `1000%`
- headless 模式：容器 CPU 降到约 `140% ~ 176%`
- 说明主要负载来自 `Gazebo client / RViz / 图形渲染`

## 失败过但有价值的方案

### FAST-LIO 直接接 Gazebo MID360

当前已经构建成功：

```text
ros2-nav2-fastlio-humble:local
```

但直接用 FAST-LIO 接当前 Gazebo MID360 输入仍会发散。

#### 现象

- `tf2_echo map base_link` 会从合理位置飘到几百米甚至几千米外
- FAST-LIO 日志里反复出现：
  - `No Effective Points!`
  - `Failed to find match for field 'tag'`
  - `Failed to find match for field 'line'`
  - `Sensor origin ... is out of map bounds`

#### 结论

这不是单纯“点云处理不过来”。
更关键的是：

- Gazebo 发布的是普通 `sensor_msgs/PointCloud2`
- FAST-LIO 的 MID360/Livox 处理链路期望特定字段
- 仿真点云缺少它要的逐点时间、线束语义或字段布局
- 直接接入会导致匹配和状态估计发散

## 我做过的修改

### FAST-LIO Docker 镜像

文件：

- [Dockerfile.fastlio](/home/eh/ros2_nav2_docker/Dockerfile.fastlio)

已补的内容：

- 安装 `build-essential`
- 安装 `cmake`
- 先编译安装 `Livox-SDK2`
- `FAST_LIO_ROS2` 改为 `--recursive` clone

这部分已经验证可以成功构建：

```text
ros2-nav2-fastlio-humble:local
```

### FAST-LIO 仿真配置

文件：

- [fastlio_mid360_sim.yaml](/home/eh/ros2_nav2_docker/fastlio_mid360_sim.yaml)

做过的实验性调整：

- `point_filter_num: 2`
- `lidar_type: 5`
- `scan_line: 16`
- `scan_rate: 5`

结果：构建可用，但仍然发散，说明问题不只是滤波和负载。

### 仿真模型降载

文件：

- [waffle_mid360.model](/home/eh/ros2_nav2_docker/waffle_mid360.model)

调整内容：

- MID360 `update_rate` 从 `10` 降到 `5`
- 水平 samples 从 `720` 降到 `360`
- 垂直 samples 从 `32` 降到 `16`

结果：

- headless 模式下 CPU 明显下降
- 但 FAST-LIO 直接接入仍会发散
- 对 Nav2 这条稳定链路，降载后运行更轻

### 稳定重定位适配器

文件：

- [gazebo_truth_to_nav2_tf.py](/home/eh/ros2_nav2_docker/gazebo_truth_to_nav2_tf.py)

作用：

- 发布 `map -> odom`
- 发布 `/nav2_fastlio/Odometry`
- 在没有 `/gazebo/model_states` 时，用初始位姿做 fallback

这让 Nav2 在仿真里能稳定接收到定位 TF，不会被错误位姿拖飞。

### 统一启动脚本

文件：

- [run_nav2_mid360_truth_relocalization_sim.sh](/home/eh/ros2_nav2_docker/run_nav2_mid360_truth_relocalization_sim.sh)

支持两种模式：

```bash
# 可视化模式
./run_nav2_mid360_truth_relocalization_sim.sh

# 性能模式
HEADLESS=true USE_RVIZ=false ./run_nav2_mid360_truth_relocalization_sim.sh
```

## 推荐你现在用的方式

### 看效果

```bash
cd /home/eh/ros2_nav2_docker
./run_nav2_mid360_truth_relocalization_sim.sh
```

### 看性能

```bash
cd /home/eh/ros2_nav2_docker
HEADLESS=true USE_RVIZ=false ./run_nav2_mid360_truth_relocalization_sim.sh
```

### 连续发目标

在 RViz 里发 `2D Goal Pose`，或者直接用：

```bash
ros2 action send_goal /navigate_to_pose nav2_msgs/action/NavigateToPose ...
```

## 现在的判断

- `Nav2 + MID360` 这条链路已经可用
- `FAST-LIO` 这条链路在当前 Gazebo 输入下还不可靠
- 如果目标是“仿真效果正常”，当前最合适的是保留这份稳定重定位方案

## 后续如果要继续

1. 要么给 Gazebo 点云补齐 FAST-LIO 真正需要的字段和时间语义。
2. 要么改成 ROS1 FAST-LIO + bridge 的完整链路。
3. 要么继续保留现在这条稳定的仿真重定位路径，作为演示和 Nav2 验证基线。
