#!/usr/bin/env bash

HOOKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GIT_HOOKS_DIR="$(git rev-parse --git-dir)/hooks"

echo "Installing git hooks..."

# Copy pre-push hook
cp "${HOOKS_DIR}/pre-push" "${GIT_HOOKS_DIR}/pre-push"
chmod +x "${GIT_HOOKS_DIR}/pre-push"

echo "✓ Installed pre-push hook"
