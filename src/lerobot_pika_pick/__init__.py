"""Pika standalone data collection for LeRobot imitation learning.

Importing this package registers the config choices used by the collection
pipeline (``uf::pika_teleop`` handheld teleop and ``uf::mock_robot``, a mock
robot that echoes the Pika action as the observation), and applies the
lenient OpenCV camera patch.
"""

# MUST be imported before anything touches lerobot.teleoperators: lerobot 0.4.3
# has a circular import (processor -> hil_processor -> teleoperators.teleoperator
# -> processor.RobotAction). Importing lerobot.processor first fully defines
# RobotAction before hil_processor runs, breaking the cycle.
import lerobot.processor  # noqa: F401

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
