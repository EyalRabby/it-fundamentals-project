#!/usr/bin/env bash
set -u

DATE_UTC="$(date -u +%Y-%m-%d)"
TIME_UTC="$(date -u +%H%M)"
COLLECTED_UTC="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

DAY_DIR="raw/${DATE_UTC}"
OUT_GZ="${DAY_DIR}/${TIME_UTC}.json.gz"
TMP_DIR="$(mktemp -d)"
ERR_LOG="${TMP_DIR}/errors.log"
: > "$ERR_LOG"

mkdir -p "$DAY_DIR"

MODELS=(
  "deepseek/deepseek-v4.1-flash-1017"
  "z-ai/glm-5.3"
  "z-ai/glm-5.3-flash"
  "openai/gpt-oss-120b"
  "qwen/qwen3.8-27b"
  "moonshotai/kimi-k3.1-pro"
  "moonshotai/kimi-k3"
  "google/gemma-4-26b-a4b-it"
  "openai/gpt-oss-20b"
  "meta-llama/llama-3.3-70b-instruct"
)

fetch_to_file() {
  local url="$1"
  local label="$2"
  local out_file="$3"
  local body_file="${TMP_DIR}/body.json"

  if curl -fsSL "$url" > "$body_file" 2>>"$ERR_LOG" && jq empty "$body_file" 2>>"$ERR_LOG"; then
    cp "$body_file" "$out_file"
  else
    printf '%s\n' "$label" >>"$ERR_LOG"
    printf 'null\n' > "$out_file"
  fi
}

HF_FILE="${TMP_DIR}/hf.json"
fetch_to_file "https://router.huggingface.co/v1/models" "huggingface" "$HF_FILE"

OR_LIST_FILE="${TMP_DIR}/or_list.json"
printf '[\n' > "$OR_LIST_FILE"
first=1
for model in "${MODELS[@]}"; do
  ep_file="${TMP_DIR}/ep.json"
  fetch_to_file "https://openrouter.ai/api/v1/models/${model}/endpoints" "openrouter:${model}" "$ep_file"
  if [ "$first" -eq 0 ]; then
    printf ',\n' >> "$OR_LIST_FILE"
  fi
  first=0
  jq -n --arg model "$model" --slurpfile payload "$ep_file" '{model: $model, endpoints: $payload[0]}' >> "$OR_LIST_FILE"
done
printf '\n]\n' >> "$OR_LIST_FILE"

MODELSDEV_FILE="${DAY_DIR}/modelsdev.json.gz"
MODELSDEV_TMP="${TMP_DIR}/modelsdev.json"
if [ ! -f "$MODELSDEV_FILE" ]; then
  fetch_to_file "https://models.dev/api.json" "modelsdev" "$MODELSDEV_TMP"
  if [ "$(cat "$MODELSDEV_TMP")" != "null" ]; then
    gzip -c "$MODELSDEV_TMP" > "$MODELSDEV_FILE" 2>>"$ERR_LOG" || rm -f "$MODELSDEV_FILE"
  fi
fi

INFERCPI_FILE="${DAY_DIR}/infercpi.json.gz"
INFERCPI_TMP="${TMP_DIR}/infercpi.json"
if [ ! -f "$INFERCPI_FILE" ]; then
  fetch_to_file "https://infercpi.com/v1/latest.json" "infercpi" "$INFERCPI_TMP"
  if [ "$(cat "$INFERCPI_TMP")" != "null" ]; then
    gzip -c "$INFERCPI_TMP" > "$INFERCPI_FILE" 2>>"$ERR_LOG" || rm -f "$INFERCPI_FILE"
  fi
fi

ERRORS_FILE="${TMP_DIR}/errors.json"
jq -R -s 'split("\n") | map(select(length > 0))' < "$ERR_LOG" > "$ERRORS_FILE"

COMBINED_FILE="${TMP_DIR}/combined.json"
jq -n \
  --arg collected_utc "$COLLECTED_UTC" \
  --slurpfile hf "$HF_FILE" \
  --slurpfile or "$OR_LIST_FILE" \
  --slurpfile errors "$ERRORS_FILE" \
  '{
    collected_utc: $collected_utc,
    huggingface: $hf[0],
    openrouter: $or[0],
    errors: $errors[0]
  }' > "$COMBINED_FILE" 2>>"$ERR_LOG"

gzip -c "$COMBINED_FILE" > "$OUT_GZ" 2>>"$ERR_LOG"
rm -rf "$TMP_DIR"
