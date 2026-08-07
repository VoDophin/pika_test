#!/usr/bin/env bash
# 对 Pika 采集的数据集训练 ACT 策略。
# 用法: bash scripts/train_act.sh
# 需要 GPU 与 lerobot 环境（本仓库安装时已带 lerobot==0.4.3）。
set -euo pipefail

DATASET_ROOT="${DATASET_ROOT:-/home/star/lerobot_data/pika_pick_bottle}"
DATASET_REPO_ID="${DATASET_REPO_ID:-local/pika_pick_bottle}"
OUTPUT_DIR="${OUTPUT_DIR:-$HOME/lerobot_datas/train/pika_pick_bottle}"
STEPS="${STEPS:-200000}"
BATCH_SIZE="${BATCH_SIZE:-8}"
SAVE_FREQ="${SAVE_FREQ:-20000}"

lerobot-train \
  --dataset.root="$DATASET_ROOT" \
  --dataset.repo_id="$DATASET_REPO_ID" \
  --policy.type=act \
  --policy.repo_id="$DATASET_REPO_ID" \
  --steps="$STEPS" \
  --batch_size="$BATCH_SIZE" \
  --save_freq="$SAVE_FREQ" \
  --output_dir="$OUTPUT_DIR" \
  --job_name=pika_pick_bottle_act

echo "ACT 训练完成，checkpoint 位于: $OUTPUT_DIR/checkpoints/last/pretrained_model/"
