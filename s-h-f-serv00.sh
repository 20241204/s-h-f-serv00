#!/usr/bin/env bash
set -e
set -u
# set -x # 启用调试模式
# 日志文件路径
LOGFILE="script_log.txt"

# 定义全局变量
num_ports=0

# 起始时间
REPORT_DATE="$(TZ=':Asia/Shanghai' date +'%Y-%m-%d %T')"
REPORT_DATE_S="$(TZ=':Asia/Shanghai' date +%s)"


# Enables the ability to run your own software
devil binexec on
# Set Devil and shell language to English
devil lang set english
# Get a list of all available IP addresses owned by Serv00.com
devil vhost list public
# Display the list of reserved ports
devil port list

# 创建进入自定义目录
rm -rfv ${HOME}/s-h-f-serv00-*
mkdir -pv ${HOME}/s-h-f-serv00-${REPORT_DATE_S}/
cd ${HOME}/s-h-f-serv00-${REPORT_DATE_S}/

hy2_nodes=""
hy2_clients=""
URL="www.bing.com"

# 获取用户输入的要生成的 hy2 节点个数
#read -p "请输入要生成的hy2节点个数：" hy2_num

killMe() {
    # kill -9 $(ps | grep -v grep | grep sing-box-freebsd | awk '{print $1}')
    pkill sing-box-freebsd &
}

# 函数：清理当前端口
clear_port() {
    # 获取当前端口列表，并去除无关的空行和标题
    port_list=$(devil port list | grep -E '^[0-9]+[[:space:]]+[a-zA-Z]+' | sed 's/^[[:space:]]*//')

    # 检查是否有端口信息
    if [[ -z "$port_list" ]]; then
        echo "无端口"
    else
        # 遍历每一行端口信息
        while read -r line; do
            # 提取端口号和端口类型
            port=$(echo "$line" | awk '{print $1}')
            port_type=$(echo "$line" | awk '{print $2}')
            
            # 删除端口
            echo "删除端口 $port ($port_type)"
            devil port del "$port_type" "$port"
        done <<< "$port_list"
    fi  
}

# 函数：获取可用的 IP 地址数组
get_ips() {
  # 获取当前主机的主机名，例如：s12.serv00.com
  local hostname=$(hostname)

  # 从主机名中提取数字部分，例如：从 "s12.serv00.com" 中提取 "12"
  local host_number=$(echo "$hostname" | awk -F'[s.]' '{print $2}')

  # 根据主机名数字部分构造一个主机名
  local hosts="${host_number}.serv00.com"

  # 初始化一个数组来保存最终的 IP 地址
  local final_ips=()

  case $hosts in
    "0.serv00.com") final_ips=("128.204.218.63" "91.185.187.49" "128.204.218.48") ;;
    "1.serv00.com") final_ips=("213.189.54.126" "85.232.241.109" "31.186.83.254") ;;
    "2.serv00.com") final_ips=("128.204.223.47" "31.186.86.47" "128.204.223.46") ;;
    "3.serv00.com") final_ips=("128.204.223.71" "91.185.189.19" "128.204.223.70") ;;
    "4.serv00.com") final_ips=("128.204.223.95" "213.189.52.181" "128.204.223.94") ;;
    "5.serv00.com") final_ips=("128.204.223.99" "85.194.243.117" "128.204.223.98") ;;
    "6.serv00.com") final_ips=("128.204.223.101" "85.194.242.89" "128.204.223.100") ;;
    "7.serv00.com") final_ips=("128.204.223.120" "85.194.244.91" "128.204.223.119") ;;
    "8.serv00.com") final_ips=("128.204.223.114" "31.186.85.171" "128.204.223.113") ;;
    "9.serv00.com") final_ips=("128.204.223.116" "91.185.186.151" "128.204.223.115") ;;
    "10.serv00.com") final_ips=("128.204.223.112" "91.185.190.159" "128.204.223.111") ;;
    "11.serv00.com") final_ips=("128.204.223.118" "31.186.87.205" "128.204.223.117") ;;
    "12.serv00.com") final_ips=("85.194.246.115" "213.189.53.91" "85.194.246.69") ;;
    "13.serv00.com") final_ips=("128.204.223.43" "31.186.87.211" "128.204.223.42") ;;
    "14.serv00.com") final_ips=("188.68.240.161" "188.68.234.53" "188.68.240.160") ;;
    "15.serv00.com") final_ips=("188.68.250.202" "188.68.248.8" "188.68.250.201") ;;
    "16.serv00.com") final_ips=("207.180.248.7" "213.136.83.240" "207.180.248.6") ;;
    *) final_ips=("Domain not found") ;;
  esac

  # 输出 IP 地址数组
  echo "${final_ips[@]}"
}

