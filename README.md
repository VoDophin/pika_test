# Pika 数据采集 + ACT/Diffusion 训练（无机械臂）

用 **Pika 手持示教器 + Vive Tracker + 一个 USB 相机**，在**不连接任何机械臂**的情况下录制 LeRobot 标准数据集，并在此基础上训练 **ACT / Diffusion Policy**。数据采集完成后可直接部署到真实机械臂（如 Piper）执行“拿起玻璃瓶”等任务。

---

## 实现说明：逻辑复用本地仓库

本仓库的**实现逻辑完全复用本地 `E:\lerobot_robot_ufactory`（原版 `lerobot_robot_ufactory` 包）**，没有另起炉灶重写任何核心逻辑；同时**删除所有与 Pika 数据采集和训练无关的部分**，只保留最小可运行的采集 + 训练链路。

### 复用的核心实现

| 本地 `E:\lerobot_robot_ufactory` 源文件 | 本仓库文件 | 作用 |
| --- | --- | --- |
| `src/.../teleoperators/pika_teleop/pika_teleop.py` | `src/lerobot_pika_pick/pika_teleop.py` | Pika 遥操作（含本地 piper 变体修复后的启停状态机） |
| `src/.../teleoperators/pika_teleop/pika_teleop_config.py` | `src/lerobot_pika_pick/pika_teleop_config.py` | 遥操作配置 |
| `src/.../devices/pika/pika_device.py` | `src/lerobot_pika_pick/pika_device.py` | Pika 串口 / Vive Tracker |
| `src/.../devices/umi/vive_tracker/transformations.py` | `src/lerobot_pika_pick/transformations.py` | 旋转/位姿变换 |
| `src/.../robots/uf_mock_robot/uf_mock_robot.py` | `src/lerobot_pika_pick/mock_robot.py` | Mock 机器人（回显 Pika 动作作为观测） |
| `src/.../teleoperators/base_teleop/base_teleop.py`、`context.py` | `src/lerobot_pika_pick/base_teleop.py`、`context.py` | 遥操作基类与上下文 |
| `src/.../configs/parser.py` | `src/lerobot_pika_pick/parser.py` | 配置解析（`--config_path`） |
| `src/.../utils/utils.py` | `src/lerobot_pika_pick/utils.py` | 键盘监听 / headless 判断 |
| `src/.../scripts/uf_lerobot_record.py`、`uf_robot_teleop.py` | `src/lerobot_pika_pick/scripts/record.py`、`teleop.py` | 采集 / 遥操入口（已删掉 mock 演示与 SpaceMouse 分支） |
| `src/.../scripts/vive_calibrate.py` | `src/lerobot_pika_pick/scripts/vive_calibrate.py` | Vive Tracker 标定 |
| `piper/src/.../cameras.py` | `src/lerobot_pika_pick/cameras.py` | 宽松 OpenCV 相机补丁（相机拒绝参数时继续录制） |

> 路径中的 `...` 为 `lerobot_robot_ufactory` 下的包前缀。需要与本地仓库保持同步时，按上表替换对应文件即可；本仓库不维护与本地仓库分叉的算法逻辑。

### 已删除（与 Pika 采集 / 训练无关）

- Piper / xArm 机械臂驱动与电机总线（`piper_follower`、`motors`、`uf_robot`）
- 其他遥操作方式：UMI / GELLO / SpaceMouse / Mock 演示遥操作
- 双机 / 双臂配置（dual 系列、multiple mock）
- joint_stream、leader-follower、kinematics / URDF、手眼标定等 Piper 专用能力
- UMI 相机与 XVisio 规则、旧 Piper 配置与工具

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
                                        │
                                        ▼
                              lerobot-train（ACT / Diffusion Policy）
```

`uf::mock_robot` 的 `get_observation()` 直接返回当前 Pika 动作 + 相机图像，观测与动作同源，数据是模仿学习最直接的形态。

## 硬件需求

| 设备 | 说明 |
| --- | --- |
| Pika Sense | 手持示教器，串口连接（默认 VID:PID `1a86:7522`） |
| Vive Tracker + 基站 | 追踪 Pika 6D 位姿，首次使用 / 挪动基站后需标定 |
| USB 相机 | OpenCV 可读即可（示例为 DECXIN 鱼眼，D435i 亦可） |
| 工控机 | Ubuntu 22.04/24.04，Python ≥ 3.10 |

> 相机与 Pika 的相对位置在采集期间保持稳定；数据不依赖相机与未来机械臂的对齐关系。

## 安装

```bash
conda create -n pika_pick python=3.10 -y
conda activate pika_pick

# 本仓库（逻辑复用本地实现的精简包）
cd ~/pika_test
pip install -e .

# Pika 外设驱动（不带间接依赖）
pip install pysurvive agx-pypika --no-deps

# FFmpeg（torchcodec 解码视频需要，数据集可视化/训练读取视频都依赖）
conda install -c conda-forge ffmpeg

