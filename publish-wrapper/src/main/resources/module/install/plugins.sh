#!/usr/bin/sh
## common
EnsureJavaBin(){
  if [ "$JAVA_BIN" = "" ]; then
      if [ "$JAVA_HOME" = "" ]; then
          which java 1>/dev/null 2>&1
          passIf0 "$?" "EnsureJavaBin" "\$JAVA_BIN and \$JAVA_HOME both have not been set. Also, we cannot find 'java' in \$PATH."
          JAVA_BIN=$(dirname "$(which java)")
      else
          JAVA_BIN=$JAVA_HOME/bin
      fi
  fi
  export JAVA_BIN
  Info "EnsureJavaBin" "JAVA_BIN=$(yellow "$JAVA_BIN")"
}

EnsureJava(){
  EnsureJavaBin
  Info "EnsureJava" "If your JAVA_BIN or JAVA_HOME hasn't been set wrong, your java path is [$JAVA_BIN/java]."
  EnsureFileExist "$JAVA_BIN/java"

  "${JAVA_BIN}/java" -version
  passIf0 "$?" "EnsureJava" "'$JAVA_BIN/java -version' run failed."
}

EnsureJava8(){
  EnsureJava
  JAVA_VERSION=`$JAVA_BIN/java -version  2>&1 |awk 'NR==1{ gsub(/"/,""); print $3 }'`
  JAVA_VER_REQ='1.8' # java版本号需大于此值
  test $(echo ${JAVA_VERSION} ${JAVA_VER_REQ} | awk '$1>$2 {print 1} $1==$2 {print 0} $1<$2 {print -1}') -ge 0
  passIf0 "$?" "EnsureJava8" "Required Java Version is ${JAVA_VER_REQ} or later, while your Java Version is ${JAVA_VERSION}!!! "
}

EnsureEnvType(){
  local ENV_TYPES=("LOCAL" "DT" "KT" "UT" "PT" "PM" "BD" "PD" "DEV" "PRD" "BDT" "BKT" "BUT" "BPT" "LN" "DT_S" "KT_S" "UT_S" "PT_S" "PD_S" "DT_A" "KT_A" "UT_A" "PT_A" "PD_A")
  passIf0 "$(Contain "${ENV_TYPES[*]}" "$ENV_TYPE")" "EnsureEnvType" "[\$ENV_TYPE=$ENV_TYPE]. It should be in (${ENV_TYPES[@]})."
  Info "EnsureEnvType" "ENV_TYPE=$(yellow "$ENV_TYPE")"
}

## initialize
SourceUserProfile(){
  local fail_on_missing=$1 #值为1，则文件不存在时退出
  if [ -f $HOME/.profile -a -z "$profile_runned" ];then
    Info "SourceUserProfile" "source \$HOME/.profile"
    source $HOME/.profile
    profile_runned=1
  elif [ -n "$profile_runned" ]; then
    Info "SourceUserProfile" "Skip! Already runned earlier!"
  elif [ "$fail_on_missing" = "1" ]; then
    passIf0 "255" "SourceUserProfile" "Missing File [$HOME/.profile]."
  else
    Warn "SourceUserProfile" "Skip! Missing File [$HOME/.profile]. Ignore this if you don't need it. Unbind this plugin to turn this warning off."
  fi
}

# ~/.bashrc文件 主要用于交互式bash shell的配置，一般情况下，不应把变量放在这里
SourceUserBashrc(){
  local fail_on_missing=$1 #值为1，则文件不存在时退出
  if [ -f $HOME/.bashrc -a -z "$bashrc_runned" ];then
    Info "SourceUserBashrc" "source \$HOME/.bashrc"
    source $HOME/.bashrc
    bashrc_runned=1
  elif [ -n "$bashrc_runned" ]; then
    Info "SourceUserBashrc" "Skip! Already runned earlier!"
  elif [ "$fail_on_missing" = "1" ]; then
    passIf0 "255" "SourceUserBashrc" "Missing File [$HOME/.bashrc]."
  else
    Warn "SourceUserBashrc" "Skip! Missing File [$HOME/.bashrc]. Ignore this if you don't need it. Unbind this plugin to turn this warning off."
  fi
}

SourceUserBashProfile(){
  local fail_on_missing=$1 #值为1，则文件不存在时退出
  if [ -f $HOME/.bash_profile -a -z "$bash_profile_runned" ];then
    Info "SourceUserBashProfile" "source \$HOME/.bash_profile"
    source $HOME/.bash_profile
    bash_profile_runned=1
  elif [ -n "$bash_profile_runned" ]; then
    Info "SourceUserBashProfile" "Skip! Already runned earlier!"
  elif [ "$fail_on_missing" = "1" ]; then
    passIf0 "255" "SourceUserBashProfile" "Missing File [$HOME/.bash_profile]."
  else
    Warn "SourceUserBashProfile" "Skip! Missing File [$HOME/.bash_profile]. Ignore this if you don't need it. Unbind this plugin to turn this warning off."
  fi
}

SourceUserEnvDefault(){
  local ENV_TYPE_TMP=$ENV_TYPE
  unset ENV_TYPE
  SourceUserBashProfile
  if [ -z "$ENV_TYPE" ]; then #防止重复引入 ~/.profile 其中引入的 /etc/profile文件在很多系统不支持重复引入
    SourceUserProfile
    if [ -z "$ENV_TYPE" ]; then
        export ENV_TYPE=$ENV_TYPE_TMP
        Warn "SourceUserEnvDefault" "No \$ENV_TYPE has been set in ~/.bash_profile or ~/.profile!"
    fi
  fi
}

