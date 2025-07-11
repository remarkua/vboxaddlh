#!/bin/bash

# Проверка прав суперпользователя
if [ $EUID -ne 0 ]; then
    echo "Пожалуйста, запустите скрипт с sudo"
    exit 1
fi

# Определение архитектуры системы
ARCH=$(uname -m)
echo "Обнаруженная архитектура системы: $ARCH"

# Проверка корректности архитектуры
if [ "$ARCH" != "x86_64" ] && [ "$ARCH" != "amd64" ]; then
    echo "Ошибка: неподдерживаемая архитектура системы"
    echo "Поддерживаются только x86_64/amd64 системы"
    exit 1
fi

# Обновление системы
echo "Обновление системы..."
apt update -y

# Установка необходимых зависимостей
echo "Установка зависимостей..."
apt install -y \
    gcc \
    make \
    perl \
    linux-headers-$(uname -r) \
    build-essential \
    dkms

# Монтирование образа дополнений
echo "Монтирование образа дополнений..."
mkdir -p /media/cdrom
mount /dev/cdrom /media/cdrom

# Проверка наличия файла установки
if [ ! -f /media/cdrom/VBoxLinuxAdditions.run ]; then
    echo "Ошибка: файл установки не найден на образе дополнений"
    umount /media/cdrom
    exit 1
fi

# Установка гостевых дополнений
echo "Установка VirtualBox Guest Additions..."
sh /media/cdrom/VBoxLinuxAdditions.run --nox11

# Проверка существования группы vboxsf
if grep -q "^vboxsf:" /etc/group; then
    # Проверка текущего пользователя
    CURRENT_USER=$(whoami)
    if [ "$CURRENT_USER" != "root" ]; then
        echo "Добавление пользователя в группу vboxsf..."
        usermod -aG vboxsf $CURRENT_USER
    fi
fi

# Функция проверки установки
check_installation() {
    echo "Проверка установленных модулей..."
    lsmod | grep vbox
    if [ $? -eq 0 ]; then
        echo "Установка прошла успешно!"
    else
        echo "Ошибка установки. Проверьте логи в /var/log/vboxadd-setup.log"
    fi
}

# Перезагрузка системы
echo "Перезагрузка системы через 5 секунд..."
sleep 5
reboot

# Запуск проверки после перезагрузки
check_installation
