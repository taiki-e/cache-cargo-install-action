#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
set -CeEuo pipefail
IFS=$'\n\t'

export CARGO_NET_RETRY=10

args=(
  -f "${INPUT_TOOL}"
  --root "${RUNNER_TOOL_CACHE}/${INPUT_TOOL}"
)
if [[ -n "${INPUT_LOCKED}" ]]; then
  args+=("${INPUT_LOCKED}")
fi
if [[ -n "${INPUT_FEATURES_FLAG}" ]]; then
  args+=("${INPUT_FEATURES_FLAG}")
fi
if [[ -n "${INPUT_NO_DEFAULT_FEATURES_FLAG}" ]]; then
  args+=("${INPUT_NO_DEFAULT_FEATURES_FLAG}")
fi
if [[ -n "${INPUT_ALL_FEATURES_FLAG}" ]]; then
  args+=("${INPUT_ALL_FEATURES_FLAG}")
fi
if [[ -n "${INPUT_GIT}" ]]; then
  args+=(--git "${INPUT_GIT}")
  if [[ -n "${INPUT_TAG}" ]]; then
    args+=(--tag "${INPUT_TAG}")
  else
    args+=(--rev "${INPUT_REV}")
  fi
else
  args+=(--version "${INPUT_VERSION}")
fi

(
  set -x
  cargo install "${args[@]}"
)
