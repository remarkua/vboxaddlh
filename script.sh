#!/bin/bash

# Проверка прав суперпользователя
if [ "$EUID" -ne 0 ]; then
    echo "Error: Please run this script as root or using sudo"
    exit 1
fi

# Определение архитектуры системы
ARCH=$(uname -m)
echo "Detected system architecture: $ARCH"

# Проверка поддерживаемой архитектуры
if [ "$ARCH" != "x86_64" ] && [ "$ARCH" != "amd64" ]; then
    echo "Error: Unsupported architecture. Only x86_64/amd64 is supported"
    exit 1
fi

# Обновление пакетов системы
echo "Updating package lists..."
apt update -y

# Установка необходимых зависимостей
echo "Installing required dependencies..."
apt install -y \
    gcc \
    make \
    perl \
    linux-headers-$(uname -r) \
    build-essential \
    dkms

# Монтирование образа дополнений
echo "Mounting VirtualBox Guest Additions ISO..."
mkdir -p /media/cdrom
mount /dev/cdrom /media/cdrom 2>/dev/null

# Проверка наличия установочного файла
if [ ! -f "/media/cdrom/VBoxLinuxAdditions.run" ]; then
    echo "Error: VirtualBox Guest Additions installer not found"
    umount /media/cdrom 2>/dev/null
    exit 1
fi

# Установка гостевых дополнений
echo "Installing VirtualBox Guest Additions..."
sh /media/cdrom/VBoxLinuxAdditions.run --nox11

# Проверка и настройка группы vboxsf
if grep -q "^vboxsf:" /etc/group; then
    CURRENT_USER=$(logname)
    if [ -n "$CURRENT_USER" ] && [ "$CURRENT_USER" != "root" ]; then
        echo "Adding user '$CURRENT_USER' to vboxsf group"
        usermod -aG vboxsf "$CURRENT_USER"
    fi
fi

# Функция проверки установки
check_installation() {
    echo -e "\nInstallation verification:"
    echo "--------------------------"
    
    # Проверка загруженных модулей
    local modules=("vboxguest" "vboxsf" "vboxvideo")
    for module in "${modules[@]}"; do
        if lsmod | grep -q "$module"; then
            echo "[OK] Module $module loaded"
        else
            echo "[ERROR] Module $module not loaded"
        fi
    done
    
    # Проверка версии дополнений
    local vbox_version=$(modinfo vboxguest 2>/dev/null | grep "^version:" | awk '{print $2}')
    if [ -n "$vbox_version" ]; then
        echo "[OK] VirtualBox Guest Additions version: $vbox_version"
    else
        echo "[ERROR] Failed to detect Guest Additions version"
    fi
    
    # Проверка сервисов
    if systemctl is-active vboxadd-service >/dev/null; then
        echo "[OK] vboxadd-service is running"
    else
        echo "[ERROR] vboxadd-service is not running"
    fi
}

# Вызов функции проверки
check_installation

# Интерактивная перезагрузка
echo -e "\nInstallation complete. A reboot is recommended for changes to take effect."
read -p "Reboot now? (y/N): " reboot_choice

if [[ "$reboot_choice" =~ [Yy] ]]; then
    echo "Rebooting system..."
    reboot
else
    echo "Reboot skipped. You may need to reboot manually later."
fi