InitializeCheck(){ #用于检查必须的变量，并提供默认值。用户可在InitializeCustom中定义自己特殊的值
  Info "InitializeCheck" "Initialize/Ensure some variables:"
  EnsureNotEmptyOrCreate "DEFINED_USER_HOME" "$HOME"
  EnsureNotEmptyOrCreate "MODULE_INSTALLER_HOME" "$(cd "$(dirname "$0")" && pwd)"
  EnsureNotEmptyOrCreate "MODULE_PATCH_HOME" "$(cd $MODULE_INSTALLER_HOME/.. && pwd)"
  EnsureNotEmptyOrCreate "MODULE_NAME" "$(basename "$MODULE_PATCH_HOME")"
  export MODULE_NAME
  EnsureNotEmptyOrCreate "MODULE_CONTENT_HOME" "$MODULE_PATCH_HOME/$MODULE_NAME" #静态，该目录下内容不动，以保证重复安装的正确性
  EnsureNotEmptyOrCreate "MODULE_CONTENT_WORK_HOME" "$MODULE_PATCH_HOME/$MODULE_NAME-working" #工作区，进行处理
  UninstallCore "$MODULE_CONTENT_WORK_HOME" 1
  trap 'test "$?" -eq 0 && test "$NO_CLEAN_ON_EXIT" != "true" && UninstallCore "$MODULE_CONTENT_WORK_HOME" 1' EXIT
  InstallCore "$MODULE_CONTENT_HOME" "$MODULE_CONTENT_WORK_HOME"

  EnsureNotEmptyOrCreate "DEPLOY_HOME" "$DEFINED_USER_HOME/apps"
  EnsureNotEmptyOrCreate "MODULE_DEPLOY_HOME" "$DEPLOY_HOME/$MODULE_NAME"
  export MODULE_DEPLOY_HOME
  EnsureNotEmptyOrCreate "BACKUP_HOME" "$DEFINED_USER_HOME/backup"
  EnsureNotEmptyOrCreate "MODULE_BACKUP_HOME" "$BACKUP_HOME/$MODULE_NAME"
  EnsureNotEmptyOrCreate "TIMESTAMP" "$(date "+%Y%m%d-%H%M%S")"
}

InitializeLxkAppCheck(){ #用于安装lxk-app
  Info "InitializeLxkAppCheck" "Initialize some LXK APP variables."
  EnsureNotEmptyOrCreate "DEFINED_USER_HOME" "$HOME"

  EnsureNotEmptyOrCreate "BS_HOME" "$DEFINED_USER_HOME/bss_home"
  export BS_HOME
  DEPLOY_HOME=$BS_HOME

  EnsureNotEmpty "NFS_BS_HOME"
  InitializeCheck
}

InitializeNoSetupCheck(){ #用于安装no-setup
  Info "InitializeNoSetupCheck" "Turn on: NO_CLEAN_ON_EXIT"
  EnsureNotEmptyOrCreate "NO_CLEAN_ON_EXIT" "true"
  InitializeCheck
}

InitializeUpjasStandaloneCheck(){ # 默认使用 upjas 3.0.0
  Info "InitializeUpjasStandaloneCheck" "Initialize some UPJAS variables."
  EnsureNotEmptyOrCreate "DEFINED_USER_HOME" "$HOME"

  EnsureNotEmptyOrCreate "UPJAS_HOME" "$DEFINED_USER_HOME/upjas-3.0.0.Final"
  export UPJAS_HOME
  UPJAS_BIN_HOME="$UPJAS_HOME/bin"
  EnsureFileExist "$UPJAS_BIN_HOME/upjas_config.sh"
  EnsureFileExist "$UPJAS_BIN_HOME/upjas_setEnv.properties"
  EnsureFileExist "$UPJAS_BIN_HOME/upjas.sh"

  UPJAS_CONF_HOME="$UPJAS_HOME/upjas-conf"
  EnsureDirExist "$UPJAS_CONF_HOME"

  UPJAS_STANDALONE_HOME="$UPJAS_HOME/standalone"
  UPJAS_STANDALONE_DEPLOY_HOME="$UPJAS_STANDALONE_HOME/deployments"
  EnsureDirExist "$UPJAS_STANDALONE_DEPLOY_HOME"
  UPJAS_STANDALONE_LOG_HOME="$UPJAS_STANDALONE_HOME/log"
  UPJAS_STANDALONE_SERVER_LOG="$UPJAS_STANDALONE_LOG_HOME/server.log"


  DEPLOY_HOME=$UPJAS_STANDALONE_HOME # 慎用 在upjas中无意义
  MODULE_DEPLOY_HOME=$UPJAS_STANDALONE_DEPLOY_HOME #慎用 在upjas中无意义
  InitializeCheck
}

InitializeACDockerCheck(){ #用于安装ACDocker前检查
  Info "InitializeACDockerCheck" "Initialize some AC variables."
  EnsureNotEmptyOrCreate "DEFINED_USER_HOME" "$HOME"
  EnsureNotEmpty "JAVA_HOME"
  EnsureNotEmptyOrCreate "AC_HOME" "$DEFINED_USER_HOME/activity_container"
  export AC_HOME
  AC_BIN_HOME="$AC_HOME/bin" # stop start required
  EnsureFileExist "$AC_BIN_HOME/ac.env" # ACContainer must have been installed correctly
  source "$AC_BIN_HOME/ac.env"
  EnsureFileExist "$AC_BIN_HOME/console.sh"
  EnsureFileExist "$AC_BIN_HOME/stop.sh"
  EnsureFileExist "$AC_BIN_HOME/start.sh"

  EnsureNotEmpty "DK_HOME"
  DEPLOY_HOME="$DK_HOME"
  InitializeCheck
}

InitializeACContainerCheck(){ #用于安装ACContainer前检查
  Info "InitializeACContainerCheck" "Initialize some AC variables."
  EnsureNotEmptyOrCreate "DEFINED_USER_HOME" "$HOME"
  EnsureNotEmpty "JAVA_HOME"
  EnsureNotEmptyOrCreate "AC_HOME" "$DEFINED_USER_HOME/activity_container"
  export AC_HOME
  AC_BIN_HOME="$AC_HOME/bin" # stop start required
  DEPLOY_HOME="$(dirname "$AC_HOME")"
  InitializeCheck
}

