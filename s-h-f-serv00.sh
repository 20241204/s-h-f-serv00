#!/bin/bash

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
    # 创建私钥和证书
    if [[ ! -e "private.key" || ! -e "cert.pem" ]]; then
        openssl ecparam -genkey -name prime256v1 -out "private.key"
        openssl req -new -x509 -days 36500 -key "private.key" -out "cert.pem" -subj "/CN=www.bing.com"
    fi
}

# 函数：获取可用的 IP 地址
get_ip() {
  # 获取当前主机的主机名，例如：s12.serv00.com
  local hostname=$(hostname)

  # 从主机名中提取数字部分，例如：从 "s12.serv00.com" 中提取 "12"
  local host_number=$(echo "$hostname" | awk -F'[s.]' '{print $2}')

  # 根据主机名数字部分构造一个主机名列表
  local hosts=("web${host_number}.serv00.com" "cache${host_number}.serv00.com" "$hostname")

  # 初始化一个空变量来保存最终的 IP 地址
  local final_ip=""

  # 遍历构造的主机名列表，依次尝试获取 IP
  for host in "${hosts[@]}"; do
    # 通过 API 获取主机的 IP 信息
    local response=$(curl -s "https://ss.botai.us.kg/api/getip?host=$host")

    # 如果返回的结果包含 "not found"，则跳过当前主机名
    if [[ "$response" =~ "not found" ]]; then
      continue
    fi

    # 从返回的数据中提取 IP 地址（第一个字段），并检查其第二个字段是否为 "Accessible"
    local ip=$(echo "$response" | awk -F "|" '{ if ($2 == "Accessible") print $1 }')

    # 如果 IP 是 "Accessible"，则输出该 IP 地址并返回
    if [[ -n "$ip" ]]; then
      echo "$ip"
      return
    fi

    # 如果 IP 不是 "Accessible"，直接输出 "web${host_number}.serv00.com"
    final_ip="web${host_number}.serv00.com"
  done

  # 如果遍历完所有主机名后仍未找到 "Accessible" IP，输出最后一个找到的 IP
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
    mv -fv ./${FILENAME} ${HOME}/${FILENAME}-$(uname -s | tr A-Z a-z)
    chmod -v u+x ${HOME}/${FILENAME}-$(uname -s | tr A-Z a-z)
    cd -
    rm -rf ${FILENAME}.tar.gz ${FILENAME}-${VERSION#v}
}

# 自杀
killMe

# 清理端口
clear_port

# 创建私钥和证书
make_pc

# 获取 IP 地址
hy2_ip=$(get_ip)

hy2_nodes=""
hy2_clients=""
URL="www.bing.com"
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
    "rules": [
      {
        "rule_set": [
          "geosite-category-ads-all"
        ],
        "server": "block"
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
      },
      {
        "rule_set": [
          "geosite-category-ads-all"
        ],
        "action": "reject"
      }
    ],
    "rule_set": [
      {
        "tag": "geosite-category-ads-all",
        "type": "remote",
        "format": "binary",
        "url": "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-category-ads-all.srs",
        "download_detour": "direct"
      }
    ],
    "final": "direct"
  }
}
EOF

echo "config.json 文件已生成！"
echo "节点已经生成！"
cat <<EOF > clients.txt 
${inbounds_clients} 
EOF
cat clients.txt 
# 本地 go 构建 sing-box
downloadAndBuild "SagerNet/sing-box"

nohup $HOME/sing-box-freebsd run -c ./config.json > $HOME/sing-box-freebsd.log 2>&1 & disown
echo '运行开始'
  


