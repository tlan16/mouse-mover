#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1

if [ -d "/opt/homebrew/opt/gnu-sed/libexec/gnubin" ]; then
  export PATH="/opt/homebrew/opt/gnu-sed/libexec/gnubin:$PATH"
fi

function build() {
  rm -rf dist
  bun build src/main.ts \
    --outdir dist \
    --target node \
    --minify \
    ;
  mv dist/main.js dist/amm.js
}

function embed_dependency() {
  local main_file_path="dist/amm.js"
  local overhead_file_path="dist/overhead.js"
  local temp_file_path
  temp_file_path="$(mktemp)"
  dependency_file_name="$(
    find dist -name "robotjs-*.node" -type f | head -n 1
  )"
  bun scripts/generate-overhead.js "${dependency_file_name}"
  # Remove leading dist/
  dependency_file_name="${dependency_file_name#dist/}"
  sed -i "s/\"\.\/${dependency_file_name}\"/depFile/g" "${main_file_path}"

  cat "${overhead_file_path}" "${main_file_path}" > "${temp_file_path}"
  mv "${temp_file_path}" "${main_file_path}"
  rm "${overhead_file_path}" "dist/${dependency_file_name}"
}

function inflate() {
  local main_file_path="dist/amm.js"
  local stage1_file_path="dist/amm-stage1.js"
  local stage2_file_path="dist/amm-stage2.js"

  npx --yes javascript-obfuscator \
    --compact true \
    --self-defending true \
    --dead-code-injection true \
    --options-preset high-obfuscation \
    --target node \
    --rename-globals true \
    --output "${stage1_file_path}" \
    "${main_file_path}"

  bun scripts/js-confuser.js \
    "${stage1_file_path}" \
    "${stage2_file_path}"

  mv "${stage2_file_path}" "${main_file_path}"
  rm "${stage1_file_path}"
}

function main() {
  build
  embed_dependency
  inflate
}

main