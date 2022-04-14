#!/bin/bash

#set -ex
#ini配置文件
INI_PATH=$1
#选择ini配置里个别几个组件进行安装，以','为分隔符,为空默认全部安装
SPLIT_FLAG=","
SELECTS=$2
#下载的URL
DOWNLOAD_URL=$SCRIPT_URL;
#ini里全局配置SECTION标识
GLOBLE_SECTION='GLOBLE'
DEFAULT_PATH='/tmp'
DEFAULT_RUN='install.sh'

function log_info()
{
  echo -e `date "+%Y-%m-%d %H:%M:%S"`" [INFO]: $@"
}

function log_error()
{
  echo -e `date "+%Y-%m-%d %H:%M:%S"`" [ERROR]: $@"
}

function install()
{
	local file=$1
	local path=$2
	local run=$3
	local url=$4
	local parameters=$5

	# 字符串转成数组传参
	argv=()
	for opts in parameters
	do
		argv=(${argv[@]} opts)
	done 
	wget --no-check-certificate --tries=2 --waitretry=1 --timeout=10 -O $path/$file  ${url}/$file >/dev/null 2>&1
	if [ $? -ne 0 ];then
		log_error "wget $path/$file from ${url}/$file fail."
		return 2
	fi
	unzip $path/$file
	bash $path/$file/$run ${argv[@]}
	if [ $? -ne 0 ];then
		log_error "bash exec $path/$file/$run fail."
		rm -rf $path/$file
		return 1
	fi
	rm -rf $path/$file
	return 0
}

function usage_help()
{
    echo "  DESC   install tools"
    echo "  USAGE  bash install.sh <xx.ini> <select target>"
}

function read_value()
{ 
    local file_name=$1; local section=$2; local key=$3
    #ret=`awk -F '=' '/\['$section'\]/{a=1}a==1&&$1~/'$key'/{print $2}' $file_name`
	ret=`awk -F '=' -v section="[$section]" -v k="$key" '$0==section{f=1;next}/\[/{f=0;next}f&&$1==k{print $2}' $file_name`
	if [[ $? -ne 0 ]] || [[ ! -n "$ret" ]];then
		return 1
	fi
	#删除单双引号
	ret=${ret#*\'}
	ret=${ret%\'*}
	ret=${ret#*\"}
	ret=${ret%\"*}
	echo $ret
	return 0
}

function get_all_section()
{ 
    local file_name=$1; local all_section=''
    for sec in `grep '\[*\]' $file_name`
    do
      sec=${sec#*[}
      sec=${sec%]*}
	  if [[ "$sec" == "$GLOBLE_SECTION" ]];then
		continue
	  fi
      all_section="$all_section $sec"
    done
    echo $all_section
	return 0
}


if [ ! -f $INI_PATH ];then
	log_error "File[$INI_PATH] of ini is invalid, please check it."
	usage_help
	exit 1
fi

#优先读取配置里的URL，否则用全局环境变量的
url=`read_value $INI_PATH $GLOBLE_SECTION 'url'`
if [ -n $url ];then
	export DOWNLOAD_URL=$url;
	log_info "Set new url: $url"
fi

stop_if_err=`read_value $INI_PATH $GLOBLE_SECTION 'stop'`
rollback_if_err=`read_value $INI_PATH $GLOBLE_SECTION 'rollback'`

if [ -n "$SELECTS" ];then
	IFS=$SPLIT_FLAG
else
	SELECTS=`get_all_section $INI_PATH`
fi

log_info "Install these: $SELECTS"
#安装程序以配置为主
for section in $SELECTS
do
	File=''
	Path=''
	Run=''
	Param=''
	if ! File=`read_value $INI_PATH $section 'file'`;then
		File=$section
	fi
	if ! Path=`read_value $INI_PATH $section 'path'`;then
		Path=$DEFAULT_PATH
	fi
	if ! Run=`read_value $INI_PATH $section 'run'`;then
		Run=$DEFAULT_RUN
	fi
	if ! Param=`read_value $INI_PATH $section 'param'`;then
		Param=''
	fi

	if install_process ${File} ${Path} ${Run} $DOWNLOAD_URL ${Param};then
		log_info "install $section finished."
		continue
	fi
	log_error "Install $section fail, file:${File}, path: ${Path}, run: ${Run}, param: ${Param}."
	if [[ "$stop_if_err" == "true" ]] || [[ "$stop_if_err" == "yes" ]];then
		log_error "Stop install if some error."
		exit 1
	fi
done
log_info "Install $INI_PATH finished!!"