InitializeACPluginCheck(){ #用于安装ACPlugin前检查
  Info "InitializeACPluginCheck" "Initialize some AC variables."
  EnsureNotEmptyOrCreate "DEFINED_USER_HOME" "$HOME"
  EnsureNotEmpty "JAVA_HOME"
  EnsureNotEmptyOrCreate "AC_HOME" "$DEFINED_USER_HOME/activity_container"
  export AC_HOME
  AC_BIN_HOME="$AC_HOME/bin" # stop start required
  EnsureFileExist "$AC_BIN_HOME/ac.env" # ACContainer must have been installed correctly
  FORBID_PLUGIN_ENV=1
  source "$AC_BIN_HOME/ac.env"
  unset FORBID_PLUGIN_ENV
  EnsureFileExist "$AC_BIN_HOME/console.sh"

  EnsureNotEmpty "DK_HOME"
  DEPLOY_HOME="$DK_HOME"
  InitializeCheck
}

## unzip
UnzipCore(){
  local ZIP_PATH=$1
  local ZIP_FILE_NAME=$2
  local UNZIP_TARGET_DIR=$3
  local keep_origin=$4
  if [ -z "$UNZIP_TARGET_DIR" ]; then
      UNZIP_TARGET_DIR=$ZIP_PATH
  fi

  EnsureDirExistOrMake "$UNZIP_TARGET_DIR"
  test -f "$ZIP_PATH/${ZIP_FILE_NAME}.tar.gz"
  passIf0 "$?" "UnzipCore" "Cannot found [$ZIP_PATH/${ZIP_FILE_NAME}.tar.gz] in path[$ZIP_PATH]."

  Info "UnzipCore" "Unzipping $ZIP_PATH/${ZIP_FILE_NAME}.tar.gz into $UNZIP_TARGET_DIR ..."
  tar --directory="$UNZIP_TARGET_DIR" -zxf "$ZIP_PATH/${ZIP_FILE_NAME}.tar.gz"
  passIf0 "$?" "UnzipCore" "Fail to unzip $ZIP_PATH/${ZIP_FILE_NAME}.tar.gz into $UNZIP_TARGET_DIR."

  if [ ! "$keep_origin" = "1" ]; then
      rm "$ZIP_PATH/${ZIP_FILE_NAME}.tar.gz"
      passIf0 "$?" "UnzipCore" "Fail to remove ${ZIP_FILE_NAME}.tar.gz in path[$ZIP_PATH]."
  fi
  Succ "UnzipCore" "OK!"
}

UnzipDefault(){
#  EnsureNotEmpty "MODULE_PATCH_HOME"
#  EnsureNotEmpty "MODULE_NAME"
#  UnzipCore "$MODULE_PATCH_HOME" "$MODULE_NAME"

   Warn "UnzipDefault" "Deprecated since publish-wrapper 1.0.6 (skeleton 2.1.6) !!! It doesn't do anything since then because there's no need. Remove it from your lifecycle.cfg of this module."
}

RollbackUnzipDefault(){
  EnsureNotEmpty "MODULE_BACKUP_HOME"
  EnsureNotEmptyOrCreate "ROLLBACK_TIMESTAMP" "$(cd "$MODULE_DEPLOY_HOME"; basename $(\ls *.timestamp) .timestamp)"
  UnzipCore "$MODULE_BACKUP_HOME" "backup$ROLLBACK_TIMESTAMP" "$MODULE_BACKUP_HOME/$ROLLBACK_TIMESTAMP" "1"
}

## localize
SelectCore(){
  #各路径参数应传入绝对路径，或相对于$MODULE_CONTENT_WORK_HOME的相对路径
  local srcPath=$1 #源目录
  local relPath=$2 #目标目录
  local keep_origin=$3 # 不删除原资源
  if [ "$relPath" = "" ]; then
      relPath=$srcPath
  fi

  cd $MODULE_CONTENT_WORK_HOME
  echo ""
  EnsureEnvType
	if [ -r "${srcPath}/${ENV_TYPE}" ];then
	  if [ -z "$(ls -A ${srcPath}/${ENV_TYPE})" ]; then
	    Warn "SelectCore" "Skip! Directory [${srcPath}/${ENV_TYPE}] is empty. Nothing to select from. Ignore this if you don't use it."
	  else
	    if [ ! -d "$relPath" ]; then
        mkdir -p "$relPath"
        passIf0 "$?" "SelectCore" "Fail to mkdir [relPath=$relPath]."
      fi
      Info "SelectCore" "srcPath=$(yellow "$srcPath"), relPath=$(yellow "$relPath")"
      cp -r ${srcPath}/${ENV_TYPE}/* ${relPath}/
      passIf0 "$?" "SelectCore" "Fail to copy."
      Succ "SelectCore" "OK!"
	  fi
	else
	  Warn "SelectCore" "Skip! Directory [${srcPath}/${ENV_TYPE}] doesn't exist. Nothing to select from. Ignore this if you don't use it."
	fi

	if [ ! "$keep_origin" = "1" ]; then
      local ENV_TYPES=("LOCAL" "DT" "KT" "UT" "PT" "PM" "BD" "PD" "DEV" "PRD" "BDT" "BKT" "BUT" "BPT" "LN" "DT_S" "KT_S" "UT_S" "PT_S" "PD_S" "DT_A" "KT_A" "UT_A" "PT_A" "PD_A")
  	  Info "SelectCore" "Removing Selection Source in directory [$srcPath] including [${ENV_TYPES[@]}] ..."
	  for type in "${ENV_TYPES[@]}";do
	    rm -rf "$srcPath/$type"
	  done
	fi
}

SelectDefault(){
  cd $MODULE_CONTENT_WORK_HOME
  SelectCore "$MODULE_CONTENT_WORK_HOME/conf"
  SelectCore "$MODULE_CONTENT_WORK_HOME/bin/env"
}

SelectDefaultDirty(){
  cd $MODULE_CONTENT_WORK_HOME
  SelectCore "$MODULE_CONTENT_WORK_HOME/conf" "$MODULE_CONTENT_WORK_HOME/conf" "1"
  SelectCore "$MODULE_CONTENT_WORK_HOME/bin/env" "$MODULE_CONTENT_WORK_HOME/bin/env" "1"
}

SelectUpjasConf(){
  cd $MODULE_CONTENT_WORK_HOME
  SelectCore "$MODULE_CONTENT_WORK_HOME/upjas-conf"
}

InterpolateCore(){
  #各路径参数应传入绝对路径，或相对于$MODULE_CONTENT_WORK_HOME的相对路径
  local tmpPath=$1   #模板所在目录
	local relPath=$2   #生成文件所在目录
	local resPath=$3   #资源文件所在目录
	local keep_origin=$4 #保留模板目录、资源目录
	local resFile=""

  cd $MODULE_CONTENT_WORK_HOME
  echo ""
	if [ ! -r "${tmpPath}" ];then
	  Warn "InterpolateCore" "Skip! No Template Directory[$tmpPath]. Ignore this if you don't use it."
	else
	  EnsureEnvType
		if [ -f "${resPath}/res.${ENV_TYPE}" ];then
			resFile=${resPath}/res.${ENV_TYPE}
		else
		  Warn "InterpolateCore" "Cannot find resource[${resPath}/res.${ENV_TYPE}]. Only use properties from Environment. Ignore this if you don't use properties from resource files."
		fi

    EnsureJava8
    Info "InterpolateCore" "tmpPath=$(yellow "$tmpPath"), relPath=$(yellow "$relPath"), resPath=$(yellow "$resPath")"
    for file in "${tmpPath}"/*
    do
        if test -f $file
        then
            fn=${file##*/}
            Info "InterpolateCore" "Interpolate file[$fn] ..."
            "${JAVA_BIN}/java" -cp "$MODULE_INSTALLER_HOME" Replace "$file" "$relPath/$fn" "$resFile"
            passIf0 "$?" "InterpolateCore" "Fail to Interpolate file[$fn]."
        fi
    done
    Succ "InterpolateCore" "OK!"
	fi

	if [ ! "$keep_origin" = "1" ]; then
	    Info "InterpolateCore" "Removing Interpolation Source : template[$tmpPath] and resource[$resPath] ..."
	    rm -rf "$tmpPath"
	    rm -rf "$resPath"
	fi
}

