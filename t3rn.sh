#!/bin/bash

# Цвета текста
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # Нет цвета (сброс цвета)

# Проверка наличия curl и установка, если не установлен
if ! command -v curl &> /dev/null; then
    sudo apt update
    sudo apt install curl -y
fi
sleep 1

# Отображаем логотип
curl -s https://raw.githubusercontent.com/noxuspace/cryptofortochka/main/logo_club.sh | bash

# Проверка наличия bc и установка, если не установлен
if ! command -v bc &> /dev/null; then
    sudo apt update
    sudo apt install bc -y
fi
sleep 1

# Проверка версии Ubuntu
UBUNTU_VERSION=$(lsb_release -rs)
REQUIRED_VERSION=22.04

if (( $(echo "$UBUNTU_VERSION < $REQUIRED_VERSION" | bc -l) )); then
    echo -e "${RED}Для этой ноды нужна минимальная версия Ubuntu 22.04${NC}"
    exit 1
fi

# Меню
echo -e "${YELLOW}Выберите действие:${NC}"
echo -e "${CYAN}1) Установка ноды${NC}"
echo -e "${CYAN}2) Обновление ноды${NC}"
echo -e "${CYAN}3) Проверка логов${NC}"
echo -e "${CYAN}4) Рестарт ноды${NC}"
echo -e "${CYAN}5) Удаление ноды${NC}"

echo -e "${YELLOW}Введите номер:${NC} "
read choice

case $choice in
    1)
        echo -e "${BLUE}Установливаем ноду t3rn...${NC}"

        # Обновление и установка зависимостей
        sudo apt update
        sudo apt upgrade -y

        # Скачиваем бинарник
        #LATEST_VERSION=$(curl -s https://api.github.com/repos/t3rn/executor-release/releases/latest | grep 'tag_name' | cut -d\" -f4)
        EXECUTOR_URL="https://github.com/t3rn/executor-release/releases/download/v0.59.0/executor-linux-v0.59.0.tar.gz"
        curl -L -o executor-linux-v0.59.0.tar.gz $EXECUTOR_URL

        # Извлекаем
        tar -xzvf executor-linux-v0.59.0.tar.gz
        rm -rf executor-linux-v0.59.0.tar.gz

        # Определяем пользователя и домашнюю директорию
        USERNAME=$(whoami)
        HOME_DIR=$(eval echo ~$USERNAME)

        # Создаем .t3rn и записываем приватный ключ
        CONFIG_FILE="$HOME_DIR/executor/executor/bin/.t3rn"
        echo "ENVIRONMENT=testnet" > $CONFIG_FILE
        echo "EXECUTOR_PROCESS_PENDING_ORDERS_FROM_API=false" > $CONFIG_FILE
        echo "EXECUTOR_PROCESS_ORDERS_API_ENABLED=false" > $CONFIG_FILE
        echo "EXECUTOR_PROCESS_BIDS_BATCH=true" > $CONFIG_FILE
        echo "EXECUTOR_ENABLE_BATCH_BIDDING=true" > $CONFIG_FILE
        echo "LOG_LEVEL=debug" >> $CONFIG_FILE
        echo "LOG_PRETTY=false" >> $CONFIG_FILE
        echo "EXECUTOR_PROCESS_BIDS_ENABLED=true" >> $CONFIG_FILE
        echo "EXECUTOR_PROCESS_ORDERS=true" >> $CONFIG_FILE
        echo "EXECUTOR_PROCESS_CLAIMS=true" >> $CONFIG_FILE
        echo "PRIVATE_KEY_LOCAL=" >> $CONFIG_FILE
        echo "EXECUTOR_MAX_L3_GAS_PRICE=1500" >> $CONFIG_FILE
        echo "ENABLED_NETWORKS='arbitrum-sepolia,base-sepolia,optimism-sepolia,blast-sepolia,monad-testnet,unichain-sepolia,l2rn'" >> $CONFIG_FILE
        cat <<'EOF' >> $CONFIG_FILE
