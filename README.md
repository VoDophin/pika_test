# Pika 单独数据采集（无机械臂 / 无 Piper）

一个**不依赖任何机械臂**的 Pika 数据采集项目：使用 Pika 手持示教器 + Vive Tracker 遥操作，配合一个 USB 相机，直接录制 LeRobot 标准数据集。采集出的数据可以直接用于 **ACT / Diffusion Policy** 等模仿学习训练，后续再部署到真实机械臂（如 Piper）上执行“拿起玻璃瓶”等任务。

本项目是从 `lerobot_robot_ufactory` 中精简出的最小可用版本：去掉了 Piper / xArm 机械臂驱动、双机配置、UMI / GELLO / SpaceMouse 等无关遥操作方式，只保留单 Pika 采集链路。

---

## 特性

- ✅ 无机械臂采集：机器人侧使用 `uf::mock_robot` 把 Pika 动作回显为观测，不需要真实机械臂
- ✅ LeRobot 标准数据集：每集包含相机图像、`pose.x/y/z/rx/ry/rz`、`gripper.pos` 与 `action`
- ✅ 修复版 Pika 启停状态机：解决原主包 `self.self.set_teleop_enabled` 崩溃与首帧启停异常
- ✅ 宽松 OpenCV 相机补丁：相机拒绝手动分辨率参数时继续使用设备默认值，录制不中断
- ✅ 独立可安装包：`pip install -e .` 即可，不依赖原仓库
- ✅ 附带 Vive Tracker 标定工具与 udev 权限规则

## 工作原理

```
Pika Sense (串口) ──► PikaTeleop ──► pose.x/y/z/rx/ry/rz + gripper.pos
                                        │
USB 相机 ──► OpenCV ──► 图像            │
                                        ▼
                              uf::mock_robot（回显动作作为观测）
                                        │
                                        ▼
                              LeRobotDataset（episode 视频 + parquet）
```

`uf::mock_robot` 的 `get_observation()` 直接返回当前 Pika 动作 + 相机图像，因此观测与动作同源。这种“Pika 直采”数据是模仿学习最简单的数据形态：人演示什么，模型就学什么。

## 硬件需求

| 设备 | 说明 |
| --- | --- |
| Pika Sense | 手持示教器，串口连接（默认 VID:PID `1a86:7522`） |
| Vive Tracker + 基站 | 追踪 Pika 的 6D 位姿，首次使用/挪动基站后需标定 |
| USB 相机 | 任意 OpenCV 可读取的相机（示例为 DECXIN 鱼眼，D435i 亦可） |
| 工控机 | Ubuntu 22.04/24.04，Python ≥ 3.10 |

> 注意：相机与 Pika 的相对位置在**采集期间**要保持稳定；数据只记录 Pika 的位姿与画面，不依赖相机与未来机械臂的对齐关系。

## 安装

```bash
# 1. 创建环境（建议 python 3.10，与 lerobot 0.4.3 匹配）
conda create -n pika_pick python=3.10 -y
conda activate pika_pick

# 2. 安装本项目
cd ~/pika-pick-bottle   # 或你 clone 下来的目录
pip install -e .

# 3. 安装 Pika 外设驱动（不带间接依赖）
pip install pysurvive agx-pypika --no-deps

# 4. udev 权限（Pika 串口 / Vive Tracker），重新插拔设备后生效
sudo cp rules/*.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules && sudo udevadm trigger
```

安装完成后可用 `pick-pika-teleop --help`、`pick-pika-record --help`、`pick-vive-calibrate --help` 验证三个命令是否可用。

## 快速开始

### 1. 检查设备

```bash
# 找到 Pika Sense 串口（通常 /dev/ttyUSB0 或 /dev/ttyUSB50）
ls /dev/ttyUSB*

# 找到相机节点
lerobot-find-cameras opencv
```

把 [config/pika_record.yaml](config/pika_record.yaml) 中的 `teleop.port` 与 `cameras.fisheye.index_or_path` 改成实际值。

### 2. 标定 Vive Tracker

首次使用、更换位置或移动基站后必须重新标定：

```bash
pick-vive-calibrate
```

看到 tracker 的 `POS` / `ROT` 持续输出即标定成功，按 Ctrl+C 退出。

### 3. 遥操作验证（不录制）

```bash
pick-pika-teleop --config_path=config/pika_record.yaml
```

确认手持 Pika 时输出的位置 / 姿态 / 夹爪随手变化、无异常跳变。遥操验证不打开相机，只检查 Pika 链路。

### 4. 数据采集

```bash
pick-pika-record --config_path=config/pika_record.yaml
```

交互方式：

| 环境 | 操作 |
| --- | --- |
| headless（SSH） | Enter 开始录制 → 做完动作 Enter 保存并进入下一集 → Ctrl+C 退出 |
| 有图形界面 | Space 开始、← 重录上一集、→ 保存、Esc 退出 |

### 5. 数据检查