InterpolateDefault(){
  cd "$MODULE_CONTENT_WORK_HOME"
  InterpolateCore "$MODULE_CONTENT_WORK_HOME/conf/template" "$MODULE_CONTENT_WORK_HOME/conf" "$MODULE_CONTENT_WORK_HOME/conf/resource"
}

InterpolateDefaultDirty(){
  cd "$MODULE_CONTENT_WORK_HOME"
  InterpolateCore "$MODULE_CONTENT_WORK_HOME/conf/template" "$MODULE_CONTENT_WORK_HOME/conf" "$MODULE_CONTENT_WORK_HOME/conf/resource" "1"
}

InterpolateUpjasConf(){
  cd "$MODULE_CONTENT_WORK_HOME"
  InterpolateCore "$MODULE_CONTENT_WORK_HOME/upjas-conf/template" "$MODULE_CONTENT_WORK_HOME/upjas-conf" "$MODULE_CONTENT_WORK_HOME/upjas-conf/resource"
}

InterpolateAC(){
  cd "$MODULE_CONTENT_WORK_HOME"
  Info "InterpolateAC" "Sourcing new ac.env for interpolation ..."
  EnsureFileExist "$MODULE_CONTENT_WORK_HOME/bin/ac.env"
  source "$MODULE_CONTENT_WORK_HOME/bin/ac.env"
  InterpolateDefault
}

## stop
StopUpjas(){
  Info "StopUpjas" "Stopping Upjas[$UPJAS_HOME] to hold standalone module[$(yellow "$MODULE_NAME")] ..."
  EnsureFileExist "$UPJAS_BIN_HOME/upjas.sh"

  cd "$UPJAS_BIN_HOME"
  sh upjas.sh stop
  passIf0 "$?" "StopUpjas" "Fail to stop."
  Succ "StopUpjas" "Upjas[$UPJAS_HOME] is successfully stopped."
}

StopACDockersInSpecifiedModule(){
  local module_name=$1 #指定的module序列
  Info "StopACDockersInSpecifiedModule" "Stopping ACDockers in module[$(yellow "$module_name")] ..."
  EnsureFileExist "$AC_BIN_HOME/stop.sh"

  if [ -d "$DK_HOME/$module_name" ]; then ## 以后需优化 stop.sh 使得免于此判断
      sh "$AC_BIN_HOME"/stop.sh -m"$module_name"
      passIf0 "$?" "StopACDockersInSpecifiedModule" "Fail to stop."
      Succ "StopACDockersInSpecifiedModule" "ACDockers in module[$(yellow "$module_name")] are successfully stopped."
  else
      Warn "StopACDockersInSpecifiedModule" "Skip! Due to missing directory[$DK_HOME/$module_name]. Ignore this if this is the first-time installation or module[$(yellow "$module_name")] has been stopped and removed manually."
  fi
}

StopAllDynamicACDockers(){
  Info "StopAllDynamicACDockers" "Stopping all dynamic ACDockers ..."
  StopACDockersInSpecifiedModule "dynamic"
}

StopACDockersInThisModule(){
  Info "StopACDockersInThisModule" "Stopping ACDockers in module[$(yellow "$MODULE_NAME")] ..."
  EnsureFileExist "$AC_BIN_HOME/stop.sh"

  if [ -d "$MODULE_DEPLOY_HOME" ]; then ## 以后需优化 stop.sh 使得免于此判断
      sh "$AC_BIN_HOME"/stop.sh -m"$MODULE_NAME"
      passIf0 "$?" "StopACDockersInThisModule" "Fail to stop."
      Succ "StopACDockersInThisModule" "ACDockers in module[$(yellow "$MODULE_NAME")] are successfully stopped."
  else
      Warn "StopACDockersInThisModule" "Skip! Due to missing directory[$MODULE_DEPLOY_HOME]. Ignore this if this is the first-time installation or module[$(yellow "$MODULE_NAME")] has been stopped and removed manually."
  fi
}