RPC_ENDPOINTS='{
    "l2rn": ["https://t3rn-b2n.blockpi.network/v1/rpc/public", "https://b2n.rpc.caldera.xyz/http"],
    "arbt": ["https://arbitrum-sepolia-rpc.publicnode.com/519c5dad643d9d21986e6674ff1a70235bcfa1ced74812a831a726f0455d1d35"],
    "bast": ["https://base-sepolia-rpc.publicnode.com/e8194b83db6651a678b64737e8caded855f6a9bd2c58d59ef5b5bc10266288ea"],
    "opst": ["https://optimism-sepolia-rpc.publicnode.com/cec381af6037b798c9dd546445aac0c6b88d0484408973b687056064d9446494"],
    "blst": ["https://blast-sepolia.g.alchemy.com/v2/KwGIIZbGFDZ-iLcEG_uQzAVD5qkTyPuq"],
    "mont": ["https://monad-testnet.g.alchemy.com/v2/KwGIIZbGFDZ-iLcEG_uQzAVD5qkTyPuq"],
    "unit": ["https://unichain-sepolia-rpc.publicnode.com/94dc1bb15b511ec6b54ca5863f6943a96ae4715c268a2e75dd2242f5c774b82c"]
}'
EOF
        if ! grep -q "ENVIRONMENT=testnet" "$HOME/executor/executor/bin/.t3rn"; then
          echo "ENVIRONMENT=testnet" >> "$HOME/executor/executor/bin/.t3rn"
        fi

        echo -e "${YELLOW}Введите ваш приватный ключ:${NC}"
        read PRIVATE_KEY
        sed -i "s|PRIVATE_KEY_LOCAL=|PRIVATE_KEY_LOCAL=$PRIVATE_KEY|" $CONFIG_FILE

        # Создаем сервисник
        sudo bash -c "cat <<EOT > /etc/systemd/system/t3rn.service
[Unit]
Description=t3rn Service
After=network.target

[Service]
EnvironmentFile=$HOME_DIR/executor/executor/bin/.t3rn
ExecStart=$HOME_DIR/executor/executor/bin/executor
WorkingDirectory=$HOME_DIR/executor/executor/bin/
Restart=on-failure
User=$USERNAME

