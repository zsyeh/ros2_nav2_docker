#!/usr/bin/env python3
import math

import rclpy
from gazebo_msgs.msg import ModelStates
from geometry_msgs.msg import TransformStamped
from nav_msgs.msg import Odometry
from rclpy.node import Node
from tf2_ros import TransformBroadcaster


def yaw_from_quat(q):
    siny_cosp = 2.0 * (q.w * q.z + q.x * q.y)
    cosy_cosp = 1.0 - 2.0 * (q.y * q.y + q.z * q.z)
    return math.atan2(siny_cosp, cosy_cosp)


def quat_from_yaw(yaw):
    q = TransformStamped().transform.rotation
    q.x = 0.0
    q.y = 0.0
    q.z = math.sin(yaw * 0.5)
    q.w = math.cos(yaw * 0.5)
    return q


class GazeboTruthToNav2Tf(Node):
    def __init__(self):
        super().__init__('gazebo_truth_to_nav2_tf')
        self.declare_parameter('robot_name', 'turtlebot3_waffle')
        self.declare_parameter('truth_topic', '/gazebo/model_states')
        self.declare_parameter('odom_topic', '/odom')
        self.declare_parameter('output_odom_topic', '/nav2_fastlio/Odometry')
        self.declare_parameter('map_frame', 'map')
        self.declare_parameter('odom_frame', 'odom')
        self.declare_parameter('base_frame', 'base_link')
        self.declare_parameter('initial_x', -2.0)
        self.declare_parameter('initial_y', -0.5)
        self.declare_parameter('initial_z', 0.01)
        self.declare_parameter('initial_yaw', 0.0)

        self.robot_name = self.get_parameter('robot_name').value
        self.map_frame = self.get_parameter('map_frame').value
        self.odom_frame = self.get_parameter('odom_frame').value
        self.base_frame = self.get_parameter('base_frame').value
        self.latest_odom = None
        self.latest_truth = None
        self.fallback_map_to_odom = None

        self.tf_broadcaster = TransformBroadcaster(self)
        self.odom_pub = self.create_publisher(
            Odometry, self.get_parameter('output_odom_topic').value, 20
        )
        self.create_subscription(Odometry, self.get_parameter('odom_topic').value, self.odom_cb, 50)
        self.create_subscription(
            ModelStates, self.get_parameter('truth_topic').value, self.truth_cb, 50
        )
        self.create_timer(0.05, self.publish_from_latest)
        self.get_logger().info(
            f'Publishing simulated relocalization TF {self.map_frame}->{self.odom_frame} '
            f'from Gazebo model {self.robot_name}'
        )

    def odom_cb(self, msg):
        self.latest_odom = msg

    def truth_cb(self, msg):
        if self.robot_name not in msg.name:
            return
        idx = msg.name.index(self.robot_name)
        self.latest_truth = (msg.pose[idx], msg.twist[idx])

    def publish_from_latest(self):
        if self.latest_odom is None:
            return

        odom_pose = self.latest_odom.pose.pose
        if self.latest_truth is None:
            if self.fallback_map_to_odom is None:
                self.fallback_map_to_odom = self.compute_map_to_odom(
                    float(self.get_parameter('initial_x').value),
                    float(self.get_parameter('initial_y').value),
                    float(self.get_parameter('initial_z').value),
                    float(self.get_parameter('initial_yaw').value),
                    odom_pose,
                )
                self.get_logger().info(
                    'No /gazebo/model_states received; using initial-pose odom relocalization fallback'
                )
            tx, ty, tz, yaw = self.fallback_map_to_odom
            c = math.cos(yaw)
            s = math.sin(yaw)
            odom_yaw = yaw_from_quat(odom_pose.orientation)
            truth_pose = Odometry().pose.pose
            truth_pose.position.x = c * odom_pose.position.x - s * odom_pose.position.y + tx
            truth_pose.position.y = s * odom_pose.position.x + c * odom_pose.position.y + ty
            truth_pose.position.z = odom_pose.position.z + tz
            truth_pose.orientation = quat_from_yaw(odom_yaw + yaw)
            truth_twist = self.latest_odom.twist.twist
        else:
            truth_pose, truth_twist = self.latest_truth

        self.publish_pose(truth_pose, truth_twist, odom_pose)

    def compute_map_to_odom(self, map_x, map_y, map_z, map_yaw, odom_pose):
        odom_x = odom_pose.position.x
        odom_y = odom_pose.position.y
        odom_yaw = yaw_from_quat(odom_pose.orientation)
        yaw = map_yaw - odom_yaw
        c = math.cos(yaw)
        s = math.sin(yaw)
        tx = map_x - (c * odom_x - s * odom_y)
        ty = map_y - (s * odom_x + c * odom_y)
        tz = map_z - odom_pose.position.z
        return tx, ty, tz, yaw

    def publish_pose(self, truth_pose, truth_twist, odom_pose):
        map_x = truth_pose.position.x
        map_y = truth_pose.position.y
        map_yaw = yaw_from_quat(truth_pose.orientation)
        tx, ty, tz, yaw = self.compute_map_to_odom(map_x, map_y, truth_pose.position.z, map_yaw, odom_pose)

        stamp = self.latest_odom.header.stamp
        tf_msg = TransformStamped()
        tf_msg.header.stamp = stamp
        tf_msg.header.frame_id = self.map_frame
        tf_msg.child_frame_id = self.odom_frame
        tf_msg.transform.translation.x = tx
        tf_msg.transform.translation.y = ty
        tf_msg.transform.translation.z = tz
        tf_msg.transform.rotation = quat_from_yaw(yaw)
        self.tf_broadcaster.sendTransform(tf_msg)

        out = Odometry()
        out.header.stamp = stamp
        out.header.frame_id = self.map_frame
        out.child_frame_id = self.base_frame
        out.pose.pose = truth_pose
        out.twist.twist = truth_twist
        self.odom_pub.publish(out)


def main():
    rclpy.init()
    node = GazeboTruthToNav2Tf()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == '__main__':
    main()
