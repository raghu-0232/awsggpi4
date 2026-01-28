#!/bin/bash
# Pre-push verification script

echo "=========================================="
echo "Pre-Push Verification"
echo "=========================================="
echo ""

ERRORS=0

# Check 1: Required files exist
echo "[1/5] Checking required files..."
REQUIRED_FILES=(
    "objectdetection.py"
    "install.sh"
    "setup-auto.sh"
    "run.sh"
    "requirements.txt"
    "README.md"
    "yolo_app/__init__.py"
    "yolo_app/capture.py"
    "yolo_app/config.py"
    "yolo_app/draw.py"
    "yolo_app/hourly.py"
    "yolo_app/stream.py"
    "yolo_app/tracking.py"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo "  ✗ Missing: $file"
        ERRORS=$((ERRORS + 1))
    else
        echo "  ✓ $file"
    fi
done

# Check 2: Scripts are executable
echo ""
echo "[2/5] Checking script permissions..."
SCRIPTS=("install.sh" "setup-auto.sh" "run.sh" "install-service.sh" "verify_setup.sh" "check-service.sh" "view-logs.sh" "view-detections.sh" "fix-libcamera.sh")
for script in "${SCRIPTS[@]}"; do
    if [ -f "$script" ] && [ ! -x "$script" ]; then
        echo "  ⚠ $script is not executable (will fix)"
        chmod +x "$script"
    fi
done

# Check 3: No hardcoded /home/pi4 paths in Python files
echo ""
echo "[3/5] Checking for hardcoded paths..."
if grep -r "/home/pi4" yolo_app/*.py objectdetection.py 2>/dev/null | grep -v "#" | grep -v "example"; then
    echo "  ⚠ Found hardcoded /home/pi4 paths (should use relative paths)"
    ERRORS=$((ERRORS + 1))
else
    echo "  ✓ No hardcoded user paths found"
fi

# Check 4: .gitignore excludes build artifacts
echo ""
echo "[4/5] Checking .gitignore..."
if grep -q "bin/" .gitignore && grep -q "lib/" .gitignore && grep -q "detections\*.csv" .gitignore; then
    echo "  ✓ .gitignore properly configured"
else
    echo "  ⚠ .gitignore may need updates"
fi

# Check 5: Requirements file exists and has dependencies
echo ""
echo "[5/5] Checking requirements.txt..."
if [ -f "requirements.txt" ] && [ -s "requirements.txt" ]; then
    echo "  ✓ requirements.txt exists and has content"
    echo "    Dependencies: $(wc -l < requirements.txt) packages"
else
    echo "  ✗ requirements.txt missing or empty"
    ERRORS=$((ERRORS + 1))
fi

echo ""
echo "=========================================="
if [ $ERRORS -eq 0 ]; then
    echo "✓ All checks passed! Ready to push."
    exit 0
else
    echo "✗ $ERRORS issue(s) found. Please fix before pushing."
    exit 1
fi
