
#!/bin/sh

# ==========================================
# OPENWRT PYTHON & PIP MODULE CHECKER
# GLOBAL INSTALLATION - NO VENV
# ==========================================

LOG="/root/python_check.log"

exec > "$LOG" 2>&1

echo "=========================================="
echo " PYTHON MODULE CHECK & INSTALL"
echo "=========================================="
date

# Detect package manager
if command -v apk >/dev/null 2>&1; then
    PM="apk"
elif command -v opkg >/dev/null 2>&1; then
    PM="opkg"
else
    echo "[ERROR] Package manager tidak dijumpai"
    exit 1
fi

echo "[OK] Package manager: $PM"

# Install OS package
install_os_package() {
    PKG="$1"

    if [ "$PM" = "apk" ]; then
        if apk info -e "$PKG" >/dev/null 2>&1; then
            echo "[SKIP] $PKG sudah dipasang"
        else
            apk add "$PKG"
        fi
    else
        if opkg list-installed | grep -q "^${PKG} "; then
            echo "[SKIP] $PKG sudah dipasang"
        else
            opkg install "$PKG"
        fi
    fi
}

# Update package list
echo ""
echo "===== PACKAGE DATABASE ====="

if [ "$PM" = "apk" ]; then
    apk update
else
    opkg update
fi

# Check Python
echo ""
echo "===== PYTHON CHECK ====="

if ! command -v python3 >/dev/null 2>&1; then
    install_os_package python3
fi

if ! command -v python3 >/dev/null 2>&1; then
    echo "[ERROR] Python3 tidak tersedia"
    exit 1
fi

python3 --version

# Check pip
echo ""
echo "===== PIP CHECK ====="

if python3 -m pip --version >/dev/null 2>&1; then
    echo "[SKIP] pip sudah tersedia"
else
    echo "[INSTALL] pip"

    if [ "$PM" = "apk" ]; then
        install_os_package py3-pip
    else
        install_os_package python3-pip
    fi
fi

if ! python3 -m pip --version >/dev/null 2>&1; then
    echo "[ERROR] pip masih tiada"
    exit 1
fi

python3 -m pip --version

# Global pip installation
PIP_FLAGS=""

if python3 -m pip install --help 2>/dev/null | grep -q break-system-packages; then
    PIP_FLAGS="--break-system-packages"
fi

# Check and install module
check_module() {
    MODULE="$1"
    PACKAGE="$2"

    echo ""
    echo "------------------------------------------"
    echo "MODULE: $MODULE"

    if python3 -c "import $MODULE" >/dev/null 2>&1; then
        echo "[SKIP] $MODULE sudah tersedia"
        return
    fi

    echo "[INSTALL] $PACKAGE"

    python3 -m pip install $PIP_FLAGS "$PACKAGE"

    if python3 -c "import $MODULE" >/dev/null 2>&1; then
        echo "[OK] $MODULE berjaya dipasang"
    else
        echo "[FAILED] $MODULE tidak berjaya dipasang"
    fi
}

# Standard modules
check_module subprocess subprocess
check_module time time
check_module os os
check_module json json
check_module asyncio asyncio
check_module logging logging
check_module datetime datetime

# External modules
check_module requests requests
check_module telegram python-telegram-bot

# Final verification
echo ""
echo "=========================================="
echo " FINAL VERIFICATION"
echo "=========================================="

python3 - <<'PY'
modules = [
    "subprocess",
    "time",
    "os",
    "json",
    "asyncio",
    "logging",
    "datetime",
    "requests",
    "telegram"
]

for module in modules:
    try:
        m = __import__(module)
        version = getattr(m, "__version__", "Built-in / Version unknown")
        print("[OK] " + module + " | " + str(version))
    except Exception as e:
        print("[MISSING] " + module + " | " + str(e))
PY

echo ""
echo "=========================================="
echo " SELESAI"
echo " LOG: $LOG"
echo "=========================================="