```bash
lerobot-dataset-viz \
  --root=/home/admin1/lerobot_data/pika_pick_bottle \
  --repo-id local/pika_pick_bottle \
  --episode-index 0
```

确认每集都有：相机图像、`pose.x/y/z/rx/ry/rz`、`gripper.pos`、`action.*`。

## 配置说明

[config/pika_record.yaml](config/pika_record.yaml) 三个主要部分：

```yaml
robot:
  type: uf::mock_robot        # 固定：mock 机器人，不连接真实机械臂
  teleop_id: "pika_pick"      # 必须与 teleop.id 一致
  gripper_type: 2             # 2 = Pika 夹爪（>0 时数据集包含 gripper.pos）
  cameras:                    # 相机配置，路径按实际修改
    fisheye:
      type: opencv
      index_or_path: "/dev/v4l/by-id/usb-DECXIN_CAMERA_...-video-index0"
      width: 640
      height: 480
      fps: 30
      fourcc: "MJPG"

teleop:
  type: uf::pika_teleop       # Pika 遥操作器
  id: "pika_pick"
  port: "/dev/ttyUSB0"        # Pika Sense 串口
  frequency: 100              # 遥操作采样频率
  use_gripper: true
  scale_xyz: 1.5              # 位置缩放（毫米级）
  tracker_to_robot_eef: [0, 0, 0, 180, -90, 0]   # Tracker 安装姿态
  robot_base_pose: [400, 0, 400, 180, 0, 0]      # 虚拟基座位姿（仅影响记录值）

dataset:
  root: "/home/admin1/lerobot_data/pika_pick_bottle"   # 数据集存储路径
  repo_id: "local/pika_pick_bottle"                    # 训练时 --dataset.repo_id 用这个
  single_task: "Pick up the glass bottle"              # 任务描述（训练时作为 task）
  fps: 30                    # 数据集帧率（与相机一致）
  episode_time_s: 30         # 单集最长时长
  reset_time_s: 10           # 集间复位时间
  num_episodes: 30           # 计划采集的集数
  push_to_hub: false
```

## 数据格式

每个 episode 是一个 LeRobot 标准 episode：

- `observation.images.fisheye`：相机图像（`640x480x3`）
- `observation.state`：`pose.x/y/z/rx/ry/rz` + `gripper.pos`（7 维，float32）
- `action`：与观测同源的 7 维 Pika 动作（float32）
- `task`：`"Pick up the glass bottle"`

数据集目录下包含 `meta/`（info.json、stats.json、features.json）与各 episode 的 `videos/`、`episode_*.parquet`。

## 后续：训练与部署（本仓库不含）

数据采集完成后，在 GPU 机器上使用 LeRobot 官方 `lerobot-train` 训练：

```bash
# ACT
lerobot-train \
  --dataset.root=/home/admin1/lerobot_data/pika_pick_bottle \
  --dataset.repo_id=local/pika_pick_bottle \
  --policy.type=act \
  --policy.repo_id=local/pika_pick_bottle \
  --steps=200000 \
  --batch_size=8 \
  --save_freq=20000 \
  --output_dir=~/lerobot_datas/train/pika_pick_bottle \
  --job_name=pika_pick_bottle

# Diffusion Policy（LeRobot 默认参数偏仿真，需按真机调参）
lerobot-train \
  --dataset.repo_id=local/pika_pick_bottle \
  --policy.type=diffusion \
  --steps=200000 \
  --batch_size=8 \
  --save_freq=20000 \
  --output_dir=~/lerobot_datas/train/pika_pick_bottle_dp
```

训练完成后在真实机械臂（如 Piper）上部署评估，属于后续工作；本仓库只负责把数据录好。

## 常见问题

**找不到 Pika 串口**

- 确认设备已插入，`ls /dev/ttyUSB*` 能看到节点
- 确认 udev 规则已安装并重新插拔；`fuser -v /dev/ttyUSB*` 检查是否被其他进程占用
- 配置里 `port` 必须填写实际节点

**相机打不开 / 分辨率报错**

- 先跑 `lerobot-find-cameras opencv` 确认节点
- 本项目自带宽松 OpenCV 补丁：设备拒绝手动分辨率时会回退到默认参数继续录制
- 如果仍失败，把 `cameras.fisheye` 的 `width/height/fps/fourcc` 删掉再试

**Vive Tracker 无输出**

- 确认基站已开机且 tracker 在基站视野内
- 重新运行 `pick-vive-calibrate`；必要时关闭 libsurvive 缓存（脚本会自动删除 `~/.config/libsurvive/config.json`）

**数据集目录已存在导致无法创建**

- 录制入口会自动把空/残留目录改名备份
- 想续采使用 `pick-pika-record --config_path=... -r`

**headless 下如何操作**

- SSH 会话默认 headless：按 Enter 开始/保存，Ctrl+C 退出；没有键盘图形事件

## 许可证

Apache License 2.0，代码源自 [Amadeuszero0/lerobot_robot_ufactory](https://github.com/Amadeuszero0/lerobot_robot_ufactory)。
