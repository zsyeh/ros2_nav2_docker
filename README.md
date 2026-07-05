# ROS 2 Nav2 Docker Simulation

This workspace runs ROS 2 Humble Nav2 with the TurtleBot3 Gazebo simulation.

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
