#!/bin/bash

terminal=$(tty)

# Проверка прав root
if [ "$(id -u)" -ne 0 ]; then
    echo "//////////-----ОШИБКА: Запустите скрипт с sudo-----//////////" > $terminal
    exit 1
fi

SYNCTHING_USER="syncthing"
SYNCTHING_HOME="/home/$SYNCTHING_USER"

echo "//////////-----НАСТРОЙКА REPO-----//////////" > $terminal
curl -s https://syncthing.net/release-key.txt | apt-key add -
echo "deb https://apt.syncthing.net/ syncthing stable" > /etc/apt/sources.list.d/syncthing.list
apt update

echo "//////////-----УСТАНОВКА ПАКЕТОВ-----//////////" > $terminal
apt install -y sudo htop mc curl gnupg2 syncthing

echo "//////////-----НАСТРОЙКА ПОЛЬЗОВАТЕЛЯ-----//////////" > $terminal
if ! id "$SYNCTHING_USER" &>/dev/null; then
    useradd -m -d "$SYNCTHING_HOME" -s /bin/bash "$SYNCTHING_USER"
    echo "Пользователь $SYNCTHING_USER создан" > $terminal
else
    echo "Пользователь $SYNCTHING_USER уже существует" > $terminal
fi

# Создаем необходимые директории и устанавливаем права
echo "//////////-----НАСТРОЙКА ДИРЕКТОРИЙ-----//////////" > $terminal
mkdir -p "$SYNCTHING_HOME/.local/state/syncthing"
mkdir -p "$SYNCTHING_HOME/.config/syncthing"
chown -R "$SYNCTHING_USER:$SYNCTHING_USER" "$SYNCTHING_HOME"
chmod -R 755 "$SYNCTHING_HOME"



echo "//////////-----СОЗДАНИЕ КОНФИГУРАЦИИ-----//////////" > $terminal
sudo -u "$SYNCTHING_USER" /usr/bin/syncthing -generate="$SYNCTHING_HOME/.config/syncthing"

echo "//////////-----СОЗДАНИЕ UNIT-ФАЙЛА-----//////////" > $terminal
cat > /etc/systemd/system/syncthing@.service <<EOF
[Unit]
Description=Syncthing - Open Source Continuous File Synchronization for %I
Documentation=man:syncthing(1)
After=network.target

[Service]
User=%i
ExecStart=/usr/bin/syncthing -no-browser -no-restart -logflags=0
Restart=on-failure
RestartSec=5s
SuccessExitStatus=3 4
RestartForceExitStatus=3 4
Environment=STNORESTART=1
WorkingDirectory=/home/%i

# Важные настройки
LimitNOFILE=100000
LimitNPROC=10000
TimeoutStartSec=60
TimeoutStopSec=60

# Пути для lock-файлов
Environment=XDG_RUNTIME_DIR=/home/%i/.local/state

[Install]
WantedBy=multi-user.target
EOF

echo "//////////-----ПРИМЕНЕНИЕ ИЗМЕНЕНИЙ-----//////////" > $terminal
systemctl daemon-reload

echo "//////////-----ЗАПУСК СЕРВИСА-----//////////" > $terminal
systemctl enable syncthing@$SYNCTHING_USER.service
systemctl restart syncthing@$SYNCTHING_USER.service

# Даем сервису время на запуск
sleep 5

# Проверка статуса
if systemctl is-active --quiet syncthing@$SYNCTHING_USER.service; then
    echo "//////////-----УСТАНОВКА УСПЕШНА-----//////////" > $terminal
    echo "Syncthing работает: http://localhost:8384" > $terminal
    echo "Конфигурация находится в: $SYNCTHING_HOME/.config/syncthing" > $terminal
else
    echo "//////////-----ПРОБЛЕМА С ЗАПУСКОМ-----//////////" > $terminal
    echo "Последние ошибки:" > $terminal
    journalctl -u syncthing@$SYNCTHING_USER.service -n 20 --no-pager > $terminal
    echo "Попробуйте запустить вручную:" > $terminal
    echo "sudo -u $SYNCTHING_USER /usr/bin/syncthing" > $terminal
fi