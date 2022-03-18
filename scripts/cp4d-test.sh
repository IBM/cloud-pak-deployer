#! /bin/bash
SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )

if [ "${CONFIG_DIR}" == "" ]; then
  echo "Config directory must be specified using the CONFIG_DIR environment variable."
  exit 1
fi

if [ "${STATUS_DIR}" == "" ]; then
  echo "Status directory must be specified using the STATUS_DIR environment variable."
  exit 1
fi

starting_cartridge=$1

get_logtime() {
  echo $(date "+%Y-%m-%d %H:%M:%S")
}

log() {
  LOG_TIME=$(get_logtime)
  printf "CPD TEST: [${LOG_TIME}] ${1}\n"
}

config_file=$(find $CONFIG_DIR/config -name '*cp4d.yaml' | head -1)

cart_to_check=$(python $SCRIPT_DIR/list-cartridges.py get-cartridges $config_file)

log "List of cartridges: $cart_to_check"

for cpd_cart in $cart_to_check;do
  if [ "$starting_cartridge" != "" ] && [ "$cpd_cart" != "$starting_cartridge" ];then
    echo "Skipping cartridge $cpd_cart"
    continue
  elif [ "$cpd_cart" == "$starting_cartridge" ];then
    starting_cartridge=""
  fi
  log "START Cartrige $cpd_cart"
  python $SCRIPT_DIR/list-cartridges.py set-removed $config_file
  python $SCRIPT_DIR/list-cartridges.py set-installed $config_file $cpd_cart
  ./cp-deploy.sh env apply -v -e env_id=fke28d --skip-infra | tee $STATUS_DIR/log/cpd-test-$cpd_cart.log
  log "END Cartridge $CPD_cart"
  log "------------------------------------------------------------------------------------------------------------------------------"
done
