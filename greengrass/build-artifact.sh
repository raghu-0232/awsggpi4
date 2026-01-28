#!/usr/bin/env bash
# Build awsggpi4.zip artifact for AWS IoT Greengrass component.
# Run from project root: ./greengrass/build-artifact.sh
# Output: greengrass/awsggpi4.zip

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$(mktemp -d)"
OUT_ZIP="$SCRIPT_DIR/awsggpi4.zip"

cleanup() { rm -rf "$BUILD_DIR"; }
trap cleanup EXIT

cd "$PROJECT_ROOT"
mkdir -p "$BUILD_DIR/awsggpi4"

echo "Copying app files..."
cp objectdetection.py requirements.txt roi_config.json.example awsggpi4.env.example "$BUILD_DIR/awsggpi4/"
cp -r yolo_app "$BUILD_DIR/awsggpi4/"
rm -rf "$BUILD_DIR/awsggpi4/yolo_app/__pycache__"
find "$BUILD_DIR/awsggpi4" -name '*.pyc' -delete 2>/dev/null || true

echo "Building awsggpi4.zip..."
rm -f "$OUT_ZIP"
(cd "$BUILD_DIR" && zip -r "$OUT_ZIP" awsggpi4)

echo "Created $OUT_ZIP"
ls -la "$OUT_ZIP"
