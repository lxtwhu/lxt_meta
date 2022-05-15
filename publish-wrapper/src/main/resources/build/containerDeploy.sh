#!/usr/bin/sh

CUR_DIR=$(cd "$(dirname "$0")"&& pwd)

BUILD_DIR=$CUR_DIR
INITIATOR_DIR=$(cd "$CUR_DIR/.."&& pwd)
PATCH_DIR=$(cd "$INITIATOR_DIR/../patch"&& pwd)
ROOT_DIR=$(cd "$INITIATOR_DIR/../../../.."&& pwd)

. "$INITIATOR_DIR/common/utils.sh"

Usage()
{
  echo 'Usage:   这个脚本是给容器化编译调用的，用来把制品放到根目录（因为容器化编译只支持这么做）。平时开发、测试时，并不需要调用。'
  echo '以防万一，你可以在 .gitignore 里配置上 install 与 *.tar.gz 两行，以防将制品上传到代码库。'
}

Info "containerDeploy.sh" "Begin to moving artifacts to root directory ..."

#EnsureDirExist $PATCH_DIR/install
#cp -r $PATCH_DIR/install $ROOT_DIR
#passIf0 "$?" "containerDeploy.sh" "Fail to copy install dir: $PATCH_DIR/install"
#
#EnsureFileExist $PATCH_DIR/*.tar.gz
#cp $PATCH_DIR/*.tar.gz $ROOT_DIR
#passIf0 "$?" "containerDeploy.sh" "Fail to copy tar.gz file: $(ls $PATCH_DIR/*.tar.gz)"

EnsureDirExist $PATCH_DIR
cp -r $PATCH_DIR/* $ROOT_DIR
passIf0 "$?" "containerDeploy.sh" "Fail to copy file: $(ls $PATCH_DIR)"

Succ "containerDeploy.sh" "Moving Finished！"

