#!/usr/bin/sh

CUR_DIR=$(cd "$(dirname "$0")"&& pwd)

BUILD_DIR=$CUR_DIR
INITIATOR_DIR=$(cd "$CUR_DIR/.."&& pwd)
PATCH_DIR=$(cd "$INITIATOR_DIR/../patch"&& pwd)
ROOT_DIR=$(cd "$INITIATOR_DIR/../../../.."&& pwd)

. "$INITIATOR_DIR/common/utils.sh"
. "$ROOT_DIR/build/node.cfg"

Usage()
{
  echo 'Usage:   integration.sh -n<node_indexes> -s<seq_index> -v<version> -b<background_mode>'
  echo '         -n<node_indexes>     必选. 逗号分隔值的集合. 值为 @, 则表示在本机当前用户发布, 且发布到node.cfg中指定目录[LOCAL_FAKE_HOME(默认值为$HOME)]. 若为从0开始的整数, 则表示发布到的远程节点序号，即node.cfg文件中预先配置的数组[REMOTE_NODE_ADDRESSES]中的下标.'
  echo '         -s<seq_index>        安装序列的序号，以group.cfg文件中预先配置的数组[INSTALL_seqs]中的下标指代[从0开始]。若不指定，则默认值为0。'
  echo '         -v<version>          本次发布的版本号（不可重复）。不指定时，默认为当前时间戳.'
  echo '         -b<background_mode>  后台模式. 输出打印到文件.'
  echo 'Example: integration.sh -n 0  发布序列0到节点0'
  echo 'Example: integration.sh -n @  发布序列0到本机当前用户'
  echo 'Example: integration.sh -n 0,1 -s 1 -v BDXX-SND-1.0.0'
  echo '                              发布序列1到节点0与节点1,并指定版本号为BDXX-SND-1.0.0'
}
## 提取参数
while getopts :n:s:v:b: OPTION;do
  if [ ! "${OPTARG#-}" = "$OPTARG" ]; then
      OPTIND=$OPTIND-1
      continue
  fi
  case $OPTION in
    n)echo "choosing nodes $OPTARG"
      NODE_INDEXES_COMMA=$OPTARG
    ;;
    s)echo "choosing sequence $OPTARG"
      SEQ_INDEX=$OPTARG
    ;;
    v)echo "specifying version $OPTARG"
      VERSION=$OPTARG
    ;;
    b)echo "background mode $OPTARG"
      BACKGROUND_MODE=$OPTARG
    ;;
    ":") #missing opt value, skip
    ;;
    "?") #unsupported opt tag, skip
    ;;
  esac
done
## 提取参数

cd "$ROOT_DIR"

export TIMESTAMP=$(date "+%Y%m%d-%H%M%S")
EnsureNotEmptyOrCreate "VERSION" $TIMESTAMP

NODE_INDEXES=($(echo "$NODE_INDEXES_COMMA" | tr "," " "))

