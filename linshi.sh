#!/bin/bash
# https://github.com/Hyy2001X/AutoBuild-Actions
# AutoBuild Module by Hyy2001
# AutoUpdate for Openwrt

Version=V6.8

function TIME() {
  local Color
  [[ -z $1 ]] && {
    echo -ne "\n${Grey}[$(date "+%H:%M:%S")]${White} "
  } || {
  case $1 in
    r) Color="${Red}";;
    g) Color="${Green}";;
    b) Color="${Blue}";;
    B) Color="${BLUEB}";;
    y) Color="${Yellow}";;
    h) Color="${BCyan}";;
    z) Color="${Purple}";;
    x) Color="${Grey}";;
  esac
    [[ $# -lt 2 ]] && {
      echo -e "\n${Grey}[$(date "+%H:%M:%S")]${White} $1"
      LOGGER $1
    } || {
      echo -e "\n${Grey}[$(date "+%H:%M:%S")]${White} ${Color}$2${White}"
      LOGGER $2
    }
  }
}

function Shell_Helper() {
if [[ -f /etc/LOCAL_Version ]]; then
  export LOCAL_Version="$(cat /etc/LOCAL_Version)" > /dev/null 2>&1
else
  wget -q -P ${Download_Path} https://ghproxy.com/${Github_API2} -O ${API_PATH} > /dev/null 2>&1
  export LOCAL_Version="$(egrep -o "${LOCAL_CHAZHAO}-${BOOT_Type}-[a-zA-Z0-9]+${Firmware_SFX}" ${API_PATH} | awk 'END {print}')" > /dev/null 2>&1
fi
clear
echo
echo
详细参数：
/overlay 可用:		${Overlay_Available}
/tmp 可用:		${TMP_Available}M
固件下载位置:		${Download_Path}
当前设备名称:		${CURRENT_Device}
固件上的名称:		${DEFAULT_Device}
当前固件版本:		${LOCAL_Firmware}
Github 地址:		${Github}
解析 API 地址:		${Github_API1}
固件下载地址:		${Github_Release}
更新运行日志:		${AutoUpdate_Log_Path}/AutoUpdate.log
固件作者:		${Author}
作者仓库:		${Library}
固件名称:		${LOCAL_Version}
固件格式:		${BOOT_Type}${Firmware_SFX}
exit 1
}

if [[ -f /bin/openwrt_info ]]; then
  [[ -z ${CURRENT_Version} ]] && TIME r "本地固件版本获取失败,请检查/bin/openwrt_info文件的值!" && exit 1
  [[ -z ${Github} ]] && TIME r "Github地址获取失败,请检查/bin/openwrt_info文件的值!" && exit 1
  chmod +x /bin/openwrt_info
  source /bin/openwrt_info 
else
  TIME r "未检测到openwrt_info文件,无法运行更新程序!"
  exit 1
fi

export Input_Option=$1
export Input_Other=$2
export Kernel="$(egrep -o "[0-9]+\.[0-9]+\.[0-9]+" /usr/lib/opkg/info/kernel.control)"
export Overlay_Available="$(df -h | grep ":/overlay" | awk '{print $4}' | awk 'NR==1')"
rm -rf "${Download_Path}" && export TMP_Available="$(df -m | grep "/tmp" | awk '{print $4}' | awk 'NR==1' | awk -F. '{print $1}')"
[ ! -d "${Download_Path}" ] && mkdir -p ${Download_Path}
opkg list | awk '{print $1}' > ${Download_Path}/Installed_PKG_List
export PKG_List="${Download_Path}/Installed_PKG_List"
export AutoUpdate_Log_Path="/tmp"

case ${Firmware_SFX} in
.img.gz | .img )
  [ -d /sys/firmware/efi ] && {
    export BOOT_Type="uefi"
  } || {
    export BOOT_Type="legacy"
  }
  export CURRENT_Device="$(jsonfilter -e '@.model.id' < /etc/board.json | tr ',' '_')"
;;
*)
  export CURRENT_Device="$(jsonfilter -e '@.model.id' < /etc/board.json | tr ',' '_')"
  export BOOT_Type="sysupgrade"