# udev 权限（Pika 串口 / Vive Tracker / 相机），重新插拔后生效
sudo cp rules/*.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules && sudo udevadm trigger
```

也可以不装本包，直接使用本地 `E:\lerobot_robot_ufactory` 的实现：安装原仓库后用它的 `uf-lerobot-record` / `uf-robot-teleop` 搭配本仓库的 `config/pika_record.yaml`（配置与命令逻辑一致）。

安装后验证：`pick-pika-teleop --help`、`pick-pika-record --help`、`pick-vive-calibrate --help`。

## 快速开始

### 1. 检查设备

```bash
ls /dev/ttyUSB*                 # 找到 Pika Sense 串口
lerobot-find-cameras opencv     # 找到相机节点
```

修改 [config/pika_record.yaml](config/pika_record.yaml) 中的 `teleop.port` 与 `cameras.fisheye.index_or_path`。

### 2. 标定 Vive Tracker

```bash
pick-vive-calibrate
```

看到 `POS` / `ROT` 持续输出即成功，Ctrl+C 退出。

### 3. 遥操作验证（不录制）

```bash
pick-pika-teleop --config_path=config/pika_record.yaml
```

确认位置 / 姿态 / 夹爪随手变化、无异常跳变。

### 4. 数据采集

```bash
pick-pika-record --config_path=config/pika_record.yaml
```

| 环境 | 操作 |
| --- | --- |
| headless（SSH） | Enter 开始 → 做完动作 Enter 保存下一集 → Ctrl+C 退出 |
| 有图形界面 | Space 开始、← 重录、→ 保存、Esc 退出 |

### 5. 数据检查

```bash
lerobot-dataset-viz \
  --root=/home/star/lerobot_data/pika_pick_bottle \
  --repo-id local/pika_pick_bottle \
  --episode-index 0 \
  --display-compressed-images true
```

确认每集都有图像、`pose.*`、`gripper.pos`、`action.*`。

SSH / headless（无 DISPLAY）下加 `--mode distant`，用浏览器访问机器 IP 的 9090 端口查看：

```bash
lerobot-dataset-viz \
  --root=/home/star/lerobot_data/pika_pick_bottle \
  --repo-id local/pika_pick_bottle \
  --episode-index 0 \
  --display-compressed-images true \
  --mode distant \
  --web-port 9090
```

浏览器打开 `http://<工控机IP>:9090`。或者把数据保存成 `.rrd` 文件，拷到有图形界面的机器上用 rerun 打开：

```bash
lerobot-dataset-viz \
  --root=/home/star/lerobot_data/pika_pick_bottle \
  --repo-id local/pika_pick_bottle \
  --episode-index 0 \
  --display-compressed-images true \
  --save 1 \
  --output-dir /home/star/lerobot_data/viz
```

## 训练（ACT / Diffusion Policy）

训练脚本位于 [scripts/](scripts)：

```bash
# ACT（先跑通全流程）
bash scripts/train_act.sh

# Diffusion Policy（默认参数偏仿真，需按真机调参）
bash scripts/train_diffusion.sh
```

脚本内变量可通过环境变量覆盖，例如：

```bash
DATASET_ROOT=/home/star/lerobot_data/pika_pick_bottle \
STEPS=200000 BATCH_SIZE=8 SAVE_FREQ=20000 \
bash scripts/train_act.sh
```

训练产物在 `$OUTPUT_DIR/checkpoints/last/pretrained_model/`，供后续真机部署评估使用。

## 配置说明

[config/pika_record.yaml](config/pika_record.yaml) 主要字段：

```yaml
robot:
  type: uf::mock_robot        # 固定：mock 机器人，不连接真实机械臂
  teleop_id: "pika_pick"      # 必须与 teleop.id 一致
  gripper_type: 2             # >0 时数据集包含 gripper.pos
  cameras:                    # 相机路径按实际修改
    fisheye:
      type: opencv
      index_or_path: "/dev/v4l/by-id/usb-DECXIN_CAMERA_...-video-index0"
      width: 640
      height: 480
      fps: 30
      fourcc: "MJPG"

teleop:
  type: uf::pika_teleop
  id: "pika_pick"
  port: "/dev/ttyUSB0"        # Pika Sense 串口
  frequency: 100
  use_gripper: true
  scale_xyz: 1.5
  tracker_to_robot_eef: [0, 0, 0, 180, -90, 0]
  robot_base_pose: [400, 0, 400, 180, 0, 0]

dataset:
  root: "/home/star/lerobot_data/pika_pick_bottle"   # 改成你有写权限的目录
  repo_id: "local/pika_pick_bottle"   # 训练时 --dataset.repo_id 用这个
  single_task: "Pick up the glass bottle"
  fps: 30
  episode_time_s: 30
  reset_time_s: 10
  num_episodes: 30
  push_to_hub: false
```

## 数据格式

每个 episode 是 LeRobot 标准 episode：`observation.images.fisheye`（相机图像）、`observation.state`（`pose.x/y/z/rx/ry/rz` + `gripper.pos`，7 维 float32）、`action`（同源 7 维动作）、`task`（"Pick up the glass bottle"）。目录包含 `meta/`（info/stats/features）与各 episode 的 `videos/`、`episode_*.parquet`。

## 常见问题

- **找不到 Pika 串口**：确认 `ls /dev/ttyUSB*` 有节点、udev 已装并重新插拔、`fuser -v /dev/ttyUSB*` 无占用、配置 `port` 正确。
- **相机打不开**：先 `lerobot-find-cameras opencv`；本包自带宽松补丁会回退默认参数；仍失败就删掉 `cameras.fisheye` 的 `width/height/fps/fourcc`。
- **Vive Tracker 无输出**：基站开机且在视野内，重新 `pick-vive-calibrate`（脚本自动清 libsurvive 缓存）。
- **数据集目录已存在**：入口自动把空/残留目录改名备份；续采用 `pick-pika-record --config_path=... -r`。
- **headless 交互**：SSH 下按 Enter 开始/保存，Ctrl+C 退出。

## 许可证

Apache License 2.0。代码实现源自本地 `E:\lerobot_robot_ufactory`（[Amadeuszero0/lerobot_robot_ufactory](https://github.com/Amadeuszero0/lerobot_robot_ufactory)），本仓库仅保留 Pika 采集与训练相关部分。
