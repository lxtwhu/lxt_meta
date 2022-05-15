#!/usr/bin/sh

checkReturn(){ 
	local mg=$1
	local rv=$2
	if [[ ! ${rv} -eq "0" ]];then
		echo "${mg}[rv=${rv}]"
		exit $rv
	fi
}

passIf0(){ # 参数 （ 0/1判断式 报错位置 报错原因）
  local rv=$1
  if [[ ! ${rv} -eq "0" ]];then
    shift 1
		Error $@
		exit $rv
	fi
}

setValue(){
  local paraTag=$1
  local paraReq=$2
  local paraVal=$3

  ##  loop from the 1st param
  shift 3
  until [ -z "$1" ]
  do
      ## test if the param ${p} begins with ${paraTag}
      ## if match, then set the value to param ${paraVal} and return
      ## else go on to loop
      if test "${1#$paraTag}" != "$1"
      then
          paraVal="${1#"$paraTag"}"

          if [ "$paraVal" == "" ];
          then
                        echo "ERROR!! tag:${paraTag}: value is null !!  EXIT FORCE!!!"
                        exit 97
                  else
                                printf "$paraVal" %s
                  if [ $paraReq -eq 1 ];
                  then
                        return 1
                  else
                                return 0
                  fi
          fi
      fi
      shift

  done
  printf "$paraVal" %s
  return 0
}

getOption(){
  echo "developing"
}

Contain(){
    local zoo=$1
    local creature=$2
    for animal in $zoo;do
        if [ "$animal" = "$creature" ];then
            echo 0
            return 0
        fi
    done
    echo 1
    return 1
}

black(){ # 文字变色
  echo -ne  "\x1b[30m$@\x1b[0m"
}

Black(){ # 背景变色
  echo -ne  "\x1b[40m$@\x1b[0m"
}

blush(){ # red is an Editor, so we use blush
  echo -ne  "\x1b[31m$@\x1b[0m"
}

Blush(){ # red is an Editor, so we use blush
  echo -ne  "\x1b[41m$@\x1b[0m"
}

green(){ # 文字变色
  echo -ne  "\x1b[32m$@\x1b[0m"
}

Green(){ # 背景变色
  echo -ne  "\x1b[42m$@\x1b[0m"
}

yellow(){ # 文字变色
  echo -ne  "\x1b[33m$@\x1b[0m"
}

Yellow(){ # 背景变色
  echo -ne  "\x1b[43m$@\x1b[0m"
}

blue(){ # 文字变色
  echo -ne  "\x1b[34m$@\x1b[0m"
}

Blue(){ # 背景变色
  echo -ne  "\x1b[44m$@\x1b[0m"
}

pink(){ # 文字变色
  echo -ne  "\x1b[35m$@\x1b[0m"
}

Pink(){ # 背景变色
  echo -ne  "\x1b[45m$@\x1b[0m"
}

cyan(){ # 文字变色
  echo -ne  "\x1b[36m$@\x1b[0m"
}

Cyan(){ # 背景变色
  echo -ne  "\x1b[46m$@\x1b[0m"
}

white(){ # 文字变色
  echo -ne  "\x1b[37m$@\x1b[0m"
}

White(){ # 背景变色
  echo -ne  "\x1b[47m$@\x1b[0m"
}

Succ(){ # 参数1提示位置，其余参数提示原因
  green "[SUCC]$1"
  shift 1
  echo -e " $@"
}

Error(){ # 参数1提示位置，其余参数提示原因
  blush "[ERRO]$1"
  shift 1
  echo -e " $@"
}

Info(){ # 参数1提示位置，其余参数提示原因
  cyan "[INFO]$1"
  shift 1
  echo -e " $@"
}

Warn(){ # 参数1提示位置，其余参数提示原因
  pink "[WARN]$1"
  shift 1
  echo -e " $@"
}
# 确保变量
EnsureNotEmpty(){
  local varName=$1
  eval "varValue=\$$varName"
  test -n "$varValue"
  passIf0 "$?" "EnsureNotEmpty" "\$$varName is empty."
  Info "EnsureNotEmpty" "$varName=$(yellow "$varValue")"
}

EnsureNotEmptyOrCreate(){
  local varName=$1
  local defaultValue=$2
  eval "varValue=\$$varName"
  if [ -z "$varValue" ]; then
    test -n "$defaultValue"
    passIf0 "$?" "EnsureNotEmptyOrCreate" "\$$varName is empty, and its default value is empty too."
    eval "$varName=$defaultValue"
    Info "EnsureNotEmptyOrCreate" "$varName=$(yellow "$defaultValue")[Default]"
  else
    Info "EnsureNotEmptyOrCreate" "$varName=$(yellow "$varValue")"
  fi
}
# 确保目录
EnsureDirExist(){
  local dirPath=$1
  test -d "$dirPath"
  passIf0 "$?" "EnsureDirExist" "dirPath[$dirPath] doesn't exist!"
}

EnsureDirExistOrMake(){
  local dirPath=$1
  if [ ! -d "$dirPath" ]; then
      Info "EnsureDirExistOrMake" "dirPath[$(yellow "$dirPath")] doesn't exist. Making Directory ..."
      mkdir -p "$dirPath"
      passIf0 "$?" "EnsureDirExistOrMake" "Fail when making directory[$dirPath], please check it!"
      Succ "EnsureDirExistOrMake" "Making Directory Success."
  fi
}
# 确保文件
EnsureFileExist(){
  local file=$1
  test -f "$file"
  passIf0 "$?" "EnsureFileExist" "File[$file] doesn't exist!"
}

EnsureFileExistOrTouch(){
  local file=$1
  if [ ! -f "$file" ]; then
      Info "EnsureFileExistOrTouch" "File[$(yellow "$file")] doesn't exist. Touching it ..."
      local dir=$(dirname "$file")
      if [ -n "$dir" ]; then
          EnsureDirExistOrMake "$dir"
      fi
      touch "$file"
      passIf0 "$?" "EnsureFileExistOrTouch" "Fail when touching file[$file], please check it!"
      Succ "EnsureFileExistOrTouch" "Touching file Success."
  fi
}

checkNet(){
	local port=$1
	Info "checkNet" "Checking status of listening port[$port] ..."
	which lsof 1>/dev/null 2>&1
	if [[ $? -eq "0" ]];then
		lsof -i :${port} | grep LISTEN
	else
		which netstat 1>/dev/null 2>&1
		if [[ $? -eq "0" ]];then
		  netstat -an | grep ":${port} " | grep LISTEN
		else
			Error "checkNet" "Fail to find 'lsof' or 'netstat' to check net!!"
			return 255
		fi
	fi
}

