cpd_cli_destination=$1
cpd_project=$2
cpd_service=$3

if [ ! -f ${cpd_cli_destination}/cpd-cli ];then
  echo "cpd-cli command not found in directory ${cpd_cli_destination}, exiting"
  exit 1
fi

pushd ${cpd_cli_destination} > /dev/null

${cpd_cli_destination}/cpd-cli status -n $cpd_project -a $cpd_service  > /dev/null
if [ $? == 0 ];then
  status='present'
else
  status='absent'
fi

popd  > /dev/null

printf "$status"