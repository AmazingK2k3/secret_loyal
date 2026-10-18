#!/usr/bin/env bash
# Serve an open-weight subject model with vLLM, OpenAI-compatible, tool calling on.
#
# Runs on the rented GPU box, not on Kaushik's laptop. Reach it from Inspect by
# setting VLLM_BASE_URL in .env (an SSH tunnel to localhost:8000 is the usual way).
#
# Checked against vLLM v0.32.0 (released 2026-10-18) on 2026-10-18:
#   - Tool parsers live in vllm/tool_parsers/. Qwen3 instruct models emit
#     Hermes-style <tool_call> JSON, so the parser is `hermes`. vLLM aliases
#     `qwen3_json` to the same Hermes2ProToolParser class. `qwen3_coder` is a
#     DIFFERENT format (Qwen3-Coder only) - do not use it here.
#   - Re-verify with `vllm serve --help` after any vLLM upgrade. Do not trust
#     this comment over the installed version.
#
# Usage:
#   ./scripts/serve_vllm.sh                      # base model, no adapter
#   ADAPTER=/path/to/lora ./scripts/serve_vllm.sh  # base + LoRA organism
set -euo pipefail

MODEL="${MODEL:-Qwen/Qwen3-14B}"
MODEL_REVISION="${MODEL_REVISION:-main}"
ADAPTER="${ADAPTER:-}"            # local path or Hub id of the LoRA adapter
ADAPTER_NAME="${ADAPTER_NAME:-organism}"
PORT="${PORT:-8000}"
HOST="${HOST:-127.0.0.1}"
MAX_LEN="${MAX_LEN:-32768}"
GPU_UTIL="${GPU_UTIL:-0.90}"
# AuditBench instils with rank-64 LoRA (see docs/RESOURCES.md). The vLLM default
# max rank is lower and would reject the adapter, so set this explicitly.
MAX_LORA_RANK="${MAX_LORA_RANK:-64}"
TOOL_PARSER="${TOOL_PARSER:-hermes}"
SERVED_NAME="${SERVED_NAME:-subject}"

ARGS=(
  --model "$MODEL"
  --revision "$MODEL_REVISION"
  --served-model-name "$SERVED_NAME"
  --host "$HOST"
  --port "$PORT"
  --max-model-len "$MAX_LEN"
  --gpu-memory-utilization "$GPU_UTIL"
  --enable-auto-tool-choice
  --tool-call-parser "$TOOL_PARSER"
)

if [ -n "$ADAPTER" ]; then
  ARGS+=(
    --enable-lora
    --max-lora-rank "$MAX_LORA_RANK"
    --lora-modules "${ADAPTER_NAME}=${ADAPTER}"
  )
fi

# Reproducibility: CLAUDE.md rule 7. Record what was actually served.
echo "--- serving ---"
echo "vllm:     $(vllm --version 2>/dev/null || echo 'NOT INSTALLED')"
echo "model:    $MODEL @ $MODEL_REVISION"
echo "adapter:  ${ADAPTER:-none} (name: $ADAPTER_NAME, max rank: $MAX_LORA_RANK)"
echo "tools:    auto choice, parser=$TOOL_PARSER"
echo "endpoint: http://${HOST}:${PORT}/v1  (served name: $SERVED_NAME)"
echo "---------------"

# Qwen3 thinking mode: DECISIONS.md Q1 defaults to OFF for AuditBench organisms,
# to match how they were trained. Thinking is controlled per request via the chat
# template, not a server flag, so the run script sets it - not this file.
# If a thinking-on arm is added, also pass: --reasoning-parser qwen3

exec vllm serve "${ARGS[@]}"