# 函数：生成私钥和证书
make_pc() {
    local URL=$1
    # 创建私钥和证书
    if [[ ! -e "private.key" || ! -e "cert.pem" ]]; then
        openssl ecparam -genkey -name prime256v1 -out "private.key"
        openssl req -new -x509 -days 36500 -key "private.key" -out "cert.pem" -subj "/CN=${URL}"
    fi
}

# 统计当前端口数量并记录每个端口的类型和端口号
list_ports () {
    echo "列出当前端口..." | tee -a "$LOGFILE"
    echo "Num Type Port Description" | tee -a "$LOGFILE"
    i=1
    ports=$(devil port list 2>>"$LOGFILE" | tail -n +2 | awk '{if ($2 == "udp" || $2 == "tcp") print $1, $2, $3}' )
    num_ports=0
    while IFS= read -r line; do
        [[ $line =~ ^[0-9]+ ]] && echo "$i $line" | tee -a "$LOGFILE" && i=$((i+1)) && num_ports=$((num_ports+1))
    done <<< "$ports"
    echo "端口数量: $num_ports" | tee -a "$LOGFILE"
}

# 生成随机端口
generate_random_ports () {
    echo "生成随机端口..." | tee -a "$LOGFILE"
    # 循环生成端口
    for ((i=1; i<=$1; i++)); do 
      # 添加端口并获取端口号
      add_port udp "hy2-${i}"
      hy2_port=$(devil port list | grep -E '^[0-9]+[[:space:]]+[a-zA-Z]+' | sed 's/^[[:space:]]*//' | grep -i hy2-${i} | awk '{print $1}')
      # 输出生成的结果
      echo "生成第 $i 组节点: hy2-${i}"
      # 获取 IP 地址
      ips=($(get_ips))
      count_num=0
      for hy2_ip in "${ips[@]}"; do
        echo "The IP address is $hy2_ip"
        count_num=$((count_num+1))
        # 生成 UUID
        hy2_uuid=$(uuidgen -r)
        # 输出生成的结果
        echo "生成第 $count_num 个节点: hy2-${i}-${count_num}"
        echo "端口: ${hy2_port}, IP: ${hy2_ip}, UUID: ${hy2_uuid}"
        # 同时生成订阅
        hy2_client="hysteria2://${hy2_uuid}@${hy2_ip}:${hy2_port}?sni=${URL}&alpn=h3&insecure=1#hy2-in-$(hostname | sed 's;.serv00.com;;g')-${i}-${count_num}"
        # 生成 JSON 配置
        hy2_config=$(cat <<EOF
{
    "tag": "hy2-in-$(hostname | sed 's;.serv00.com;;g')-${i}-${count_num}",
    "type": "hysteria2",
    "listen": "${hy2_ip}",
    "listen_port": ${hy2_port},
    "users": [
    {
        "password": "${hy2_uuid}"
    }
    ],
    "masquerade": {
    "url": "https://${URL}",
    "type": "proxy"
    },
    "tls": {
    "enabled": true,
    "alpn": [
        "h3"
    ],
    "certificate_path": "${HOME}/s-h-f-serv00-${REPORT_DATE_S}/cert.pem",
    "key_path": "${HOME}/s-h-f-serv00-${REPORT_DATE_S}/private.key"
    }
}
EOF
)
        # 存储节点配置
        hy2_nodes+=("$hy2_config")
        hy2_clients+=("$hy2_client")
      done
    done
}

# 函数：添加端口
add_port() {
  local protocol=$1
  local description=$2

  # 验证协议类型
  if [[ "$protocol" != "udp" && "$protocol" != "tcp" ]]; then
    echo "[Error] Invalid port type. Please use 'udp' or 'tcp'."
    return 1
  fi

  # 如果端口不存在，尝试添加端口
  echo "生成随机端口协议: $protocol，描述: $description"
  result=$(devil port add "$protocol" random "$description" 2>&1)

  # 检查命令执行结果
  if [[ "$result" == *"Error"* ]]; then
    echo "[Error] $result"
    # 如果遇到端口限制错误，给出提示
    if [[ "$result" == *"Port limit exceeded"* ]]; then
      echo "[Error] 端口限制已达到，无法继续添加端口！"
    fi
    return 1
  else
    # 提取端口号
    local port=$(echo "$result" | awk -F ' ' '{print $5}')
    echo "[Ok] Port reserved successfully: $port"
    echo "$port"
  fi
}