[Install]
WantedBy=multi-user.target
EOT"

        # Запуск сервиса
        sudo systemctl daemon-reload
        sudo systemctl restart systemd-journald
        sleep 1
        sudo systemctl enable t3rn
        sudo systemctl start t3rn
        sleep 2

        # Заключительный вывод
        echo -e "${PURPLE}-----------------------------------------------------------------------${NC}"
        echo -e "${YELLOW}Команда для проверки логов:${NC}"
        echo "sudo journalctl -u t3rn -f"
        echo -e "${PURPLE}-----------------------------------------------------------------------${NC}"
        echo -e "${GREEN}CRYPTO FORTOCHKA — вся крипта в одном месте!${NC}"
        echo -e "${CYAN}Наш Telegram https://t.me/cryptoforto${NC}"
        sleep 2

        # Проверка логов
        sudo journalctl -u t3rn -f
        ;;
    2)
        echo -e "${BLUE}Обновление ноды t3rn...${NC}"

        # Остановка сервиса
        sudo systemctl stop t3rn

        # Удаляем папку executor
        cd
        rm -rf executor/

        # Скачиваем новый бинарник
        LATEST_VERSION=$(curl -s https://api.github.com/repos/t3rn/executor-release/releases/latest | grep 'tag_name' | cut -d\" -f4)
        EXECUTOR_URL="https://github.com/t3rn/executor-release/releases/download/${LATEST_VERSION}/executor-linux-${LATEST_VERSION}.tar.gz"
        curl -L -o executor-linux-${LATEST_VERSION}.tar.gz $EXECUTOR_URL
        tar -xzvf executor-linux-${LATEST_VERSION}.tar.gz
        rm -rf executor-linux-${LATEST_VERSION}.tar.gz

        # Определяем пользователя и домашнюю директорию
        USERNAME=$(whoami)
        HOME_DIR=$(eval echo ~$USERNAME)
        
        # Создаем .t3rn и записываем приватный ключ
        CONFIG_FILE="$HOME_DIR/executor/executor/bin/.t3rn"
        echo "ENVIRONMENT=testnet" > $CONFIG_FILE
        echo "EXECUTOR_PROCESS_PENDING_ORDERS_FROM_API=false" > $CONFIG_FILE
        echo "EXECUTOR_PROCESS_ORDERS_API_ENABLED=false" > $CONFIG_FILE
        echo "EXECUTOR_PROCESS_BIDS_BATCH=true" > $CONFIG_FILE
        echo "EXECUTOR_ENABLE_BATCH_BIDDING=true" > $CONFIG_FILE
        echo "LOG_LEVEL=debug" >> $CONFIG_FILE
        echo "LOG_PRETTY=false" >> $CONFIG_FILE
        echo "EXECUTOR_PROCESS_BIDS_ENABLED=true" >> $CONFIG_FILE
        echo "EXECUTOR_PROCESS_ORDERS=true" >> $CONFIG_FILE
        echo "EXECUTOR_PROCESS_CLAIMS=true" >> $CONFIG_FILE
        echo "PRIVATE_KEY_LOCAL=" >> $CONFIG_FILE
        echo "EXECUTOR_MAX_L3_GAS_PRICE=1500" >> $CONFIG_FILE
        echo "ENABLED_NETWORKS='arbitrum-sepolia,base-sepolia,optimism-sepolia,blast-sepolia,monad-testnet,unichain-sepolia,l2rn'" >> $CONFIG_FILE
        cat <<'EOF' >> $CONFIG_FILE
RPC_ENDPOINTS='{
    "l2rn": ["https://b2n.rpc.caldera.xyz/http"],
    "arbt": ["https://arbitrum-sepolia-rpc.publicnode.com/519c5dad643d9d21986e6674ff1a70235bcfa1ced74812a831a726f0455d1d35"],
    "bast": ["https://base-sepolia-rpc.publicnode.com/e8194b83db6651a678b64737e8caded855f6a9bd2c58d59ef5b5bc10266288ea"],
    "opst": ["https://optimism-sepolia-rpc.publicnode.com/cec381af6037b798c9dd546445aac0c6b88d0484408973b687056064d9446494"],
    "blst": ["https://blast-sepolia.g.alchemy.com/v2/KwGIIZbGFDZ-iLcEG_uQzAVD5qkTyPuq"],
    "mont": ["https://monad-testnet.g.alchemy.com/v2/KwGIIZbGFDZ-iLcEG_uQzAVD5qkTyPuq"],
    "unit": ["https://unichain-sepolia-rpc.publicnode.com/94dc1bb15b511ec6b54ca5863f6943a96ae4715c268a2e75dd2242f5c774b82c"]
}'
EOF

        if ! grep -q "ENVIRONMENT=testnet" "$HOME/executor/executor/bin/.t3rn"; then
          echo "ENVIRONMENT=testnet" >> "$HOME/executor/executor/bin/.t3rn"
        fi

        echo -e "${YELLOW}Введите ваш приватный ключ:${NC}"
        read PRIVATE_KEY
        sed -i "s|PRIVATE_KEY_LOCAL=|PRIVATE_KEY_LOCAL=$PRIVATE_KEY|" $CONFIG_FILE

        # Релоад деймонов
        sudo systemctl daemon-reload
        sudo systemctl restart systemd-journald
        sudo systemctl start t3rn
        sleep 2

        # Заключительный вывод
        echo -e "${PURPLE}-----------------------------------------------------------------------${NC}"
        echo -e "${YELLOW}Команда для проверки логов:${NC}"
        echo "sudo journalctl -u t3rn -f"
        echo -e "${PURPLE}-----------------------------------------------------------------------${NC}"
        echo -e "${GREEN}CRYPTO FORTOCHKA — вся крипта в одном месте!${NC}"
        echo -e "${CYAN}Наш Telegram https://t.me/cryptoforto${NC}"
        sleep 2

        # Проверка логов
        sudo journalctl -u t3rn -f
        ;;
    3)
        # Проверка логов
        sudo journalctl -u t3rn -f
        ;;
    4)
        # Рестарт ноды
        sudo systemctl restart t3rn
        sudo journalctl -u t3rn -f
        ;;
    5)
        echo -e "${BLUE}Удаление ноды t3rn...${NC}"

        # Остановка и удаление сервиса
        sudo systemctl stop t3rn
        sudo systemctl disable t3rn
        sudo rm /etc/systemd/system/t3rn.service
        sudo systemctl daemon-reload
        sleep 2

        # Удаление папки executor
        rm -rf $HOME/executor

        echo -e "${GREEN}Нода t3rn успешно удалена!${NC}"

        # Заключительный вывод
        echo -e "${PURPLE}-----------------------------------------------------------------------${NC}"
        echo -e "${GREEN}CRYPTO FORTOCHKA — вся крипта в одном месте!${NC}"
        echo -e "${CYAN}Наш Telegram https://t.me/cryptoforto${NC}"
        sleep 1
        ;;
    *)
        echo -e "${RED}Неверный выбор. Пожалуйста, введите номер от 1 до 4.${NC}"
        ;;
esac
