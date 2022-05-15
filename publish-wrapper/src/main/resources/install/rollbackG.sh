#!/usr/bin/sh

GROUP_INSTALLER_HOME=$(cd "$(dirname "$0")"&& pwd)
GROUP_PATCH_HOME=$(cd $GROUP_INSTALLER_HOME/..&& pwd)
. ${GROUP_INSTALLER_HOME}/utils.sh

#***************************************************************
#############################解析操作对象#######################
index=$1
. ${GROUP_INSTALLER_HOME}/groupParser.sh rollback "$index"
EnsureNotEmpty "GROUP_NAME" #$(basename "$GROUP_PATCH_HOME")

GROUP_CONTENT_HOME=${GROUP_PATCH_HOME}/${GROUP_NAME}
#**************************************************************
#*********使用说明*********************************************
Usage()
{
  echo 'Usage: rollbackG.sh < sequence_index (deafault:0) >'
}

## DEPRECATED
## unzip
unzipG(){
  local keep_origin=$1

  cd $GROUP_PATCH_HOME
  if [ ! -f ${GROUP_NAME}.tar.gz ];then
	  checkReturn "unzipG: Cannot found ${GROUP_NAME}.tar.gz in path[$GROUP_PATCH_HOME]" "1"
  fi
  echo "unzipG: unzipping ${GROUP_NAME}.tar.gz ..."
  tar -zxf ${GROUP_NAME}.tar.gz $MODULES_STR
  checkReturn "unzipG: Fail to unzip ${GROUP_NAME}.tar.gz in path[$GROUP_PATCH_HOME]" "$?"

  if [ ! "$keep_origin" = "1" ]; then
      rm ${GROUP_NAME}.tar.gz
      checkReturn "unzipG: Fail to remove ${GROUP_NAME}.tar.gz in path[$GROUP_PATCH_HOME]" "$?"
  fi

  echo " OK!"
}

cleanG(){
  return 0
}

#***************************************************************
#############################业务逻辑开始#######################

echo "###############################"
echo "####  Begin to rollback ... ####"
echo "###############################"
echo "  Group  : $GROUP_NAME"
echo "  Modules: $MODULES_STR"
echo "###############################"

#不再压缩
#unzipG "1"

EnsureDirExist "$GROUP_CONTENT_HOME"

for module in "${MODULES_ARR[@]}"; do
	echo ""
	echo ">>>>>>>>>>>>>"
	echo "     Rollback module [$module] ..."
	echo ">>>>>>>>>>>>>"
	#不再压缩
	#MODULE_DIR=$GROUP_PATCH_HOME/$module
	MODULE_DIR=$GROUP_CONTENT_HOME/$module
	bash --login --noprofile --norc $MODULE_DIR/install/installM.sh rollback # 考虑到 installM 中的插件可能会 source ~/.bash_profile ~/.profile文件，这里的 --login参数是必须的！【~/.bash_profile ~/.profile只应该在login态使用】
	checkReturn "rollbackG.sh: Fail when rollback module [$module] ..." "$?"
done

echo ""
echo "###############################"
echo "####  Succ to rollback ... ####"
echo "###############################"
echo "  Group  : $GROUP_NAME"
echo "  Modules: $MODULES_STR"
echo "###############################"


