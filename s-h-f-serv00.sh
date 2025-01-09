#!/usr/bin/env bash
set -e
set -u
# 起始时间
REPORT_DATE="$(TZ=':Asia/Shanghai' date +'%Y-%m-%d %T')"
REPORT_DATE_S="$(TZ=':Asia/Shanghai' date +%s)"

make_restart() {
    # 写入重启脚本
    cat <<20241204 | tee restart.sh >/dev/null
# kill -9 \$(ps | grep -v grep | grep sing-box-freebsd | awk '{print \$1}')
pkill sing-box-freebsd &
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
                ,---.                        ,--.,--.            
,---.   ,---.   |__.    ,---.,---.,---..    ,|  ||  |            
`---.---|    ---|    ---`---.|---'|     \  / |  ||  |            
`---'   `---'   `       `---'`---'`      `'  `--'`--'            

# --------------------------------

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

# 函数：生成私钥和证书
make_pc() {
    local URL=$1
    # 创建私钥和证书
    if [[ ! -e "private.key" || ! -e "cert.pem" ]]; then
        openssl ecparam -genkey -name prime256v1 -out "private.key"
        openssl req -new -x509 -days 36500 -key "private.key" -out "cert.pem" -subj "/CN=${URL}"
    fi
}

# 函数：获取可用的 IP 地址
get_ip() {
  # 获取当前主机的主机名，例如：s12.serv00.com
  local hostname=$(hostname)

  # 从主机名中提取数字部分，例如：从 "s12.serv00.com" 中提取 "12"
  local host_number=$(echo "$hostname" | awk -F'[s.]' '{print $2}')

  # 根据主机名数字部分构造一个主机名
  local hosts="web${host_number}.serv00.com"

  # 初始化一个空变量来保存最终的 IP 地址
  local final_ip=""

  case $hosts in
    "web0.serv00.com") final_ip="128.204.218.48" ;;
    "web1.serv00.com") final_ip="31.186.83.254" ;;
    "web2.serv00.com") final_ip="128.204.223.46" ;;
    "web3.serv00.com") final_ip="128.204.223.70" ;;
    "web4.serv00.com") final_ip="128.204.223.94" ;;
    "web5.serv00.com") final_ip="128.204.223.98" ;;
    "web6.serv00.com") final_ip="128.204.223.100" ;;
    "web7.serv00.com") final_ip="128.204.223.119" ;;
    "web8.serv00.com") final_ip="128.204.223.113" ;;
    "web9.serv00.com") final_ip="128.204.223.115" ;;
    "web10.serv00.com") final_ip="128.204.223.111" ;;
    "web11.serv00.com") final_ip="128.204.223.117" ;;
    "web12.serv00.com") final_ip="85.194.246.69" ;;
    "web13.serv00.com") final_ip="128.204.223.42" ;;
    "web14.serv00.com") final_ip="188.68.240.160" ;;
    "web15.serv00.com") final_ip="188.68.250.201" ;;
    "web16.serv00.com") final_ip="207.180.248.6" ;;
    "web17.serv00.com") final_ip="128.204.218.63" ;;
    *) final_ip="Domain not found" ;;
  esac

  # 输出 IP 地址
  echo "$final_ip"
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
    chmod -v u+x ${FILENAME}-$(uname -s | tr A-Z a-z)
    cd -
    rm -rf ${FILENAME}.tar.gz ${FILENAME}-${VERSION#v}
}

# 神秘的分割线
echo "=========================================="
echo 本脚本会根据用户输入端口个数开通1~3个UDP端口，如果有需求，可以自己爆改

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

# 自杀
killMe

# 清理端口
clear_port

# 获取 IP 地址
hy2_ip=$(get_ip)
echo "The IP address is $hy2_ip"

hy2_nodes=""
hy2_clients=""
URL="www.bing.com"

# 创建私钥和证书
make_pc $URL

# 获取用户输入的要生成的 hy2 节点个数
read -p "请输入要生成的hy2节点个数：" hy2_num
# 循环生成端口
for ((i=1; i<=hy2_num; i++)); do 
  # 添加端口并获取端口号
  add_port udp "hy2-${i}"
  hy2_port=$(devil port list | grep -E '^[0-9]+[[:space:]]+[a-zA-Z]+' | sed 's/^[[:space:]]*//' | grep -i hy2-${i} | awk '{print $1}')

  # 生成 UUID
  hy2_uuid=$(uuidgen -r)

  # 输出生成的结果
  echo "生成第 $i 个节点: hy2-${i}"
  echo "端口: ${hy2_port}, IP: ${hy2_ip}, UUID: ${hy2_uuid}"

  # 同时生成订阅
  hy2_client="hysteria2://${hy2_uuid}@${hy2_ip}:${hy2_port}?sni=${URL}&alpn=h3&insecure=1#hy2-in-$(hostname | sed 's;.serv00.com;;g')-${i}"

  # 生成 JSON 配置
  hy2_config=$(cat <<EOF
{
    "tag": "hy2-in-$(hostname | sed 's;.serv00.com;;g')-${i}",
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
    "certificate_path": "cert.pem",
    "key_path": "private.key"
    }
}
EOF
)
  # 存储节点配置
  hy2_nodes+=("$hy2_config")
  hy2_clients+=("$hy2_client")

done

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
downloadAndBuild "SagerNet/sing-box"

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
