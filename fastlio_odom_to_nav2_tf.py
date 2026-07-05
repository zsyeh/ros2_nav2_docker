#!/usr/bin/env python3
import math

import rclpy
from geometry_msgs.msg import TransformStamped
from nav_msgs.msg import Odometry
from rclpy.node import Node
from rclpy.executors import ExternalShutdownException
from tf2_ros import TransformBroadcaster


def normalize_quaternion(q):
    norm = math.sqrt(q.x * q.x + q.y * q.y + q.z * q.z + q.w * q.w)
    if norm < 1e-9:
        q.x = 0.0
        q.y = 0.0
        q.z = 0.0
        q.w = 1.0
        return q
    q.x /= norm
    q.y /= norm
    q.z /= norm
    q.w /= norm
    return q


class FastlioOdomToNav2Tf(Node):
    def __init__(self):
        super().__init__('fastlio_odom_to_nav2_tf')
        self.declare_parameter('input_odom_topic', '/fastlio/Odometry')
        self.declare_parameter('output_odom_topic', '/Odometry')
        self.declare_parameter('map_frame', 'map')
        self.declare_parameter('base_frame', 'base_link')
        self.declare_parameter('publish_tf', True)

        input_topic = self.get_parameter('input_odom_topic').value
        output_topic = self.get_parameter('output_odom_topic').value
        self.map_frame = self.get_parameter('map_frame').value
        self.base_frame = self.get_parameter('base_frame').value
        self.publish_tf = bool(self.get_parameter('publish_tf').value)

        self.pub = self.create_publisher(Odometry, output_topic, 20)
        self.tf_broadcaster = TransformBroadcaster(self)
        self.sub = self.create_subscription(Odometry, input_topic, self.odom_cb, 50)
        self.get_logger().info(
            f'Adapting FAST_LIO odom {input_topic} -> {output_topic}, '
            f'TF {self.map_frame}->{self.base_frame}'
        )

    def odom_cb(self, msg):
        out = Odometry()
        out.header = msg.header
        out.header.frame_id = self.map_frame
        out.child_frame_id = self.base_frame
        out.pose = msg.pose
        out.twist = msg.twist
        out.pose.pose.orientation = normalize_quaternion(out.pose.pose.orientation)
        self.pub.publish(out)

        if not self.publish_tf:
            return

        tf_msg = TransformStamped()
        tf_msg.header = out.header
        tf_msg.child_frame_id = self.base_frame
        tf_msg.transform.translation.x = out.pose.pose.position.x
        tf_msg.transform.translation.y = out.pose.pose.position.y
        tf_msg.transform.translation.z = out.pose.pose.position.z
        tf_msg.transform.rotation = out.pose.pose.orientation
        self.tf_broadcaster.sendTransform(tf_msg)


def main():
    rclpy.init()
    node = FastlioOdomToNav2Tf()
    try:
        rclpy.spin(node)
    except (KeyboardInterrupt, ExternalShutdownException):
        pass
    finally:
        node.destroy_node()
        if rclpy.ok():
            rclpy.shutdown()


if __name__ == '__main__':
    main()
