#!/bin/bash
set -ex

# 获取系统架构并设置 OS_ARCH 参数
OS_ARCH=$(arch)

WORKSPACE=/opt/ServerStatus
mkdir -p ${WORKSPACE}
cd ${WORKSPACE}

apt update && apt install -y curl wget unzip

# 获取最新版本号
latest_version=$(curl -m 10 -sL "https://api.github.com/repos/zdz/ServerStatus-Rust/releases/latest" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')

# 下载并解压客户端文件
wget --no-check-certificate -qO "client-${OS_ARCH}-unknown-linux-musl.zip" "https://github.com/zdz/ServerStatus-Rust/releases/download/${latest_version}/client-${OS_ARCH}-unknown-linux-musl.zip"

unzip -o "client-${OS_ARCH}-unknown-linux-musl.zip"

# 移动服务文件到 systemd 目录
mv -v stat_client.service /etc/systemd/system/stat_client.service

# 判断虚拟化
if [ -x "$(type -p systemd-detect-virt)" ]; then
    VIRT=$(systemd-detect-virt)
elif [ -x "$(type -p hostnamectl)" ]; then
    VIRT=$(hostnamectl | awk '/Virtualization/{print $NF}')
elif [ -x "$(type -p virt-what)" ]; then
    VIRT=$(virt-what)
else
    VIRT="Unknown"
fi

# 询问服务器的主机名和所在地
read -p "请输入服务器的主机名: " SERVER_ALIAS
read -p "请输入服务器的所在地(国家简码 例如cn): " SERVER_LOCATION

# 创建 stat_client.service 文件内容
cat <<EOL > /etc/systemd/system/stat_client.service
[Unit]
Description=ServerStatus-Rust Client
After=network.target

[Service]
User=root
Group=root
Environment="RUST_BACKTRACE=1"
WorkingDirectory=/opt/ServerStatus
# EnvironmentFile=/opt/ServerStatus/.env
ExecStart=/opt/ServerStatus/stat_client -a https://tz.restia.site/report -g vps -p restia --type $VIRT --alias $SERVER_ALIAS --location $SERVER_LOCATION
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOL

# 重载 systemd 配置并启动服务
systemctl daemon-reload
systemctl start stat_client
systemctl enable stat_client
systemctl status stat_client