IntegrationNode(){
    local NODE_INDEX=$1

    echo ""
    Info "IntegrationNode[$NODE_INDEX]" ">>>>>>>> BEGIN NODE [$NODE_INDEX]"

    EnsureNotEmpty "NODE_INDEX"
    test "$NODE_INDEX" = "@" -o "$NODE_INDEX" -gt "-1" -a "$NODE_INDEX" -lt "${#REMOTE_NODE_ADDRESSES[@]}" 1>/dev/null 2>&1
    passIf0 "$?" "IntegrationNode[$NODE_INDEX]" "-n should be comma-separated identifiers like '@' or an integer number in range [0,${#REMOTE_NODE_ADDRESSES[@]}). You have an illegal input [$NODE_INDEX]."

    if [ "$NODE_INDEX" = "@" ]; then
        ## 本地模式
        EnsureNotEmptyOrCreate "LOCAL_FAKE_HOME" $HOME
        THIS_GROUP_DIR="$LOCAL_FAKE_HOME/install/$VERSION/$GROUP_NAME"

        Info "IntegrationNode[$NODE_INDEX]" "Installing ..."
        EnsureDirExistOrMake "$THIS_GROUP_DIR"
        cp -r "$PATCH_DIR"/* "$THIS_GROUP_DIR"
        passIf0 "$?" "IntegrationNode[$NODE_INDEX]" "Fail when copy products to node."

        sh "$THIS_GROUP_DIR/install/installG.sh" "$SEQ_INDEX"
        passIf0 "$?" "IntegrationNode[$NODE_INDEX]" "Fail during installation."
        Succ "IntegrationNode[$NODE_INDEX]" "Installing $(Green Success)! Go to fake home[$LOCAL_FAKE_HOME] and check!"
    else
        ## 远程模式
        REMOTE_NODE_ADDRESS=${REMOTE_NODE_ADDRESSES[$NODE_INDEX]}
        REMOTE_THIS_GROUP_DIR="~/install/$VERSION/$GROUP_NAME"

        Info "IntegrationNode[$NODE_INDEX]" "Making remote directory [$REMOTE_THIS_GROUP_DIR] for [$REMOTE_NODE_ADDRESS] ..."
        ssh ${REMOTE_NODE_ADDRESS} "mkdir -p $REMOTE_THIS_GROUP_DIR"
        passIf0 "$?" "integration.sh" "Failure: Remote directory creation aborted."
        Succ "IntegrationNode[$NODE_INDEX]" "Success: Remote directory created."

        Info "IntegrationNode[$NODE_INDEX]" "Sending package to remote directory[$REMOTE_NODE_ADDRESS:$REMOTE_THIS_GROUP_DIR] ..."
        scp -r "$PATCH_DIR"/* "$REMOTE_NODE_ADDRESS:$REMOTE_THIS_GROUP_DIR"
        passIf0 "$?" "IntegrationNode[$NODE_INDEX]" "Failure: Deployed to remote directory : $REMOTE_NODE_ADDRESS:$REMOTE_THIS_GROUP_DIR"
        Succ "IntegrationNode[$NODE_INDEX]" "Success: Deployed to remote directory : $REMOTE_NODE_ADDRESS:$REMOTE_THIS_GROUP_DIR"

        Info "IntegrationNode[$NODE_INDEX]" "Remote Installation Begins ... ..."
        ssh ${REMOTE_NODE_ADDRESS} "export TIMESTAMP=$TIMESTAMP && cd $REMOTE_THIS_GROUP_DIR/install && bash installG.sh" "$SEQ_INDEX"
        passIf0 "$?" "integration.sh" "Failure: ... ... Remote Installation Ends !!!"
        Succ "IntegrationNode[$NODE_INDEX]" "$(Green Success): Remote Installation Ends !!! Go to [$REMOTE_NODE_ADDRESS:$REMOTE_THIS_GROUP_DIR] and check!"
    fi

    Succ "IntegrationNode[$NODE_INDEX]" "<<<<<<<< FINISH NODE [$NODE_INDEX]"
    echo ""
}

for index in "${NODE_INDEXES[@]}" ; do
    if [[ "$BACKGROUND_MODE" = "1" ]]; then
        IntegrationNode "$index" 1>${BUILD_DIR}/integration-ver-${VERSION}-node-${index}.log 2>&1 &
        pid[$index]=$!
        Info "integration.sh" "Node $index installing in background : pId [${pid[$index]}] log [${BUILD_DIR}/integration-ver-${VERSION}-node-${index}.log]"
    else
        IntegrationNode "$index"
    fi
done

if [[ "$BACKGROUND_MODE" = "1" ]]; then
    Info "integration.sh" "Waiting for nodes[${NODE_INDEXES[@]}] to finish ..."
    FAIL=0
    for index in "${NODE_INDEXES[@]}" ; do
        wait ${pid[$index]}
        if [[ $? -eq 0 ]]; then
            Succ "integration.sh" "Node $index Finished : log [${BUILD_DIR}/integration-ver-${VERSION}-node-${index}.log]"
        else
            Error "integration.sh" "Node $index Failed : log [${BUILD_DIR}/integration-ver-${VERSION}-node-${index}.log]"
            let "FAIL+=1"
        fi
    done

    Info "integration.sh" "Total: ${#NODE_INDEXES[@]} Pass: $((${#NODE_INDEXES[@]}-$FAIL)) Fail: ${FAIL}"
    test ${FAIL} -eq 0
    passIf0 "$?" "integration.sh" "Failure: ... ... Some Nodes Failed !!! Plz check the logs."
fi

Succ "integration.sh" "END: nodes[$NODE_INDEXES_COMMA] seq[$SEQ_INDEX] version[$VERSION] background mode[$BACKGROUND_MODE]"









####



