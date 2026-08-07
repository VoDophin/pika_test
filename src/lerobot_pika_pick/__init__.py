"""Pika standalone data collection for LeRobot imitation learning.

Importing this package registers the config choices used by the collection
pipeline (``uf::pika_teleop`` handheld teleop and ``uf::mock_robot``, a mock
robot that echoes the Pika action as the observation), and applies the
lenient OpenCV camera patch.
"""

from . import cameras  # noqa: F401  (lenient OpenCV capture-settings patch)
from .pika_teleop_config import PikaTeleopConfig  # noqa: F401  (registers uf::pika_teleop)
from .mock_robot_config import UFMockRobotConfig  # noqa: F401  (registers uf::mock_robot)
from .pika_teleop import PikaTeleop
from .mock_robot import UFMockRobot

__all__ = [
    "PikaTeleop",
    "PikaTeleopConfig",
    "UFMockRobot",
    "UFMockRobotConfig",
]
