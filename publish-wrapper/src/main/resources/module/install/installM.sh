#!/usr/bin/sh

MODULE_INSTALLER_HOME=$(cd "$(dirname "$0")"&& pwd)
. ${MODULE_INSTALLER_HOME}/utils.sh
. ${MODULE_INSTALLER_HOME}/plugins.sh

. ${MODULE_INSTALLER_HOME}/lifecycle.cfg

MODULE_PATCH_HOME=$(cd $MODULE_INSTALLER_HOME/..&& pwd)
MODULE_NAME=$(basename "$MODULE_PATCH_HOME")
#**************************************************************
#*********使用说明*********************************************
Usage()
{
  Info "Usage" "installM.sh"
}

#***************************************************************
#############################业务逻辑开始#######################
lifecycle_mode=$1
case "$lifecycle_mode" in
rollback|Rollback|ROLLBACK|r)
  lifecycle_mode="rollback"
  LIFECYCLE=("initialize" "unzip" "stop" "uninstall" "install" "start" "verify")
  ;;
clean|Clean|CLEAN|c)
  lifecycle_mode="clean"
  LIFECYCLE=("initialize" "unzip" "localize" "stop" "backup" "uninstall" "install" "start" "verify")
  ;;
*)
  lifecycle_mode="install"
  LIFECYCLE=("initialize" "localize" "stop" "backup" "uninstall" "install" "start" "verify")
  ;;
esac

Info "installM.sh $lifecycle_mode" "Parsing lifecycle: $(yellow "Mode: $lifecycle_mode")"
eval "${lifecycle_mode}Mode"
passIf0 "$?" "installM.sh $lifecycle_mode" "Lifecycle parsing failure."

ExecPhase(){
  local PHASE=$1
  Info "Begin" "ExecPhase >>$(cyan $PHASE)<<"
  echo "================================"
  passIf0 "$(Contain "${LIFECYCLE[*]}" "$PHASE")" "installM.sh $lifecycle_mode" "$(cyan $PHASE) is an illegal phase."
  if [ -n "$(eval "echo -n \${${PHASE}_phase}")" ]; then
    eval "Info \"installM.sh $lifecycle_mode\" \"Binding Plugin [ \$(blue \${${PHASE}_phase}) ] @$(pink $MODULE_NAME)\""
    eval "eval \"\${${PHASE}_phase}\""
    passIf0 "$?" "installM.sh $lifecycle_mode" "Fail to extract [${PHASE}_phase] plugins."
  else
    Info "installM.sh $lifecycle_mode" "No plugin binded to this phase. Skip."
  fi
  echo "================================"
  Succ "End" "ExecPhase >>$(cyan $PHASE)<<"
  echo ""
}

echo "###########        $(Cyan "Begin") to $lifecycle_mode module [$(pink "$MODULE_NAME")]  ...        ###############"
	for phase in "${LIFECYCLE[@]}";do
	  ExecPhase $phase
	done
echo "###########        $(Green "Succ") to $lifecycle_mode module [$(pink "$MODULE_NAME")]  ...         ###############"
