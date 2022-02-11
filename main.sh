#!/bin/bash

Verison="Beta 0.2"

[[ $EUID -ne 0 ]] && echo "请在root用户下运行脚本" && exit 0

menu(){
    
    clear
    echo "1. 安装CloudFlare Argo Tunnel"
    echo "2. 登录CloudFlare账户"
    echo "3. 创建一条隧道"
    echo "4. 绑定子域名到隧道"
    echo "5. 列出所有隧道"
    echo "6. 删除隧道"
    echo "7. 开启隧道"
    echo "8. 关闭隧道"
    echo "9. 卸载CloudFlare Argo Tunnel(没做呢)"
    echo "10. 配置到systemctl中"
    echo "11. 创建config.yml配置文件"
    echo "0. 退出脚本"
    read -p "请输入选项：" numberInput
    case ${numberInput} in
        1) tunnelInstall ;;
        2) tunnelLogin ;;
        3) tunnelCreate ;;
        4) tunnelRoute ;;
        5) tunnelList ;;
        6) tunnelDelete ;;
        7) tunnelStart ;;
        8) tunnelStop ;;
        9) tunnelUninstall ;;
        10) serviceAdd ;;
        11) tunnelConfig ;;
        0) exit 0
    esac
}

checkInstall(){
    if [[ -z $(which cloudflared 2> /dev/null) ]]; then
        echo "【错误】未安装CloudFlare Argo Tunnel客户端，请先安装客户端"
        exit 0
    fi
}

checkLogin(){
    if [ -f "/root/.cloudflared/cert.pem" ]; then
        echo ""
    else
        echo "【错误】未登录"
        exit 0
    fi
}

checkService(){
    if [[ ! $(systemctl status cloudflared 2> /dev/null) ]]; then
        echo "【错误】未配置到服务，请配置到systenctl中"
        exit 0
    fi
}

errorCatch(){
    echo "【错误】请将该页面所有内容截图并发送给作者 ErrorCode:$1"
    exit 0
}

x86_64='x86_64'


tunnelInstall(){
    if [[ -n $(which cloudflared 2> /dev/null) ]]; then
        echo "【验证】已经安装CloudFlare Argo Tunnel客户端了，无需重复安装"
    else
        getArch=$(uname -m) #检查系统架构
        if [ -f "/usr/bin/apt-get" ]; then
            if [ ${getArch} = ${x86_64} ]; then
                arch='amd64'
            else
                arch=${getArch}
            fi
            apt-get install curl
            wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${arch}.deb
            dpkg -i cloudflared-linux-${arch}.deb
        elif [ -f "/usr/bin/dnf" ]; then
            if [ ${getArch} == ${x86_64} ]; then
                arch='amd64'
            else
                arch=${getArch}
            fi
            yum install curl
            wget -N https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${arch}.rpm
            rpm -i cloudflared-linux-${arch}.rpm
        elif [ -f "/usr/bin/yum" ]; then
            if [ ${getArch} == ${x86_64} ]; then
                arch='amd64'
            else
                arch=${getArch}
            fi
            yum install curl
            wget -N https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${arch}.rpm
            rpm -i cloudflared-linux-${arch}.rpm
        fi
    fi
    tunnelLogin
    tunnelCreate
    tunnelRoute
    tunnelConfig
    serviceAdd
}

tunnelLogin(){
    checkInstall
    echo '==========%登录%=========='
    echo "打开链接，登录到Cloudflare，确保账户下有一个或多个域名"
    cloudflared tunnel login || errorCatch 101
    checkLogin
    echo '==========%结束%=========='
}

tunnelCreate(){
    checkInstall
    checkLogin
    echo '==========%创建%=========='
    read -p ">_输入隧道名称：" tunnelName
    cloudflared tunnel create ${tunnelName} || errorCatch 201
    echo '==========%结束%=========='
}

tunnelRoute(){
    checkInstall
    checkLogin
    tunnelList
    echo '==========%绑定%=========='
    read -p ">_输入隧道名称：" tunnelName
    read -p ">_完整输入想要绑定的域名：" tunnelDomain
    cloudflared tunnel route dns ${tunnelName} ${tunnelDomain} || errorCatch 301
    echo '==========%结束%=========='
}

tunnelConfig(){
    checkInstall
    checkLogin
    tunnelList
    echo '==========%配置%=========='
    read -p ">_输入隧道名称：" tunnelName
    read -p ">_完整输入隧道域名：" tunnelDomain
    read -p ">_输入隧道ID：" tunnelID
    read -p ">_输入协议名称（http;https;unix;tcp;ssh;rdp;bastion）：" tunnelService
    read -p ">_输入想要Tunnel代理的端口：" tunnelPort
    echo "正在写入文件中，请稍后。。。"
    echo "tunnel: ${tunnelID}" > ~/.cloudflared/config.yml || errorCatch 401
    echo "credentials-file: /root/.cloudflared/${tunnelID}.json" >> ~/.cloudflared/config.yml
    echo "ingress:" >> ~/.cloudflared/config.yml
    echo "  - hostname: ${tunnelDomain}" >> ~/.cloudflared/config.yml
    echo "    service: $tunnelService://localhost:${tunnelPort}" >> ~/.cloudflared/config.yml
    echo "  - service: http_status:404" >> ~/.cloudflared/config.yml
    echo '==========%结束%=========='
}

serviceAdd(){
    checkInstall
    checkLogin
    echo '==========%服务%=========='
    echo "添加cloudflared到service中（脚本运行所需）"
    cloudflared service install || errorCatch 501
    systemctl start cloudflared || errorCatch 502
    systemctl enable cloudflared || errorCatch 503
    checkService
    echo '==========%结束%=========='
}

tunnelStart(){
    checkInstall
    checkLogin
    checkService
    echo '==========%启动%=========='
    systemctl start cloudflared || errorCatch 601
    systemctl status cloudflared || errorCatch 602
    echo '==========%结束%=========='
}

tunnelStop(){
    checkInstall
    checkLogin
    tunnelList
    echo '==========%停止%=========='
    systemctl start cloudflared || errorCatch 602
    echo '==========%结束%=========='
}

tunnelList(){
    checkInstall
    checkLogin
    echo '==========%列表%=========='
    cloudflared tunnel list || errorCatch 701
    echo '==========%结束%=========='
}

tunnelDelete(){
    checkInstall
    checkLogin
    tunnelList
    echo '==========%删除%=========='
    read -p "输入隧道名称：" tunnelName
    cloudflared tunnel delete -f ${tunnelName} || errorCatch 801
    echo '==========%结束%=========='
}


menu