esac

export LOCAL_Firmware="${CURRENT_Version}"
export LOCAL_Xianshi="${CURRENT_Version}-${BOOT_Type}"

cat > /etc/openwrt_upgrade <<-EOF
LOCAL_Firmware="${CURRENT_Version}"
MODEL_type="${BOOT_Type}${Firmware_SFX}"
KERNEL_type="${Kernel} - ${LUCI_EDITION}"
EOF

function GET_PID() {
  local Result
  while [[ $1 ]];do
    Result=$(busybox ps | grep "$1" | grep -v "grep" | awk '{print $1}' | awk 'NR==1')
    [[ -n ${Result} ]] && echo ${Result}
  shift
  done
}

function LOGGER() {
  [[ ! -d ${AutoUpdate_Log_Path} ]] && mkdir -p ${AutoUpdate_Log_Path}
  [[ ! -f ${AutoUpdate_Log_Path}/AutoUpdate.log ]] && touch ${AutoUpdate_Log_Path}/AutoUpdate.log
  echo "[$(date "+%Y-%m-%d-%H:%M:%S")] [$(GET_PID AutoUpdate.sh)] $*" >> ${AutoUpdate_Log_Path}/AutoUpdate.log
}

cd /etc
clear && echo "Openwrt-AutoUpdate Script ${Version}"
echo
if [[ -z "${Input_Option}" ]];then
  export Upgrade_Options="sysupgrade -q"
  export Update_Mode=1
  TIME h "执行: 更新固件[保留配置]"
else
  case ${Input_Option} in
  -t | -n | -f | -u | -N | -s | -w)
    case ${Input_Option} in
    -t)
      export Input_Other="-t"
      TIME h "执行: 测试模式"
      TIME z "测试模式(只运行,不安装,查看更新固件操作流程是否正确)"
    ;;
    -w)
      export Input_Other="-w"
    ;;
    -n | -N)
      export Upgrade_Options="sysupgrade -n"
      TIME h "执行: 更新固件(不保留配置)"
    ;;
    -s)
      export Upgrade_Options="sysupgrade -F -n"
      TIME h "执行: 强制更新固件(不保留配置)"
    ;;
    -u)
      export AutoUpdate_Mode=1
      export Upgrade_Options="sysupgrade -q"
    ;;
    esac
  ;;
  -c)
      source /bin/openwrt_info
      TIME h "执行：更换[Github地址]操作"
      TIME y "地址格式：https://github.com/帐号/仓库"
      TIME z  "正确地址示例：https://github.com/281677160/build-actions"
      TIME h  "现在所用地址为：${Github}"
      echo
      read -p "请输入新的Github地址(直接回车为不修改,退出程序)：" Input_Other
      Input_Other="${Input_Other:-"$Github"}"
      Github_uci=$(uci get autoupdate.@login[0].github 2>/dev/null)
      [[ -n "${Github_uci}" ]] && [[ "${Github_uci}" != "${Input_Other}" ]] && {
        uci set autoupdate.@login[0].github=${Input_Other}
        uci commit autoupdate
        TIME y "Github 地址已更换为: ${Input_Other}"
        TIME y "UCI 设置已更新!"
        echo
      }
      Input_Other="${Input_Other:-"$Github"}"
      [[ "${Github}" != "${Input_Other}" ]] && {
        sed -i "s?${Github}?${Input_Other}?g" /bin/openwrt_info
        unset Input_Other
        exit 0
      } || {
        TIME g "INPUT: ${Input_Other}"
        TIME r "输入的 Github 地址相同,无需修改!"
        echo
        exit 1
      }
  ;;
  -h | -H | -l | -L)
    TIME y "加载信息中，请稍后..."
    Shell_Helper
  ;;
  -g | -G)
    bash /bin/replace.sh
    sleep 1
    exit 0
  ;;
  *)
    echo -e "\nERROR INPUT: [$*]"
    Shell_Helper
  ;;
  esac
fi