StopSpecifiedACDockers(){
  local dockers=$1 #指定的dockers序列，逗号分隔
  Info "StopSpecifiedACDockers" "Stopping Specified ACDockers [$(yellow "$dockers")] ..."
  EnsureFileExist "$AC_BIN_HOME/stop.sh"

  if [ -d "$MODULE_DEPLOY_HOME" ]; then ## 以后需优化 stop.sh 使得免于此判断
      sh "$AC_BIN_HOME"/stop.sh -d"$dockers"
      passIf0 "$?" "StopSpecifiedACDockers" "Fail to stop."
      Succ "StopSpecifiedACDockers" "Specified ACDockers [$(yellow "$dockers")] are successfully stopped."
  else
      Warn "StopSpecifiedACDockers" "Skip! Due to missing directory[$MODULE_DEPLOY_HOME]. Ignore this if this is the first-time installation or module[$(yellow "$MODULE_NAME")] has been stopped and removed manually."
  fi
}

StopACSwarm(){
  Info "StopACSwarm" "Stopping ACSwarm ..."
  if [ -f "$AC_BIN_HOME/console.sh" ]; then
    sh "$AC_BIN_HOME/console.sh" -b"d->q"
    passIf0 "$?" "StopACSwarm" "Fail to stop ACSwarm."
    Succ "StopACSwarm" "ACSwarm is successfully stopped."
  else
    Warn "StopACSwarm" "Skip! Due to missing file[$AC_BIN_HOME/console.sh]. Ignore this if this is the first-time installation or ACSwarm has been stopped and removed manually."
  fi
}

StopACSwarmAndDockers(){
  Info "StopACSwarmAndDockers" "Stopping ACSwarm and all ACDockers ..."
  if [ -f "$AC_BIN_HOME/stop.sh" ]; then
    sh "$AC_BIN_HOME/stop.sh"
    passIf0 "$?" "StopACSwarmAndDockers" "Fail to stop ACSwarm and Dockers."
    Succ "StopACSwarmAndDockers" "ACSwarm and all ACDockers are successfully stopped."
  else
    Warn "StopACSwarmAndDockers" "Skip! Due to missing file[$AC_BIN_HOME/stop.sh]. Ignore this if this is the first-time installation or ACSwarm has been stopped and removed manually."
  fi
}

## backup
BackupCore(){
  local installDir=$1 #源目录
  local backupDir=$2 #目标目录
  local today=$3 #备份入的时间戳

  if [ -z "$today" ]; then
      today=$TIMESTAMP
  fi

  EnsureDirExistOrMake "$backupDir"
  cd "$backupDir"

  Info "BackupCore" "src=$(yellow "$installDir"), target=$(yellow "$backupDir/backup$today.tar.gz")"
  if [ -r $installDir ];then
    if [ -f "$backupDir/backup$today.tar.gz" ]; then
        printf "> An archive already exists, contents will be appended to it. Preparing ... " %s
        gunzip -f "$backupDir/backup$today.tar.gz"
        passIf0 "$?" "BackupCore" "Fail to gunzip[$backupDir/backup${today}.tar.gz]."
    fi

    local installDirHome=$(cd "$installDir"/.. && pwd)
    local installDirName=$(basename $(cd "$installDir" && pwd))

    printf "> step 1/2 archiving ... " %s
    tar --directory="$installDirHome" -rf "$backupDir/backup$today.tar" "$installDirName"
    passIf0 "$?" "BackupCore" "Fail to tar."

    printf "> step 2/2 zipping ... " %s
    gzip -f "$backupDir/backup$today.tar"
    passIf0 "$?" "BackupCore" "Fail to gzip."

    printf " OK !!  \n" %s
	  Succ "BackupCore" "OK!"
	else
	  Warn "BackupCore" "Nothing to backup from directory[$(yellow "$installDir")]. Ignore this if this is the first-time installation."
	  return 0
	fi
}

BackupDefault(){
  EnsureNotEmpty "MODULE_DEPLOY_HOME"
  EnsureNotEmpty "MODULE_BACKUP_HOME"
  BackupCore "$MODULE_DEPLOY_HOME" "$MODULE_BACKUP_HOME"
}

BackupUpjasWar(){
  EnsureNotEmpty "MODULE_BACKUP_HOME"
  EnsureNotEmpty "UPJAS_STANDALONE_DEPLOY_HOME"
  BackupCore "$UPJAS_STANDALONE_DEPLOY_HOME" "$MODULE_BACKUP_HOME"
}

BackupUpjasConf(){
  EnsureNotEmpty "MODULE_BACKUP_HOME"
  EnsureNotEmpty "UPJAS_CONF_HOME"
  BackupCore "$UPJAS_CONF_HOME" "$MODULE_BACKUP_HOME"
}

## uninstall
UninstallCore(){
  local installDir=$1
  local force=$2

  Info "UninstallCore" "Uninstalling [$(yellow "$installDir")] ..."
  if [ -r $installDir ]; then
    rm -r $installDir
    passIf0 "$?" "UninstallCore" "Fail to remove."
    Succ "UninstallCore" "OK!"
  elif [ "$force" != "1" ]; then
    Warn "UninstallCore" "Nothing to uninstall from directory[$(yellow "$installDir")]. Ignore this if this is the first-time installation."
  fi
}

UninstallDefault(){
  EnsureNotEmpty "MODULE_DEPLOY_HOME"
  UninstallCore "$MODULE_DEPLOY_HOME"
}

UninstallUpjasWar(){
  EnsureNotEmpty "UPJAS_STANDALONE_DEPLOY_HOME"
  UninstallCore "$UPJAS_STANDALONE_DEPLOY_HOME"
}

UninstallUpjasConf(){
  EnsureNotEmpty "UPJAS_CONF_HOME"
  UninstallCore "$UPJAS_CONF_HOME"
}

## ACContainer need one to deal with aclogs and plugins dirs

