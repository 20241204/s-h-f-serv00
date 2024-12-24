# s-h-f-serv00
sing-box + hysteria2 + freebsd 支持在 serv00 上搭建 3 个 hysteria2 节点

![Watchers](https://img.shields.io/github/watchers/20241204/s-h-f-serv00) ![Stars](https://img.shields.io/github/stars/20241204/s-h-f-serv00) ![Forks](https://img.shields.io/github/forks/20241204/s-h-f-serv00) ![Vistors](https://visitor-badge.laobi.icu/badge?page_id=20241204.s-h-f-serv00) ![LICENSE](https://img.shields.io/badge/license-CC%20BY--SA%204.0-green.svg)
<a href="https://star-history.com/#20241204/s-h-f-serv00&Date">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=20241204/s-h-f-serv00&type=Date&theme=dark" />
    <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=20241204/s-h-f-serv00&type=Date" />
    <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=20241204/s-h-f-serv00&type=Date" />
  </picture>
</a>  


# 描述
> 由于 cloudflare 不想再用爱发电，我感到万分悲痛，所以开发测试了一下此脚本，可能没什么用，不过，先随便写写先留个备份，我该睡一会儿了，等我醒来，再说

# 下载本脚本到 serv00 服务器
    # -1.登录 serv00 服务器并执行命令下载脚本到 serv00 服务器
    rm -fv ${HOME}/s-h-f-serv00.sh
    wget -t 3 -T 10 --verbose --show-progress=on --progress=bar --no-check-certificate --hsts-file=/tmp/wget-hsts -c \
                          "https://raw.githubusercontent.com/20241204/s-h-f-serv00/master/s-h-f-serv00.sh" \
                          -O ${HOME}/s-h-f-serv00.sh
    bash ${HOME}/s-h-f-serv00.sh

![image](https://github.com/user-attachments/assets/63bfd760-c700-4f5a-8d16-3362bf92bd28)
![image](https://github.com/user-attachments/assets/f8ed787f-0527-421e-9c0e-493c3ba74349)


# 注意
> 此脚本会清除 serv00 上的全部端口，并按照用户输入的生成 hy2 个数生成全新的 udp 端口
> 由于端口限制你最多只能生成3个节点，这只是个测试脚本，写的很low，你可以魔改爆改本脚本


# 声明
此脚本仅用于学习测试，使用本脚本有什么后果，我没能力负责，真出了什么事请饶过我好吗，我就是个臭写脚本的，而且我过的也不太好，唉