TIME g "正在获取云端数据..."
[ ! -d ${Download_Path} ] && mkdir -p ${Download_Path}
wget -q ${Github_API1} -O ${API_PATH} > /dev/null 2>&1
if [[ $? -ne 0 ]];then
  wget -q -P ${Download_Path} https://pd.zwc365.com/${Github_API2} -O ${API_PATH} > /dev/null 2>&1
  if [[ $? -ne 0 ]];then
    wget -q -P ${Download_Path} https://ghproxy.com/${Github_API2} -O ${API_PATH} > /dev/null 2>&1
  fi
  if [[ $? -ne 0 ]];then
    TIME r "获取固件版本信息失败,请检测网络,或者您更改的Github地址为无效地址,或者您的仓库是私库,或者发布已被删除!"
    echo
    exit 1
  fi
fi

export LOCAL_Version="$(egrep -o "${LOCAL_CHAZHAO}-${BOOT_Type}-[a-zA-Z0-9]+${Firmware_SFX}" ${API_PATH} | awk 'END {print}')"
echo "${LOCAL_Version}" > /etc/local_Version
TIME g "正在获取云端固件版本信息..."
export CLOUD_Version="$(egrep -o "${CLOUD_CHAZHAO}-[0-9]+-${BOOT_Type}-[a-zA-Z0-9]+${Firmware_SFX}" ${API_PATH} | awk 'END {print}')"
export CLOUD_Firmware="$(echo ${CLOUD_Version} | egrep -o "${SOURCE}-${DEFAULT_Device}-[0-9]+")"
export CLOUD_Xianshi="$(echo ${CLOUD_Version} | egrep -o "${SOURCE}-${DEFAULT_Device}-[0-9]+-${BOOT_Type}")"
[[ -z "${CLOUD_Version}" ]] && {
  TIME r "获取云端固件版本信息失败!"
  exit 1
} || {
  TIME g "对比本地版本和云端版本..."
}

[[ "${Input_Other}" == "-w" ]] && {
  echo -e "\nCLOUD_Firmware=${CLOUD_Firmware}" > /tmp/Version_Tags
  echo -e "\nLOCAL_Firmware=${CURRENT_Version}" >> /tmp/Version_Tags
  exit 0
}

let X=$(grep -n "${CLOUD_Version}" ${API_PATH} | tail -1 | cut -d : -f 1)-4
let CLOUD_Firmware_Size=$(sed -n "${X}p" ${API_PATH} | egrep -o "[0-9]+" | awk '{print ($1)/1048576}' | awk -F. '{print $1}')+1
echo
echo -e "\n本地版本：${LOCAL_Version}"
echo "云端版本：${CLOUD_Version}"
echo "设备名称：${CURRENT_Device}"
echo "固件作者：${Author}"
[[ "${Firmware_SFX}" =~ (.img.gz|.img) ]] && {
  echo "引导模式：${BOOT_Type}"
}
echo "固件体积：${CLOUD_Firmware_Size}M"
echo
if [[ ! "${Force_Update}" == 1 ]];then
  if [[ "${LOCAL_Firmware}" -eq "${CLOUD_Firmware}" ]];then
    [[ "${AutoUpdate_Mode}" == 1 ]] && exit 0
    TIME && read -p "当前版本和云端最高版本一致，是否还要重新安装固件?[Y/n]:" Choose
    [[ "${Choose}" == Y ]] || [[ "${Choose}" == y ]] && {
      TIME z "正在开始重新安装固件..."
    } || {
      TIME r "已取消重新安装固件,即将退出程序..."
      sleep 2
      exit 0
    }
  elif [[ "${LOCAL_Firmware}" -eq "${CLOUD_Firmware}" ]];then
    [[ "${AutoUpdate_Mode}" == 1 ]] && exit 0
    TIME && read -p "云端最高版本,低于您现在的版本,是否强制覆盖现有固件?[Y/n]:" Choose
    [[ "${Choose}" == Y ]] || [[ "${Choose}" == y ]] && {
      TIME z "正在开始使用云端版本覆盖现有固件..."
    } || {
      TIME r "已取消覆盖固件,退出程序..."
      sleep 1
      exit 0
    }
  else
    TIME y "检测到有可更新的固件版本,立即更新固件!"
  fi
