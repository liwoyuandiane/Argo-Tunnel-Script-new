#!/bin/bash

Verison="Beta 0.2"

#判定是否为root运行
[[ $EUID -ne 0 ]] && "请在root用户下运行脚本" && exit 1

#主菜单
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
        0) exit 0
    esac
}

#检查是否安装，False则关闭程序并要求安装
checkInstall(){
    if [[ -n $(which cloudflared 2> /dev/null) ]]; then #检测是否存在cloudflared指令，指令存在的位置
        echo "已安装CloudFlare Argo Tunnel客户端，无需重复安装"
        exit 0
    else
        echo "未安装CloudFlare Argo Tunnel客户端，请先安装客户端"
        exit 0
    fi
}

checkLogin(){
    if [ -f "/root/.cloudflared/cert.pem" ]; then
        #
    else
        echo "未登录，请先登录"
        exit 0
    fi
}

checkService(){
    if [[ ! $(systemctl status cloudflared 2> /dev/null) ]]; then
        echo "未配置到服务，请配置到systenctl中"
        exit 0
    fi
}

#错误捕捉
#错误代码表
#登陆相关 101
errorCatch(ErrorCode){
    echo "发生错误，请将该页面所有内容截图并发送给作者 ErrorCode:$1"
}

#安装流程
tunnelInstall(){
    checkInstall
    getArch=$(uname -m) #检查系统架构
    if [ -f "/usr/bin/apt-get" ]; then
        if [${getArch} = "x86_64"]; then
            arch="amd64"
        else
            arch=${getArch}
        fi
        wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${arch}.deb
        dpkg -i cloudflared-linux-${arch}.deb
    elif [ -f "/usr/bin/dnf" ]; then
        if [${getArch} = "x86_64"]; then
            arch="amd64"
        else
            arch=${getArch}
        fi
        wget -N https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${arch}.rpm
        rpm -i cloudflared-linux-${arch}.rpm
    elif [ -f "/usr/bin/yum" ]; then
        if [${getArch} = "x86_64"]; then
            arch="amd64"
        else
            arch=${getArch}
        fi
        wget -N https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${arch}.rpm
        rpm -i cloudflared-linux-${arch}.rpm
    fi
    tunnelLogin
    tunnelCreate
    tunnelRoute
    tunnelConfig
    serviceAdd
}


tunnelLogin(){
    checkInstall
    echo "【登录】"
    echo "打开链接，登录到Cloudflare，确保账户下有一个或多个域名"
    cloudflared tunnel login || errorCatch 101
}

tunnelCreate(){
    checkInstall
    checkLogin
    echo "【创建隧道】"
    read -p "输入隧道名称（非中文）：" tunnelName
    cloudflared tunnel create ${tunnelName} || errorCatch 201
    echo "手动保存隧道名称和隧道ID，脚本不做记录"
}

tunnelRoute(){
    checkInstall
    checkLogin
    echo "【绑定隧道到域名】"
    read -p "输入创建好的隧道名称（非中文）：" tunnelName
    read -p "输入想要绑定的域名或子域名（未被其他记录占用）：" tunnelDomain
    cloudflared tunnel route dns ${tunnelName} ${tunnelDomain} || errorCatch 301
}


tunnelConfig(){
    checkInstall
    checkLogin
    tunnelList
    read -p "输入上面创建好的隧道ID（不要有异常字符）：" tunnelID
    read -p "输入上面创建好的隧道名称：" tunnelName
    read -p "输入上面创建好的隧道域名：" tunnelDomain
    read -p "输入想要创建的协议名称（http;https;unix;tcp;ssh;rdp;bastion）：" tunnelService
    read -P "输入开启的端口：" tunnelPort
    echo "正在写入文件中，请稍后。。。"
    echo "tunnel: ${tunnelID}" > /root/.cloudflared/${tunnelID}.json || errorCatch 401
    echo "credentials-file: /root/.cloudflared/${tunnelID}.json" >> /root/.cloudflared/${tunnelID}.json
    echo "ingress:" >> /root/.cloudflared/${tunnelID}.json
    echo "  - hostname" >> /root/.cloudflared/${tunnelID}.json
    echo "    serivce: $tunnelService://localhost:${tunnelPort}" >> /root/.cloudflared/${tunnelID}.json
    echo "  - service: http_status:404" >> /root/.cloudflared/${tunnelID}.json
}

serviceAdd(){
    checkInstall
    checkLogin
    echo "添加cloudflared到service中（脚本运行所需）"
    cloudflared service install || errorCatch 501
    systemctl start cloudflared || errorCatch 502
    systemctl enable cloudflared || errorCatch 503
}

tunnelStart(){
    checkInstall
    checkLogin
    checkService
    systemctl start cloudflared || errorCatch 601
}

tunnelStop(){
    checkInstall
    checkLogin
    tunnelList
    systemctl start cloudflared || errorCatch 602
}

tunnelList(){
    checkInstall
    checkLogin
    echo "【列出所有隧道】"
    cloudflared tunnel list || errorCatch 701
}

tunnelDelete(){
    checkInstall
    checkLogin
    tunnelList
    echo "【删除特定隧道 无法恢复】"
    read -p "输入要删除的隧道名称：" tunnelName
    cloudflared tunnel delete -f ${tunnelName} || errorCatch 801
}


menu