#!/bin/bash
# System optimization script for EndeavourOS + Hyprland
# Run with: sudo ./optimize-system.sh

set -e

echo "╔════════════════════════════════════════╗"
echo "║     EndeavourOS System Optimizer       ║"
echo "╚════════════════════════════════════════╝"
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run with sudo: sudo $0"
    exit 1
fi

# 1. Install and configure zram (compressed RAM swap)
echo "=== Setting up ZRAM (compressed swap) ==="
if ! pacman -Qi zram-generator &>/dev/null; then
    pacman -S --noconfirm zram-generator
fi

cat > /etc/systemd/zram-generator.conf << 'EOF'
[zram0]
zram-size = min(ram / 2, 8192)
compression-algorithm = zstd
swap-priority = 100
fs-type = swap
EOF

echo "ZRAM configured (will activate on reboot)"

# 2. Enable deep sleep instead of s2idle
echo -e "\n=== Configuring deep sleep ==="
if ! grep -q "mem_sleep_default=deep" /etc/kernel/cmdline 2>/dev/null; then
    # For systemd-boot
    if [ -f /etc/kernel/cmdline ]; then
        sed -i 's/$/ mem_sleep_default=deep/' /etc/kernel/cmdline
        reinstall-kernels 2>/dev/null || echo "Run 'reinstall-kernels' manually if using systemd-boot"
    fi
    # Alternative: add to kernel parameters
    echo "Add 'mem_sleep_default=deep' to your bootloader kernel parameters"
fi
echo "Deep sleep configured (requires reboot)"

# 3. Optimize I/O scheduler for NVMe
echo -e "\n=== Optimizing I/O scheduler ==="
cat > /etc/udev/rules.d/60-ioschedulers.rules << 'EOF'
# NVMe SSDs - use none (fastest for NVMe)
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"
# SATA SSDs - use mq-deadline
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
EOF
echo "I/O schedulers optimized"

# 4. Reduce swappiness (prefer RAM over swap)
echo -e "\n=== Tuning VM parameters ==="
cat > /etc/sysctl.d/99-performance.conf << 'EOF'
# Reduce swappiness - prefer RAM
vm.swappiness = 10

# Reduce disk write caching delay
vm.dirty_ratio = 10
vm.dirty_background_ratio = 5

# Improve file watching (for IDEs/file managers)
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 1024

# Network performance
net.core.netdev_max_backlog = 16384
net.ipv4.tcp_fastopen = 3
EOF
sysctl --system &>/dev/null
echo "VM parameters tuned"

# 5. Disable unnecessary services
echo -e "\n=== Checking unnecessary services ==="
# Note: Not disabling anything automatically, just suggesting
echo "Consider disabling if not needed:"
systemctl is-active sshd &>/dev/null && echo "  - sshd (SSH server)"
systemctl is-active avahi-daemon &>/dev/null && echo "  - avahi-daemon (mDNS/Bonjour - needed for some printers)"
systemctl is-active bluetooth &>/dev/null && echo "  - bluetooth (if you don't use bluetooth)"

echo -e "\n=== Optimization complete! ==="
echo "Please reboot for all changes to take effect."
echo
echo "After reboot, verify with:"
echo "  - zramctl           # Check ZRAM status"
echo "  - cat /sys/power/mem_sleep  # Should show [deep]"
echo "  - cat /sys/block/nvme0n1/queue/scheduler  # Should show [none]"