fi

[[ "${TMP_Available}" -lt "${CLOUD_Firmware_Size}" ]] && {
  TIME g "tmp 剩余空间: ${TMP_Available}M"
  TIME r "tmp空间不足[${CLOUD_Firmware_Size}M],不够下载固件所需,请清理tmp空间或者增加运行内存!"
  echo
  exit 1
}

cd ${Download_Path}
TIME g "正在下载云端固件,请耐心等待..."
echo
[[ "$(cat ${Download_Path}/Installed_PKG_List)" =~ curl ]] && {
  export Google_Check=$(curl -I -s --connect-timeout 8 google.com -w %{http_code} | tail -n1)
  if [ ! "$Google_Check" == 301 ];then
    wget -q --show-progress --progress=bar:force:noscroll "https://ghproxy.com/${Release_download}/${CLOUD_Version}" -O ${CLOUD_Version}
    if [[ $? -ne 0 ]];then
      wget -q --show-progress --progress=bar:force:noscroll "https://pd.zwc365.com/${Release_download}/${CLOUD_Version}" -O ${CLOUD_Version}
      if [[ $? -ne 0 ]];then
        TIME r "下载云端固件失败,请尝试手动安装!"
        echo
        exit 1
      else
        TIME y "下载云端固件成功!"
      fi
    else
      TIME y "下载云端固件成功!"
    fi
  else
    wget -q --show-progress --progress=bar:force:noscroll "${Release_download}/${CLOUD_Version}" -O ${CLOUD_Version}
    if [[ $? -ne 0 ]];then
      wget -q --show-progress --progress=bar:force:noscroll "https://ghproxy.com/${Release_download}/${CLOUD_Version}" -O ${CLOUD_Version}
      if [[ $? -ne 0 ]];then
        TIME r "下载云端固件失败,请尝试手动安装!"
        echo
        exit 1
      else
        TIME y "下载云端固件成功!"
      fi
    else
      TIME y "下载云端固件成功!"
    fi
  fi
}

export LOCAL_MD5=$(md5sum ${CLOUD_Version} | cut -c1-3)
export LOCAL_256=$(sha256sum ${CLOUD_Version} | cut -c1-3)
export MD5_256=$(echo ${CLOUD_Version} | egrep -o "[a-zA-Z0-9]+${Firmware_SFX}" | sed -r "s/(.*)${Firmware_SFX}/\1/")
export CLOUD_MD5="$(echo "${MD5_256}" | cut -c1-3)"
export CLOUD_256="$(echo "${MD5_256}" | cut -c 4-)"
[[ ${LOCAL_MD5} != ${CLOUD_MD5} ]] && {
  TIME r "MD5对比失败,固件可能在下载时损坏,请检查网络后重试!"
  exit 1
}
[[ ${LOCAL_256} != ${CLOUD_256} ]] && {
  TIME r "SHA256对比失败,固件可能在下载时损坏,请检查网络后重试!"
  exit 1
}
[[ "${Input_Other}" == "-t" ]] && {
  TIME z "测试模式运行完毕!"
  rm -rf "${Download_Path}"
  echo
  exit 0
}

chmod 777 ${CLOUD_Version}
[[ "$(cat ${PKG_List})" =~ gzip ]] && opkg remove gzip > /dev/null 2>&1
TIME g "正在更新固件,更新期间请不要断开电源或重启设备 ..."
sleep 2
if [[ "${AutoUpdate_Mode}" == 1 ]] || [[ "${Update_Mode}" == 1 ]]; then
  source /etc/deletefile
  cp -Rf /etc/config/network /mnt/network
  mv -f /etc/config/luci /etc/config/luci-
  sysupgrade -b /mnt/back.tar.gz
  [[ $? == 0 ]] && {
    mv -f /etc/config/luci- /etc/config/luci
    export Upgrade_Options="sysupgrade -f /mnt/back.tar.gz"
  } || {
    mv -f /etc/config/luci- /etc/config/luci
    export Upgrade_Options="sysupgrade -q"
  }
fi

${Upgrade_Options} ${CLOUD_Version}

exit 0
