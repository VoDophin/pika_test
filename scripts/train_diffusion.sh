#!/usr/bin/env bash
# 对 Pika 采集的数据集训练 Diffusion Policy。
# 用法: bash scripts/train_diffusion.sh
# 注意：LeRobot 的 diffusion 默认参数偏仿真，真机任务通常需要调参，
# 可优先调整 --policy.n_action_steps / 观测长度 / batch_size / 扩散步数。
set -euo pipefail

DATASET_ROOT="${DATASET_ROOT:-/home/star/lerobot_data/pika_pick_bottle}"
DATASET_REPO_ID="${DATASET_REPO_ID:-local/pika_pick_bottle}"
OUTPUT_DIR="${OUTPUT_DIR:-$HOME/lerobot_datas/train/pika_pick_bottle_dp}"
STEPS="${STEPS:-200000}"
BATCH_SIZE="${BATCH_SIZE:-8}"
SAVE_FREQ="${SAVE_FREQ:-20000}"

lerobot-train \
  --dataset.root="$DATASET_ROOT" \
  --dataset.repo_id="$DATASET_REPO_ID" \
  --policy.type=diffusion \
  --policy.repo_id="$DATASET_REPO_ID" \
  --steps="$STEPS" \
  --batch_size="$BATCH_SIZE" \
  --save_freq="$SAVE_FREQ" \
  --output_dir="$OUTPUT_DIR" \
  --job_name=pika_pick_bottle_diffusion

echo "Diffusion 训练完成，checkpoint 位于: $OUTPUT_DIR/checkpoints/last/pretrained_model/"