# 删除用户选择的端口
delete_port () {
    echo "尝试删除端口..." | tee -a "$LOGFILE"
    ports=$(devil port list 2>>"$LOGFILE" | tail -n +2 | awk '{if ($2 == "udp" || $2 == "tcp") print $1, $2, $3}' )
    port_to_delete=$( echo "$ports" | sed -n "$1p" | awk '{print $1}' || true)
    if [[ -n "${port_to_delete:-}" ]]; then
        echo "将要删除的端口是：$port_to_delete" | tee -a "$LOGFILE"
        if devil port del udp "$port_to_delete" 2>>"$LOGFILE"; then
            echo "Port $port_to_delete has been removed successfully" | tee -a "$LOGFILE"
            return 0
        elif devil port del tcp "$port_to_delete" 2>>"$LOGFILE"; then
            echo "Port $port_to_delete has been removed successfully" | tee -a "$LOGFILE"
            return 0
        else
            echo "[Error] Failed to remove port $port_to_delete" | tee -a "$LOGFILE"
            return 1
        fi
    else
        echo "[Error] Invalid port number" | tee -a "$LOGFILE"
        return 1
    fi
}

# 函数：尝试获取网页内容，最多重试5次
fetchPageContent() {
    local GITHUB_URI=$1
    local PAGE_CONTENT=""
    for i in {1..5}; do
        PAGE_CONTENT=$(curl -sL ${GITHUB_URI})
        if [ -n "${PAGE_CONTENT}" ]; then
            break
        fi
        echo "尝试获取网页内容失败，重试第 $i 次..."
        sleep 2
    done
    echo "${PAGE_CONTENT}"
}

# 函数：确保成功获取到网页内容
ensurePageContent() {
    local PAGE_CONTENT=$1
    if [ -z "${PAGE_CONTENT}" ]; then
        echo "无法获取网页内容，请稍后再试。"
        exit 1
    fi
}

