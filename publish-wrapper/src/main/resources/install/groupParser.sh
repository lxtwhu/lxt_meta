#!/usr/bin/sh

CUR_PATH=$(cd "$(dirname "$0")"&& pwd)
operType=$1
sequence_index=$2

####### parse  subModules config  ########
if [ -f ${CUR_PATH}/group.cfg ];then
	. ${CUR_PATH}/group.cfg
	if [ "${GROUP_NAME}" = "" ];then
		echo "    Cannot found   GROUP_NAME  in file [group.cfg] !"
		exit 255
	fi

	case "${operType}" in
	install)
		OPERATE_seqs=("${INSTALL_seqs[@]}")
		;;
	rollback)
		OPERATE_seqs=("${ROLLBACK_seqs[@]}")
		;;
  *)
    echo "Usage:  groupParser < install | rollback > < sequence_index >"
		exit 255
	esac

	if [ -z "$sequence_index" ]; then
	  sequence_index=0
  fi
  test "$sequence_index" -gt "-1" -a "$sequence_index" -lt "${#OPERATE_seqs[@]}" 1>/dev/null 2>&1
  passIf0 "$?" "groupParser.sh" "Usage:  groupParser < install | rollback > < sequence_index >\n  'sequence_index' should be an integer number lower than the size of < install | rollback > seqs. You chose ${operType} seqs, so the range is [0,${#OPERATE_seqs[@]}). Your illegal input is [$sequence_index]."

	OPERATE_seq=${OPERATE_seqs[$sequence_index]}
	MODULES_STR=${OPERATE_seq}

	test -n "${MODULES_STR}"
	passIf0 "$?" "groupParser.sh" "In $operType seqs, the seq of index $sequence_index is empty, thus there is nothing to $operType."

	MODULES_ARR=(${MODULES_STR})	
else
	echo "    Cannot found    group.cfg   in path [$CUR_PATH] !"
	exit 255
fi