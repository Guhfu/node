download_node() {
  if [ -d "$HOME/executor" ] || screen -list | grep -q "\.t3rnnode"; then
    echo 'Папка executor или сессия t3rnnode уже существуют. Установка невозможна. Выберите удалить ноду или выйти из скрипта.'
    return
  fi

  echo 'Начинаю установку ноды...'

  read -p "Введите ваш приватный ключ: " PRIVATE_KEY_LOCAL

  sudo apt update -y && sudo apt upgrade -y
  sudo apt-get install make screen build-essential software-properties-common curl git nano jq -y

  cd $HOME

  sudo wget https://github.com/t3rn/executor-release/releases/download/v0.29.0/executor-linux-v0.29.0.tar.gz -O executor-linux.tar.gz
  sudo tar -xzvf executor-linux.tar.gz
  sudo rm -rf executor-linux.tar.gz
  cd executor

  export NODE_ENV="testnet"
  export LOG_LEVEL="debug"
  export LOG_PRETTY="false"
  export EXECUTOR_PROCESS_ORDERS="true"
  export EXECUTOR_PROCESS_CLAIMS="true"
  export PRIVATE_KEY_LOCAL="$PRIVATE_KEY_LOCAL"
  export ENABLED_NETWORKS="arbitrum-sepolia,base-sepolia,blast-sepolia,optimism-sepolia,l1rn"
  export RPC_ENDPOINTS_BSSP="https://base-sepolia.g.alchemy.com/v2/KwGIIZbGFDZ-iLcEG_uQzAVD5qkTyPuq"
  export RPC_ENDPOINTS_BLSS="https://blast-sepolia.g.alchemy.com/v2/KwGIIZbGFDZ-iLcEG_uQzAVD5qkTyPuq"
  export RPC_ENDPOINTS_OPSP="https://opt-sepolia.g.alchemy.com/v2/KwGIIZbGFDZ-iLcEG_uQzAVD5qkTyPuq"
  export RPC_ENDPOINTS_ARBT="https://arb-sepolia.g.alchemy.com/v2/KwGIIZbGFDZ-iLcEG_uQzAVD5qkTyPuq"
  export RPC_ENDPOINTS_L1RN='https://brn.rpc.caldera.xyz/'
  export EXECUTOR_MAX_L3_GAS_PRICE=150
  export EXECUTOR_PROCESS_PENDING_ORDERS_FROM_API="false"

  cd $HOME/executor/executor/bin/

  screen -dmS t3rnnode bash -c '
    echo "Начало выполнения скрипта в screen-сессии"

    cd $HOME/executor/executor/bin/
    ./executor

    exec bash
  '

  echo "Screen сессия 't3rnnode' создана и нода запущена..."
}

check_logs() {
  if screen -list | grep -q "\.t3rnnode"; then
    screen -S t3rnnode -X hardcopy /tmp/screen_log.txt && sleep 0.1 && tail -n 100 /tmp/screen_log.txt && rm /tmp/screen_log.txt
  else
    echo "Сессия t3rnnode не найдена."
  fi
}

change_fee() {
    echo 'Начинаю изменение комиссии...'

    if [ ! -d "$HOME/executor" ]; then
        echo 'Папка executor не найдена. Установите ноду.'
        return
    fi

    read -p 'На какой газ GWEI вы хотите изменить? (по стандарту 30) ' GWEI_SET
    
    cd $HOME/executor
    export EXECUTOR_MAX_L3_GAS_PRICE=$GWEI_SET

    echo 'Перезагружаю ноду...'

    restart_node

    echo 'Комиссия была изменена.'
}

stop_node() {
  echo 'Начинаю остановку...'

  if screen -list | grep -q "\.t3rnnode"; then
    screen -S t3rnnode -p 0 -X stuff "^C"
    echo "Нода была остановлена."
  else
    echo "Сессия t3rnnode не найдена."
  fi
}

restart_node() {
  echo 'Начинаю перезагрузку...'

  session="t3rnnode"
  
  if screen -list | grep -q "\.${session}"; then
    screen -S "${session}" -p 0 -X stuff "^C"
    sleep 1
    screen -S "${session}" -p 0 -X stuff "./executor\n"
    echo "Нода была перезагружена."
  else
    echo "Сессия ${session} не найдена."
  fi
}

delete_node() {
  echo 'Начинаю удаление ноды...'

  if [ -d "$HOME/executor" ]; then
    sudo rm -rf $HOME/executor
    echo "Папка executor была удалена."
  else
    echo "Папка executor не найдена."
  fi

  if screen -list | grep -q "\.t3rnnode"; then
    sudo screen -X -S t3rnnode quit
    echo "Сессия t3rnnode была закрыта."
  else
    echo "Сессия t3rnnode не найдена."
  fi

  echo "Нода была удалена."
}

exit_from_script() {
  exit 0
}

while true; do
    channel_logo
    sleep 2
    echo -e "\n\nМеню:"
    echo "1. 🚀 Установить ноду"
    echo "2. 📋 Проверить логи ноды"
    echo "3. 🐾 Изменить комиссию"
    echo "4. 🛑 Остановить ноду"
    echo "5. 🔄 Перезапустить ноду"
    echo "6. 🗑️ Удалить ноду"
    echo -e "7. 🚪 Выйти из скрипта\n"
    read -p "Выберите пункт меню: " choice

    case $choice in
      1)
        download_node
        ;;
      2)
        check_logs
        ;;
      3)
        change_fee
        ;;
      4)
        stop_node
        ;;
      5)
        restart_node
        ;;
      6)
        delete_node
        ;;
      7)
        exit_from_script
        ;;
      *)
        echo "Неверный пункт. Пожалуйста, выберите правильную цифру в меню."
        ;;
    esac
  done