# 下载 sing-box-freebsd 配置并启用
downloadAndBuild() {
    local URI=$1
    local GITHUB_URI="https://github.com/${URI}"
    local TAG_URI="/${URI}/releases/tag/"

    PAGE_CONTENT=$(fetchPageContent ${GITHUB_URI}/releases)
    ensurePageContent "${PAGE_CONTENT}"

    # 提取最新版本号
    VERSION=$(echo "${PAGE_CONTENT}" | grep -o "href=\"${TAG_URI}[^\"]*" | head -n 1 | sed "s;href=\"${TAG_URI};;" | sed 's/\"//g')
    echo ${VERSION}

    # 下载并编译
    FILENAME=$(basename ${GITHUB_URI})
    FULL_URL=${GITHUB_URI}/archive/refs/tags/${VERSION}.tar.gz
    echo "${FULL_URL}"
    
    # 确保下载链接存在
    if [ -z "${FULL_URL}" ]; then
        echo "无法找到匹配的下载链接，请稍后再试。"
        exit 1
    fi
    
    wget -t 3 -T 10 --verbose --show-progress=on --progress=bar --no-check-certificate --hsts-file=/tmp/wget-hsts -c "${FULL_URL}" -O ${FILENAME}.tar.gz
    tar zxf ${FILENAME}.tar.gz
    cd ${FILENAME}-${VERSION#v}
    go build -tags with_quic ./cmd/${FILENAME}
    mv -fv ./${FILENAME} ${HOME}/s-h-f-serv00-${REPORT_DATE_S}/${FILENAME}-$(uname -s | tr A-Z a-z)
    chmod -v u+x ${HOME}/s-h-f-serv00-${REPORT_DATE_S}/${FILENAME}-$(uname -s | tr A-Z a-z)
    cd -
    rm -rf ${FILENAME}.tar.gz ${FILENAME}-${VERSION#v}
}

# 方案2 直接下载 非官方 sing-box 的 freebsd 编译成品，我本来是担心风险的，但是现在来看不得不用了
downloadAndExtract() {
    local URI=$1
    local APPNAME=$2
    local GITHUB_URI="https://github.com/${URI}"
    local TAG_URI="/${URI}/releases/tag/"

    PAGE_CONTENT=$(fetchPageContent ${GITHUB_URI}/releases)
    ensurePageContent "${PAGE_CONTENT}"

    # 提取最新版本号
    VERSION=$(echo "${PAGE_CONTENT}" | grep -o "href=\"${TAG_URI}[^\"]*" | head -n 1 | sed "s;href=\"${TAG_URI};;" | sed 's/\"//g')
    echo ${VERSION}

    # 下载并编译
    FILENAME=$(basename ${GITHUB_URI})
    #FULL_URL=${GITHUB_URI}/releases/download/${VERSION}/${APPNAME}-$(uname -s | tr A-Z a-z)-$(uname -m)
    FULL_URL=${GITHUB_URI}/releases/download/${VERSION}/${FILENAME}-$(uname -m)
    echo "${FULL_URL}"
    
    # 确保下载链接存在
    if [ -z "${FULL_URL}" ]; then
        echo "无法找到匹配的下载链接，请稍后再试。"
        exit 1
    fi

    # 下载并解压
    wget -t 3 -T 10 --verbose --show-progress=on --progress=bar --no-check-certificate --hsts-file=/tmp/wget-hsts -c "${FULL_URL}" -O ${HOME}/s-h-f-serv00-${REPORT_DATE_S}/${APPNAME}-$(uname -s | tr A-Z a-z)
    chmod -v u+x ${HOME}/s-h-f-serv00-${REPORT_DATE_S}/${APPNAME}-$(uname -s | tr A-Z a-z)
}

make_restart() {
    # 写入重启脚本
    cat <<20241204 | tee restart.sh >/dev/null
# kill -9 \$(ps | grep -v grep | grep sing-box-freebsd | awk '{print \$1}')
pkill sing-box-freebsd &
sleep 3
nohup ${HOME}/s-h-f-serv00-${REPORT_DATE_S}/sing-box-freebsd run -c ${HOME}/s-h-f-serv00-${REPORT_DATE_S}/config.json > ${HOME}/s-h-f-serv00-${REPORT_DATE_S}/sing-box-freebsd.log 2>&1 & disown
20241204

    # 本机 DOMAIN
    HOSTNAME_DOMAIN="$(hostname)"
    USERNAME="$(whoami)"

    # 起始时间+6h
    #F_DATE="$(date -d '${REPORT_DATE}' --date='6 hour' +'%Y-%m-%d %T')"
    # 脚本结束时间
    F_DATE="$(TZ=':Asia/Shanghai' date +'%Y-%m-%d %T')"
    F_DATE_S="$(TZ=':Asia/Shanghai' date +%s)"
    # 写入 crontab 自动化，应对服务器自动重启

    cat <<20241204 | tee crontab >/dev/null
@reboot cd ${HOME}/s-h-f-serv00-${REPORT_DATE_S} ; bash restart.sh
$(crontab -l | sed '/s-h-f-serv00.sh/d' | sed "\|@reboot cd ${HOME}/s-h-f-serv00-.* ; bash restart.sh|d")
20241204
    crontab crontab
    rm -fv crontab

    # 检查写入之后的 crontab
    echo '写入之后的 crontab'
    crontab -l

    # 写入 result.txt 字符画
    cat <<'20241204' | tee result.txt >/dev/null
# ---------------------------------

 .-.  .-.  .-. .  .  .   .-.  .-. .  . 
(   ):   :(   )|  |.'|  (   ):   :|  | 
  .' |   |  .' '--|- |    .' |   |'--|-
 /   :   ; /      |  |   /   :   ;   | 
'---' `-' '---'   ''---''---' `-'    ' 
                                            
        |       ,---.                        ,--.,--.
,---.   |---.   |__.    ,---.,---.,---..    ,|  ||  |
`---.---|   |---|    ---`---.|---'|     \  / |  ||  |
`---'   `   '   `       `---'`---'`      `'  `--'`--'
                                                     
# --------------------------------thin

20241204
    # 写入 result.txt
    cat <<20241204 | tee -a result.txt >/dev/null
    ！！！！！！！！！！！！注意！！！！！！！！！！！！！！！
    # 有时候？忽然连不上了
    # 执行以下命令查看进程是否启动？
    # sing-box-freebsd 进程
    ps | grep -v grep | grep sing-box-freebsd
    
    # 查看一下日志是否有可用信息？
    # sing-box-freebsd 日志
    tail -f -n 200 ${HOME}/s-h-f-serv00-*/sing-box-freebsd.log
    
    # 如果一切正常有可能 serv00 服务器重新启动了导致 uuid 自动改变了
    # 可以执行以下命令查看重启后新生成的配置文件信息
    cat ${HOME}/s-h-f-serv00-*/result.txt
    
    # 当然也有进程停止了，那就借用已经存在的文件启动试试重启脚本吧？
    bash ${HOME}/s-h-f-serv00-${REPORT_DATE_S}/restart.sh

    # 什么还是不行，那就手动重启脚本，再重新编译二进制文件启动吧！！！
    bash s-h-f-serv00.sh
    
    # 啊？什么什么还是不行？啊好烦啊，唉，我尽力了。。。
    ！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！

# 节点信息如下：

20241204
}

# 神秘的分割线
echo "=========================================="
echo 本脚本会根据用户删除端口个数开通1~3个UDP端口，如果有需求，可以自己爆改

# 自杀
killMe

# 清理端口
#clear_port

# 创建私钥和证书
make_pc $URL

# 脚本主体
echo "脚本开始执行..." | tee -a "$LOGFILE"
count=0
list_ports
echo "当前端口数量: $num_ports" | tee -a "$LOGFILE"
if [ "$num_ports" -lt 3 ]; then
    count=$((3-num_ports))
    echo "生成 $count 个随机端口..." | tee -a "$LOGFILE"
    generate_random_ports "$count"
else
    while true; do
        list_ports
        read -p "当前可能有多个端口，你可以选择要删除的条目，请输入要删除的端口编号（输入y完成操作，ctrl+c退出脚本）： " num
        if [[ $num =~ ^[0-9]+$ ]]; then
            if delete_port "$num"; then
                count=$((count+1))
            fi
        elif [[ $num == "y" ]]; then
            break
        else
            echo "无效输入，请输入端口编号或y"
        fi
    done
    # 根据删除的次数生成随机端口
    echo "生成 $count 个随机端口..." | tee -a "$LOGFILE"
    generate_random_ports "$count"
fi

echo "共生成了 $count 个随机端口" | tee -a "$LOGFILE"
list_ports
echo "脚本执行完成。" | tee -a "$LOGFILE"

# 拼接多个节点配置并生成 config.json
inbounds=$(printf ",\n%s" "${hy2_nodes[@]}")
inbounds="${inbounds:2}"  # 去除前面的逗号
inbounds="${inbounds:2}"  # 去除前面的逗号
# 同时为订阅节点添加换行
inbounds_clients=$(printf "\n%s" "${hy2_clients[@]}")

  cat > config.json <<EOF
{
  "log": {
    "disabled": true,
    "level": "debug",
    "timestamp": true
  },
  "dns": {
    "servers": [
      {
        "tag": "google",
        "address": "tls://8.8.8.8",
        "strategy": "ipv4_only",
        "detour": "direct"
      }
    ],
    "final": "google",
    "strategy": "",
    "disable_cache": false,
    "disable_expire": false
  },
  "inbounds": [
    ${inbounds}
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    }
  ],
  "route": {
    "rules": [
      {
        "protocol": "dns",
        "action": "hijack-dns"
      },
      {
        "ip_is_private": true,
        "outbound": "direct"
      }
    ],
    "final": "direct"
  }
}
EOF

echo "config.json 文件已生成！"

# 本地 go 构建 sing-box
#downloadAndBuild "SagerNet/sing-box"

# 方案2 直接下载 非官方 sing-box freebsd 编译成品，我本来是担心风险的，但是现在来看不得不用了
downloadAndExtract "20241204/sing-box-freebsd" "sing-box"

make_restart
nohup ./sing-box-freebsd run -c ./config.json > ./sing-box-freebsd.log 2>&1 & disown
echo '运行开始'
echo "节点已经生成！"
cat <<EOF >> result.txt
${inbounds_clients} 

# 本脚本执行耗时:
"$REPORT_DATE ---> $F_DATE" "Total:$[ $F_DATE_S - $REPORT_DATE_S ] seconds"
EOF
cat result.txt