UnregisterACPlugin(){
  EnsureNotEmpty "MODULE_NAME" # plugin module's name
  Info "UnregisterACPlugin" "Unregistering previously uninstalled ACPlugins in module[$MODULE_NAME] ..."

  EnsureNotEmpty "AC_PLUGIN_CONFIG"
  EnsureFileExist "$AC_PLUGIN_CONFIG"
  Info "UnregisterACPlugin" "Unregistering [$MODULE_NAME] in File[$AC_PLUGIN_CONFIG] ..."
  sed -i "/$MODULE_NAME/d" "$AC_PLUGIN_CONFIG"
  passIf0 "$?" "UnregisterACPlugin" "Fail to unregister file[$AC_PLUGIN_CONFIG]."

  EnsureNotEmpty "AC_PLUGIN_ENV"
  EnsureFileExist "$AC_PLUGIN_ENV"
  Info "UnregisterACPlugin" "Unregistering [$MODULE_NAME] in File[$AC_PLUGIN_ENV] ..."
  sed -i "/$MODULE_NAME/d" "$AC_PLUGIN_ENV"
  passIf0 "$?" "UnregisterACPlugin" "Fail to unregister file[$AC_PLUGIN_ENV]."

  EnsureNotEmpty "AC_PLUGIN_LOG"
  EnsureFileExist "$AC_PLUGIN_LOG"
  Info "UnregisterACPlugin" "Unregistering [$MODULE_NAME] in File[$AC_PLUGIN_LOG] ..."
  sed -i "/$MODULE_NAME/d" "$AC_PLUGIN_LOG"
  passIf0 "$?" "UnregisterACPlugin" "Fail to unregister file[$AC_PLUGIN_LOG]."

  Succ "UnregisterACPlugin" "OK!"
}

## install
InstallCore(){
  local packageDir=$1 #源目录
  local installDir=$2 #目标目录
  local needTS=$3

  Info "InstallCore" "packageDir=$(yellow "$packageDir"), installDir=$(yellow "$installDir")"
  test -r $packageDir
  passIf0 "$?" "InstallCore" "The package directory[$packageDir] doesn't exsit, nothing to install."
  test ! -e $installDir
  passIf0 "$?" "InstallCore" "The installation directory[$installDir] already exsits, should have been uninstalled."

  mkdir -p $installDir
  passIf0 "$?" "InstallCore" "Fail to make directory[$installDir]."
  cp -r $packageDir/* $installDir
  passIf0 "$?" "InstallCore" "Fail to copy."
  if [ "$needTS" = "1" ];then
    EnsureNotEmpty "TIMESTAMP"
    local timestamp=$TIMESTAMP
    touch $installDir/$timestamp.timestamp
    passIf0 "$?" "InstallCore" "Fail to touch timestamp[$installDir/$timestamp.timestamp]."
  fi
  Succ "InstallCore" "OK!"
}

InstallDefault(){
  EnsureNotEmpty "MODULE_CONTENT_WORK_HOME"
  EnsureNotEmpty "MODULE_DEPLOY_HOME"
  InstallCore "$MODULE_CONTENT_WORK_HOME" "$MODULE_DEPLOY_HOME" "1"
}

InstallUpjasConf(){
  EnsureNotEmpty "MODULE_CONTENT_WORK_HOME"
  EnsureNotEmpty "UPJAS_CONF_HOME"
  InstallCore  "$MODULE_CONTENT_WORK_HOME/upjas-conf" "$UPJAS_CONF_HOME" "1"
}

InstallUpjasWar(){
  EnsureNotEmpty "MODULE_CONTENT_WORK_HOME"
  EnsureNotEmpty "UPJAS_STANDALONE_DEPLOY_HOME"
  InstallCore  "$MODULE_CONTENT_WORK_HOME/standalone/deployments" "$UPJAS_STANDALONE_DEPLOY_HOME" "1"
}

BackupLxkAppOnNfs(){
  Info "BackupLxkAppOnNfs" "Starting to backup lxk app module to NFS ..."

  EnsureDirExistOrMake "$NFS_BS_HOME"

  UninstallCore "$NFS_BS_HOME/$MODULE_NAME"

  InstallCore "$MODULE_DEPLOY_HOME" "$NFS_BS_HOME/$MODULE_NAME"

  Succ "BackupLxkAppOnNfs" "OK!"
}

RollbackInstallDefault(){
  EnsureNotEmpty "MODULE_BACKUP_HOME"
  EnsureNotEmpty "MODULE_DEPLOY_HOME"
  EnsureNotEmpty "ROLLBACK_TIMESTAMP"
  InstallCore "${MODULE_BACKUP_HOME}/${ROLLBACK_TIMESTAMP}/$MODULE_NAME" "$MODULE_DEPLOY_HOME"

  rm -r "${MODULE_BACKUP_HOME}/${ROLLBACK_TIMESTAMP}"
  passIf0 "$?" "RollbackInstallDefault" "Fail to remove."
  Succ "RollbackInstallDefault" "OK!"
}

RollbackInstallUpjasConf(){
  EnsureNotEmpty "MODULE_BACKUP_HOME"
  EnsureNotEmpty "ROLLBACK_TIMESTAMP"
  EnsureNotEmpty "UPJAS_CONF_HOME"
  InstallCore "$MODULE_BACKUP_HOME/$ROLLBACK_TIMESTAMP/upjas-conf" "$UPJAS_CONF_HOME"

  rm -r "$MODULE_BACKUP_HOME/$ROLLBACK_TIMESTAMP/upjas-conf"
  passIf0 "$?" "RollbackInstallUpjasConf" "Fail to remove upjas-conf [$MODULE_BACKUP_HOME/$ROLLBACK_TIMESTAMP/upjas-conf]."

  rmdir --ignore-fail-on-non-empty "$MODULE_BACKUP_HOME/$ROLLBACK_TIMESTAMP"
  passIf0 "$?" "RollbackInstallUpjasConf" "Fail to remove directory [$MODULE_BACKUP_HOME/$ROLLBACK_TIMESTAMP]."

  Succ "RollbackInstallUpjasConf" "OK!"
}

RollbackInstallUpjasWar(){
  EnsureNotEmpty "MODULE_BACKUP_HOME"
  EnsureNotEmpty "ROLLBACK_TIMESTAMP"
  EnsureNotEmpty "UPJAS_STANDALONE_DEPLOY_HOME"
  InstallCore "$MODULE_BACKUP_HOME/$ROLLBACK_TIMESTAMP/deployments" "$UPJAS_STANDALONE_DEPLOY_HOME"

  rm -r "$MODULE_BACKUP_HOME/$ROLLBACK_TIMESTAMP/deployments"
  passIf0 "$?" "RollbackInstallUpjasWar" "Fail to remove deployments [$MODULE_BACKUP_HOME/$ROLLBACK_TIMESTAMP/deployments]."

  rmdir --ignore-fail-on-non-empty "$MODULE_BACKUP_HOME/$ROLLBACK_TIMESTAMP"
  passIf0 "$?" "RollbackInstallUpjasWar" "Fail to remove directory [$MODULE_BACKUP_HOME/$ROLLBACK_TIMESTAMP]."

  Succ "RollbackInstallUpjasWar" "OK!"
}

## postinstall
PostinstallACContainer(){
  # new ac.env
  Info "PostinstallACContainer" "Sourcing newly installed ac.env ..."
  EnsureFileExist "$AC_BIN_HOME/ac.env"
  source "$AC_BIN_HOME/ac.env" # AC_PORT .. 2nd
  # ac_plugin_dir
  Info "PostinstallACContainer" "Making ACPlugin Management Directory ..."
  EnsureNotEmpty "AC_PLG_HOME"
  EnsureDirExistOrMake "$AC_PLG_HOME"
  EnsureNotEmpty "AC_PLUGIN_ENV"
  EnsureFileExistOrTouch "$AC_PLUGIN_ENV"
  EnsureNotEmpty "AC_PLUGIN_CONFIG"
  EnsureFileExistOrTouch "$AC_PLUGIN_CONFIG"
  EnsureNotEmpty "AC_PLUGIN_LOG"
  EnsureFileExistOrTouch "$AC_PLUGIN_LOG"
  # ac_log_dir
  Info "PostinstallACContainer" "Making AC logs Directory ..."
  EnsureNotEmptyOrCreate "AC_LOG_HOME" "$(cd "$AC_HOME/.."&& pwd)"/aclogs
  EnsureDirExistOrMake "$AC_LOG_HOME"
}

PostinstallACDockerModule(){
  EnsureNotEmpty "MODULE_DEPLOY_HOME"
  EnsureDirExist "$MODULE_DEPLOY_HOME"
  EnsureFileExist "$MODULE_DEPLOY_HOME/conf"/*.dk
  Info "PostinstallACDockerModule" "Moving docker configurations '*.dk' to upper directory."
  mv "$MODULE_DEPLOY_HOME/conf"/*.dk "$MODULE_DEPLOY_HOME"
  passIf0 "$?" "PostinstallACDockerModule" "Fail to move '*.dk' from [$(yellow "$MODULE_DEPLOY_HOME/conf")] to upper directory."
}

PostinstallACPlugin(){
  EnsureNotEmpty "MODULE_DEPLOY_HOME"
  EnsureDirExist "$MODULE_DEPLOY_HOME"
  EnsureFileExist "$MODULE_DEPLOY_HOME/conf"/*.plugin
  Info "PostinstallACPlugin" "Moving plugin configurations '*.plugin' to upper directory."
  mv "$MODULE_DEPLOY_HOME/conf"/*.plugin "$MODULE_DEPLOY_HOME"
  passIf0 "$?" "PostinstallACPlugin" "Fail to move '*.plugin' from [$(yellow "$MODULE_DEPLOY_HOME/conf")] to upper directory."

  RegisterACPlugin
}

RegisterACPlugin(){
  EnsureNotEmpty "MODULE_NAME" # plugin module's name
  Info "RegisterACPlugin" "Registering previously installed ACPlugins in module[$MODULE_NAME] ..."

  EnsureNotEmpty "AC_PLUGIN_CONFIG"
  EnsureFileExist "$AC_PLUGIN_CONFIG"
  Info "RegisterACPlugin" "Registering ['*.plugin'] into File[$AC_PLUGIN_CONFIG] ..."
  PLUGIN_CFG_FILES=($(ls "$MODULE_DEPLOY_HOME"/*.plugin))
  for plugin in "${PLUGIN_CFG_FILES[@]}";do
      Info "RegisterACPlugin" "Adding contents from file[$plugin] ..."
      cat "$plugin" |tee -a "$AC_PLUGIN_CONFIG"
  done
  Succ "RegisterACPlugin" "Registered ['*.plugin'] into File[$AC_PLUGIN_CONFIG]."

  EnsureNotEmpty "AC_PLUGIN_ENV"
  EnsureFileExist "$AC_PLUGIN_ENV"
  Info "RegisterACPlugin" "Registering ['*.env'] into File[$AC_PLUGIN_ENV] ..."
  PLUGIN_ENV_FILE=($(ls "$MODULE_DEPLOY_HOME/conf"/*.env))
  for env in "${PLUGIN_ENV_FILE[@]}";do
      Info "RegisterACPlugin" "Adding contents from file[$env] ..."
      echo ". $env" |tee -a "$AC_PLUGIN_ENV"
  done
  Succ "RegisterACPlugin" "Registered ['*.env'] into File[$AC_PLUGIN_ENV]."
  ##
  EnsureNotEmpty "AC_PLUGIN_LOG"
  EnsureFileExist "$AC_PLUGIN_LOG"
  Info "RegisterACPlugin" "Registering ['*log.prop'] into File[$AC_PLUGIN_LOG] ..."
  PLUGIN_LOG_FILE=($(ls "$MODULE_DEPLOY_HOME/conf"/*log.prop))
  for log in "${PLUGIN_LOG_FILE[@]}";do
      Info "RegisterACPlugin" "Adding contents from file[$log] ..."
      echo "$log" |tee -a "$AC_PLUGIN_LOG"
  done
  Succ "RegisterACPlugin" "Registered ['*log.prop'] into File[$AC_PLUGIN_LOG]."

  Succ "RegisterACPlugin" "OK!"
}

## start
StartUpjas(){
  Info "StartUpjas" "Starting Upjas[$UPJAS_HOME] with standalone module[$(yellow "$MODULE_NAME")] ..."
  EnsureFileExist "$UPJAS_BIN_HOME/check_to_start.sh"
  EnsureFileExist "$UPJAS_BIN_HOME/jon_upjas_start.sh"

  cd "$UPJAS_BIN_HOME"
  sh check_to_start.sh
  passIf0 "$?" "StartUpjas" "Fail to check when starting."

  if [ -s upjas-*-gc* ]; then
     mv upjas-*-gc*  gclogbak/
  fi

  sh jon_upjas_start.sh
  passIf0 "$?" "StartUpjas" "Fail to start."
  Succ "StartUpjas" "Upjas[$UPJAS_HOME] is successfully started."
}

StartACDockersInSpecifiedModule(){
  local module_name=$1 #指定的module序列
  Info "StartACDockersInSpecifiedModule" "Starting ACDockers in module[$(yellow "$module_name")] ..."
  EnsureFileExist "$AC_BIN_HOME/start.sh"
  EnsureDirExist "$DK_HOME/$module_name"

  sh "$AC_BIN_HOME"/start.sh -m"$module_name"
  passIf0 "$?" "StartACDockersInSpecifiedModule" "Fail to start."
  Succ "StartACDockersInSpecifiedModule" "ACDockers in module[$(yellow "$module_name")] are successfully started."

}

StartAllDynamicACDockers(){
  Info "StartAllDynamicACDockers" "Starting all dynamic ACDockers ..."
  StartACDockersInSpecifiedModule "dynamic"
}

StartACDockersInThisModule(){
  Info "StartACDockersInThisModule" "Starting ACDockers in module[$(yellow "$MODULE_NAME")] ..."
  EnsureFileExist "$AC_BIN_HOME/start.sh"
  EnsureDirExist "$MODULE_DEPLOY_HOME"

  sh "$AC_BIN_HOME"/start.sh -m"$MODULE_NAME"
  passIf0 "$?" "StartACDockersInThisModule" "Fail to start."
  Succ "StartACDockersInThisModule" "ACDockers in module[$(yellow "$MODULE_NAME")] are successfully started."
}

StartSpecifiedACDockers(){
  local dockers=$1 #指定的dockers序列，逗号分隔
  Info "StartSpecifiedACDockers" "Starting Specified ACDockers [$(yellow "$dockers")] ..."
  EnsureFileExist "$AC_BIN_HOME/start.sh"
  EnsureDirExist "$MODULE_DEPLOY_HOME"

  sh "$AC_BIN_HOME"/start.sh -d"$dockers"
  passIf0 "$?" "StartSpecifiedACDockers" "Fail to start."
  Succ "StartSpecifiedACDockers" "Specified ACDockers [$(yellow "$dockers")] are successfully started."
}

StartACSwarm(){
  Info "StartACSwarm" "Starting ACSwarm ..."
  test -f "$AC_BIN_HOME/console.sh"
  passIf0 "$?" "StartACSwarm" "Failure: Missing file[$AC_BIN_HOME/console.sh]. ACContainer may have not been installed correctly, please check it."

  sh "$AC_BIN_HOME/console.sh" -b"c->q"
  passIf0 "$?" "StartACSwarm" "Fail to start ACSwarm."
  Succ "StartACSwarm" "ACSwarm is successfully started."
}

## verify
CheckACSwarm(){
  Info "CheckACSwarm" "Checking ACSwarm ..."
  test -f "$AC_BIN_HOME/.acswarm.pid"
  passIf0 "$?" "CheckACSwarm" "Fail to find ACSwarm pid tag file, start false!!"

	local pid=$(cat "$AC_BIN_HOME/.acswarm.pid")
	local _pid=$(ps -ef|awk  '{print $2}'|grep "^$pid$")
	test "$_pid" -eq "$pid"
	passIf0 "$?" "CheckACSwarm" "Fail to find ACSwarm process[$pid], start false!!"

 	local tag=0
 	while (($tag<5))
  do
    tag=$((tag+1))
    Info "CheckACSwarm" "Checking for the [$tag] time ... ..."
    checkNet "${AC_PORT}"
    if [ $? -eq 0 ];then
      break;
    else
      sleep 1
    fi
  done
  tag=$((tag+1))
  Info "CheckACSwarm" "Checking for the [$tag] time ... ..."
	checkNet "${AC_PORT}"
	passIf0 "$?" "CheckACSwarm" "Fail to find out listening port[$AC_PORT] after [$tag] attempts."

	Succ "CheckACSwarm" "Success: ACSwarm is operating as Process[$pid], on Port[$AC_PORT]."
}

CheckACDockersInThisModule(){
  Info "CheckACDockersInThisModule" "Checking ACDockers in module[$(yellow "$MODULE_NAME")] ..."
  EnsureFileExist "$AC_BIN_HOME/check.sh"
  EnsureDirExist "$MODULE_DEPLOY_HOME"

  sh "$AC_BIN_HOME"/check.sh -m"$MODULE_NAME"
  passIf0 "$?" "CheckACDockersInThisModule" "Fail when check."
  Succ "CheckACDockersInThisModule" "ACDockers in module[$(yellow "$MODULE_NAME")] are successfully checked."
}

CheckSpecifiedACDockers(){
  local dockers=$1 #指定的dockers序列，逗号分隔
  Info "CheckSpecifiedACDockers" "Checking Specified ACDockers [$(yellow "$dockers")] ..."
  EnsureFileExist "$AC_BIN_HOME/check.sh"
  EnsureDirExist "$MODULE_DEPLOY_HOME"

  sh "$AC_BIN_HOME"/check.sh -d"$dockers"
  passIf0 "$?" "CheckSpecifiedACDockers" "Fail when check."
  Succ "CheckSpecifiedACDockers" "Specified ACDockers [$(yellow "$dockers")] are successfully checked."
}

