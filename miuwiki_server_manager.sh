#!/bin/bash

#基础设置---------------------------------
#config 位置
g_config_floder="./miuwiki_server_manager.conf"
g_update_floder="./miuwiki_server_update.conf"
#Steam CMD 位置
g_steamcmd_floder="./Steam/steamcmd.sh"
#服务器状态
g_array_name=()
g_array_ip=()
g_array_port=()
g_array_cmd=()
g_array_folder=()
g_array_status=()


#Install 设置变量
g_install_server=()
#网站
g_mmsource="https://mms.alliedmods.net/mmsdrop/1.11/mmsource-1.11.0-git1148-linux.tar.gz"
g_sourcemod="https://sm.alliedmods.net/smdrop/1.11/sourcemod-1.11.0-git6931-linux.tar.gz"
g_tickrate="https://github.com/accelerator74/Tickrate-Enabler/releases/download/build/Tickrate-Enabler-l4d2-def3795.zip"
g_l4dtoolz="https://github.com/accelerator74/l4dtoolz/releases/download/1.1.0.2/L4DToolZ-l4d2-bd0e49f.zip"
#镜像kgithub
g_tickrate_img="https://kgithub.com/accelerator74/Tickrate-Enabler/releases/download/build/Tickrate-Enabler-l4d2-def3795.zip"
g_l4dtoolz_img="https://kgithub.com/accelerator74/l4dtoolz/releases/download/1.1.0.2/L4DToolZ-l4d2-bd0e49f.zip"



# #颜色代码
skyblue="\033[36m"
normal_font="\033[0m"
green_font="\033[32m" 
red_font="\033[31m"

#标识符
working="[*]"
choose="[-]"
err="${red_font}[x]${normal_font}"
success="${green_font}[ok]${normal_font}"
# Green_background_prefix="\033[42;37m"
# Red_background_prefix="\033[41;37m" 

# #echo -e "\033[30m 黑色字 \033[0m"
# #echo -e "\033[35m 紫色字 \033[0m"
# #echo -e "\033[37m 白色字 \033[0m"

StartShell()
{
    #First check the enviorment base on the config
    echo -e "\n[*]检查配置文件情况..."
    if test -f ${g_config_floder};
    then
        echo -e "${success}配置文件检查成功"
    else
        echo -e "${err}没有找到 ./${g_config_floder} 文件, 正在尝试创建..."
        if touch ./miuwiki_server_manager.conf
        then
            fold=$(pwd)
            echo -e "{\n    name = 默认服务器\n    ip = 192.168.1.1\n    port = 27015\n    folder = ${fold}/L4D2/srcds_run\n    cmd = -game left4dead2 -console -condebug +map c2m1_highway\n}" >> ./miuwiki_server_manager.conf
            echo -e "${success}配置文件创建成功"
        else
            echo -e "${err}配置文件创建失败, 请检查目录权限或存储容量"
            exit 1
        fi
    fi
    if test -f ${g_update_floder};
    then
        echo -e "${success}更新文件检查成功"
    else
        echo -e "${err}没有找到 ./${g_update_floder} 文件, 正在尝试创建...."
        if touch ./miuwiki_server_update.conf
        then
            echo -e "${success}更新文件创建成功"
        else
            echo -e "${err}更新文件创建失败, 请检查目录权限或存储容量"
            exit 1
        fi
    fi

    #
    echo -e "\n[*]检查Steam CMD安装情况..."
    if test -f ${g_steamcmd_floder};
    then
        echo -e "${green_font}[ok]${normal_font}Steam CMD已经安装"
    else
        echo -e "${red_font}[x]${normal_font}没有找到 ${g_steamcmd_floder} 文件, 正在尝试下载..."
        mkdir ./Steam
        cd ./Steam || return
        curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf -
        cd ../ || return
        echo -e "${green_font}[ok]${normal_font}Steam CMD 安装完成"
    fi
    #
    echo -e "\n[*]检查screen 服务安装情况..."
    temp=$(screen -version grep "Screen version")
    if [ "$temp" ] # 如果不是空, 返回1
    then
        echo -e "${success}screen 服务已经安装" 
    else
        echo -e "${err}screen 服务没有安装, 请根据系统选择合适的安装方式, 之后重新启动脚本."
        exit 1        
    fi
    #
    echo -e "\n[*]正在从配置文件加载信息..."
    #请注意, 读取在windows编辑的conf文件, 每一行都有\r结尾换行, 存的变量就会带有这个\r因此判断或者使用中都会出错
    g_array_name=($(<./miuwiki_server_manager.conf grep "name = " | sed 's/name = //g' | tr -d '\r')) # s删除 "name = " 
    g_array_ip=($(<./miuwiki_server_manager.conf grep "ip = " | sed 's/ip = //g' | tr -d '\r')) 
    g_array_port=($(<./miuwiki_server_manager.conf grep "port = " | sed 's/port = //g' | tr -d '\r'))
    g_array_folder=($(<./miuwiki_server_manager.conf grep "folder = " | sed 's/folder = //g'| tr -d '\r'))
    #cmd 有空格, 因此指定一下eof
    OLD_IFS="${IFS}"
    IFS=$'\t\n'
    g_array_cmd=($(<./miuwiki_server_manager.conf grep "cmd = " | sed 's/cmd = //g' | tr -d '\r'))
    IFS=$OLD_IFS
    # echo "${array_ip[@]}"
    # for((i=0;i<${#array_name[@]};i++)); do
    #     echo "${i}=>${array_name[i]}"
    # done
    echo -e "${green_font}[ok]${normal_font}读取到 ${skyblue}${#g_array_name[@]}${normal_font} 个服务器配置"

    #
    echo -e "\n[*]检查服务器状态中..."
    screen=$(screen -ls)
    for((i=0;i<${#g_array_port[@]};i++)); 
    do  
        # echo -e "${g_array_name[i]}"
        # echo -e "${g_array_ip[i]}"
        # echo -e "${g_array_port[i]}"
        # echo -e "${g_array_cmd[i]}"
        # echo -e "${g_array_folder[i]}"
        if [[ "${screen}" =~ l4d2-conf-port-${g_array_port[i]} ]] # 查找变量是否具有对应字符串
        then
            g_array_status[i]=1
        else    # 不等于为运行
            g_array_status[i]=0
        fi
    done
    echo -e "${green_font}[ok]${normal_font}检查完成, 所有检测已完成."
    #
    username=$(whoami)
    echo -e "
        ———————— https://miuwiki.site ————————
            欢迎使用 Miuwiki 服务器管理系统！
    "
    echo -e "现在是 ${skyblue}$(date)${normal_font}, 当前操作用户: ${green_font}${username}${normal_font} "
    echo -e "\n    当前配置文件下的服务器状态:\n"
    printf "    %-5s %-20s %-20s %-20s\n" 序号 服务器名称: ip:port 状态:
    for((i=0;i<${#g_array_port[@]};i++)); 
    do
        server_num=$((i + 1))
        if [ "${g_array_status[i]}" == 1 ] 
        then
            printf "    %-4s %-20s %-20s ${green_font}%-20s\n${normal_font}" ${server_num}. ${g_array_name[i]} ${g_array_ip[i]}:${g_array_port[i]} [运行]
        else
            printf "    %-4s %-20s %-20s ${red_font}%-20s\n${normal_font}" ${server_num}. ${g_array_name[i]} ${g_array_ip[i]}:${g_array_port[i]} [停止]
        fi
    done
    
    echo -e "\n选择您需要的操作:"
    echo -e "
        ${green_font}1.${normal_font} 安装
        ${green_font}2.${normal_font} 启动
        ${green_font}3.${normal_font} 关闭
        ${green_font}4.${normal_font} 重启
        ${green_font}5.${normal_font} 更新
        ${green_font}6.${normal_font} 查看控制台
        ————————
        ${green_font}7.${normal_font} 刷新配置文件并重启脚本
        ${green_font}0.${normal_font} 退出脚本
    "
    echo && read -e -p "请输入数字 [0-7]: " num
    case "$num" in
    0) ExitShell ;;
    1) InstallServer ;;
    2) StartServer ;;
    3) CloseServer ;;
    4) RestartServer ;;
    5) UpdateServer ;;
    6) CheckServer ;;
    7) ReloadConfig ;;
    *) echo -e "请输入正确的数字 [0-7]" ;;
    esac
}
# exit
ExitShell()
{
    echo -e "退出脚本"
    exit 1
}
# install a server
InstallServer()
{
    state=()
    echo -e "\n${skyblue}[TIPS]: ${normal_font}安装多个服务器请在本次安装完成后自行复制该目录下的游戏服务端."
    echo && read -e -p "[-]是否需要安装 Sourcemod 插件平台(SM:1.11.6931, MM:1.11.0.1148 )[y=是,其余=否] ? " state
    if [ "${state}" = "y" ]
    then
        g_install_server[0]=1
        echo -e " ${green_font}安装 Sourcemod 插件平台.${normal_font}"
    else
        g_install_server[0]=0
        echo -e " ${red_font}不安装 Sourcemod 插件平台.${normal_font}"
    fi
    echo && read -e -p "[-]是否需要安装 Tickrate 拓展(版本请查看该脚本的github)[y=是,其余=否] ?" state
    if [ "${state}" = "y" ]
    then
        g_install_server[1]=1
        echo -e " ${green_font}安装 Tickrate 拓展.${normal_font}"
    else
        g_install_server[1]=0
        echo -e " ${red_font}不安装 Tickrate 拓展.${normal_font}"
    fi
    echo && read -e -p "[-]是否需要安装 L4DTool 拓展(版本请查看该脚本的github)[y=是,其余=否] ?" state
    if [ "${state}" = "y" ]
    then
        g_install_server[2]=1
        echo -e " ${green_font}安装 L4DTool 拓展.${normal_font}"
    else
        g_install_server[2]=0
        echo -e " ${red_font}不安装 L4DTool 拓展.${normal_font}"
    fi
    #
    echo -e "\n[*] 信息获取成功, 请确保当前目录具有读写权限. 正在启动Steam CMD进行下载...\n"
    if ./${g_steamcmd_floder} +force_install_dir ../L4D2 +login anonymous +app_update 222860 +quit
    then
        echo -e "${green_font}[ok]${normal_font} 成功下载服务端, 正在进行余下配置..."
    else
        echo -e "${red_font}[x]${normal_font} 服务端下载失败, 请检查网络连接. 脚本退出."
        exit 1
    fi
    
    #https://mms.alliedmods.net/mmsdrop/1.11/mmsource-1.11.0-git1148-linux.tar.gz
    #https://sm.alliedmods.net/smdrop/1.11/sourcemod-1.11.0-git6931-linux.tar.gz
    if [ "${g_install_server[0]}" == 1 ]
    then
        if test -f "./mmsource-1.11.0-git1148-linux.tar.gz";
        then    
            tar -zxvf ./mmsource-1.11.0-git1148-linux.tar.gz
            state[0]=1
            echo -e "${success} MM:Source 已经下载, 解压完成!"
        else
            echo -e "\n${skyblue}[*] 正在下载: MM:Source...${normal_font}"
            if wget -t 10 -T 3  --no-check-certificate ${g_mmsource} && tar -zxvf ./mmsource-1.11.0-git1148-linux.tar.gz
            then
                state[0]=1
                echo -e "${green_font}[ok]${normal_font} MM:Source:1.11.0.1148 下载解压完成!"
            else
                state[0]=0
                echo -e "${red_font}[x]${normal_font} MM:Source:1.11.0.1148 下载失败, 请检查网络连接."
            fi
        fi
        
        if test -f "./sourcemod-1.11.0-git6931-linux.tar.gz";
        then
            tar -zxvf ./sourcemod-1.11.0-git6931-linux.tar.gz
            state[1]=1
            echo -e "${success} SourceMod 已经下载, 解压完成!"
        else
            echo -e "\n${skyblue}[*] 正在下载: SourceMod...${normal_font}"
            if wget -t 10 -T 3  --no-check-certificate ${g_sourcemod} && tar -zxvf ./sourcemod-1.11.0-git6931-linux.tar.gz
            then
                state[1]=1
                echo -e "${green_font}[ok]${normal_font} SourceMod:1.11:6931 下载解压完成!"
            else
                state[1]=0
                echo -e "${red_font}[x]${normal_font} SourceMod:1.11:6931 下载失败, 请检查与网络连接."
            fi
        fi
    fi
    #
    if [ "${g_install_server[1]}" == 1 ]
    then
        if test -f "./Tickrate-Enabler-l4d2-def3795.zip";
        then
            unzip -o ./Tickrate-Enabler-l4d2-def3795.zip
            state[2]=1
            echo -e "${success} Tickrate 拓展已经下载, 解压完成!"
        else
            echo -e "\n${skyblue}[*] 正在下载: Tickrate 拓展...${normal_font}"
            if wget -t 10 -T 3  --no-check-certificate ${g_tickrate} && unzip -o ./Tickrate-Enabler-l4d2-def3795.zip
            then
                echo -e "${green_font}[ok]${normal_font} Tickrate 下载解压完成!"
            else
                echo -e "${red_font}[x]${normal_font} Tickrate 下载失败, 尝试使用镜像下载."
                if wget -t 10 -T 3  --no-check-certificate ${g_tickrate_img} && unzip -o ./Tickrate-Enabler-l4d2-def3795.zip
                then
                    state[2]=1
                    echo -e "${green_font}[ok]${normal_font} Tickrate 下载解压完成!"
                else
                    state[2]=0
                    echo -e "${red_font}[x]${normal_font} Tickrate 镜像源下载失败, 检查网络连接或更换github镜像源."
                fi
            fi
        fi
    fi
    #
    if [ "${g_install_server[2]}" == 1 ]
    then
        if test -f "./L4DToolZ-l4d2-bd0e49f.zip";
        then
            unzip -o ./L4DToolZ-l4d2-bd0e49f.zip
            echo -e "${success} L4DToolZ 拓展已经下载, 解压完成!"
            state[3]=1
        else
            echo -e "\n${skyblue}[*] 正在下载: L4DToolZ 拓展...${normal_font}"
            if wget -t 10 -T 3  --no-check-certificate ${g_l4dtoolz} && unzip -o ./L4DToolZ-l4d2-bd0e49f.zip
            then
                echo -e "${green_font}[ok]${normal_font} L4DToolZ 下载解压完成"
            else
                echo -e "${red_font}[x]${normal_font} L4DToolZ 下载失败, 尝试使用镜像下载. "
                if wget -t 10 -T 3  --no-check-certificate ${g_l4dtoolz_img} && unzip -o ./L4DToolZ-l4d2-bd0e49f.zip
                then
                    state[3]=1
                    echo -e "${green_font}[ok]${normal_font} L4DToolZ 下载解压完成!"
                else
                    state[3]=0
                    echo -e "${red_font}[x]${normal_font} L4DToolZ 镜像源下载失败, 检查网络连接或更换github镜像源."
                fi
            fi
        fi
    fi

    if [[ "${state[0]}" == 1 || "${state[1]}" == 1 || "${state[2]}" == 1 || "${state[3]}" == 1 ]]
    then
        mv -f ./addons/* ./L4D2/left4dead2/addons
        rm -rf ./addons/
    fi
    if [ "${state[1]}" == 1 ]
    then
        mv -f ./cfg/* ./L4D2/left4dead2/cfg
        rm -rf ./cfg/
    fi

    fold=$(pwd)
    echo -e "{" >> ./miuwiki_server_manager.conf
    echo -e "    name = 默认服务器" >> ./miuwiki_server_manager.conf
    echo -e "    ip = 192.168.1.1" >> ./miuwiki_server_manager.conf
    echo -e "    port = 27020" >> ./miuwiki_server_manager.conf
    echo -e "    folder = ${fold}/L4D2/srcds_run" >> ./miuwiki_server_manager.conf
    echo -e "    cmd = -game left4dead2 -console -condebug +map c2m1_highway" >> ./miuwiki_server_manager.conf
    echo -e "}" >> ./miuwiki_server_manager.conf
    echo -e "${success} 成功安装服务器 L4D2, 目录: ${fold}/L4D2."
    if [ "${g_install_server[0]}" == 1 ]
    then
        if [[ ${state[0]} -eq 1 && ${state[1]} -eq 1 ]]
        then
            echo -e "${success} 安装: SouceMod 平台"
        else
            echo -e "${err} 安装: SouceMod 平台"
        fi
    fi
    if [ "${g_install_server[1]}" == 1 ]
    then
        if [ "${state[2]}" == 1 ]
        then
            echo -e "${success} 安装: Tickrate 拓展"
        else
            echo -e "${err} 安装: Tickrate 拓展"
        fi
    fi
    if [ "${g_install_server[2]}" == 1 ]
    then
        if [ "${state[3]}" == 1 ]
        then
            echo -e "${success} 安装: L4DToolz 拓展"
        else
            echo -e "${err} 安装: L4DToolz 拓展"
        fi
    fi
    echo -e "请前往配置文件修改服务器参数\n" 
}
# start the server on config
StartServer()
{
    echo -e "\n    ${green_font}0. ${normal_font}启动所有停止的服务器  "
    for((i=0;i<"${#g_array_status[@]}";i++));
    do
        server_num=$((i + 1))
        if [ "${g_array_status[i]}" == 1 ] 
        then
            printf "    ${green_font}%-2s${normal_font} %-20s %-20s ${green_font}%-20s\n${normal_font}" ${server_num}. ${g_array_name[i]} ${g_array_ip[i]}:${g_array_port[i]} [运行]
        else
            printf "    ${green_font}%-2s${normal_font} %-20s %-20s ${red_font}%-20s\n${normal_font}" ${server_num}. ${g_array_name[i]} ${g_array_ip[i]}:${g_array_port[i]} [停止]
        fi
    done
    echo && read -e -p  "${choose}请选择一个停止的服务器启动[输入对应数字]:  " num
    if [[ ${num} -lt 0 || "${num}" -gt ${server_num} ]]
    then
        echo -e "${err}错误的字符'${num}'."
        StartServer
    fi

    if [ "${num}" == 0 ]
    then
        echo -e "${working}正在启动所有停止的服务器..."
        for((i=0;i<"${#g_array_status[@]}";i++));
        do
            server_num=$((i + 1))
            if [ "${g_array_status[i]}" == 0 ] 
            then
                echo -e "${working}正在启动服务器${server_num}..."
                StartSrcds ${server_num}
            fi
        done
    else # 选项必定大于0小于temp
        index=$((num - 1))
        if [ "${g_array_status[index]}" == 1 ] 
        then
            echo -e "${err}服务器 ${num} 正在运行, 请重新选择"
            StartServer
        else
            echo -e "\n${working}正在启动服务器 ${num} ..."
            StartSrcds "${num}"
        fi
    fi
    screen -ls
}
# start srcds by StartServer()
StartSrcds() # 接受服务器序号
{
    num=$1
    index=$((num - 1))
    #echo -e "screen -dmS l4d2-conf-${num} ${g_array_folder[index]} -ip ${g_array_ip[index]} -port ${g_array_port[index]} ${g_array_cmd[index]}"
    if screen -dmS l4d2-conf-port-${g_array_port[index]} "${g_array_folder[index]}" -ip "${g_array_ip[index]}" -port "${g_array_port[index]}" "${g_array_cmd[index]}" > /dev/null
    then
        echo -e "${success}服务器 ${num} 启动成功."
    else
        echo -e "${err}服务器 ${num} 启动失败, 请检查错误. 脚本退出."
        exit 1
    fi
}
CloseServer()
{
    echo -e "\n    ${green_font}0. ${normal_font}停止所有运行的服务器  "
    for((i=0;i<"${#g_array_status[@]}";i++));
    do
        server_num=$((i + 1))
        if [ "${g_array_status[i]}" == 1 ] 
        then
            printf "    ${green_font}%-2s${normal_font} %-20s %-20s ${green_font}%-20s\n${normal_font}" ${server_num}. ${g_array_name[i]} ${g_array_ip[i]}:${g_array_port[i]} [运行]
        else
            printf "    ${green_font}%-2s${normal_font} %-20s %-20s ${red_font}%-20s\n${normal_font}" ${server_num}. ${g_array_name[i]} ${g_array_ip[i]}:${g_array_port[i]} [停止]
        fi
    done
    echo && read -e -p  "${choose}请选择一个运行中的服务器停止[输入对应数字]:  " num
    if [[ ${num} -lt 0 || "${num}" -gt ${server_num} ]]
    then
        echo -e "${err}错误的字符'${num}'."
        CloseServer
    fi

    if [ "${num}" == 0 ]
    then
        echo -e "${working}正在停止所有运行的服务器..."
        for((i=0;i<"${#g_array_status[@]}";i++));
        do
            server_num=$((i + 1))
            if [ "${g_array_status[i]}" == 1 ] 
            then
                echo -e "${working}正在停止服务器${server_num}..."
                CloseSrcds ${server_num} # 因为停止是通过screen 名称停止的, 因此不需要考虑数组下标影响
            fi
        done
    else # 选项必定大于0小于temp
        index=$((num - 1))
        if [ "${g_array_status[index]}" == 0 ] 
        then
            echo -e "${err}服务器 ${num} 不在运行, 请重新选择"
            CloseServer
        else
            echo -e "\n${working}正在停止服务器 ${num} ..."
            CloseSrcds "${num}" # 因为停止是通过screen 名称停止的, 因此不需要考虑数组下标影响
        fi
    fi
}
CloseSrcds() # 接受服务器序号
{
    servernum=$1
    index=$((servernum - 1))
    if screen -S l4d2-conf-port-${g_array_port[index]} -X quit
    then
        echo -e "${success}服务器 ${index} 停止成功."
    else
        echo -e "${err}服务器 ${num} 停止失败, 请检查错误. 脚本退出."
        exit 1
    fi 
}
RestartServer()
{
    echo -e "\n    ${green_font}0. ${normal_font}重启所有服务器(包括运行和停止的)  "
    for((i=0;i<"${#g_array_status[@]}";i++));
    do
        server_num=$((i + 1))
        if [ "${g_array_status[i]}" == 1 ] 
        then
            printf "    ${green_font}%-2s${normal_font} %-20s %-20s ${green_font}%-20s\n${normal_font}" ${server_num}. ${g_array_name[i]} ${g_array_ip[i]}:${g_array_port[i]} [运行]
        else
            printf "    ${green_font}%-2s${normal_font} %-20s %-20s ${red_font}%-20s\n${normal_font}" ${server_num}. ${g_array_name[i]} ${g_array_ip[i]}:${g_array_port[i]} [停止]
        fi
    done
    echo && read -e -p  "${choose}请选择一个服务器重启[输入对应数字]:  " num
    if [[ ${num} -lt 0 || "${num}" -gt ${server_num} ]]
    then
        echo -e "${err}错误的字符'${num}'."
        StartServer
    fi

    if [ "${num}" == 0 ]
    then
        echo -e "${working}正在重启所有运行的服务器..."
        for((i=0;i<"${#g_array_status[@]}";i++));
        do
            server_num=$((i + 1))
            echo -e "${working}正在重启服务器${server_num}..."
            RestartSrcds ${i} ${server_num}
        done
    else # 选项必定大于0小于temp
        index=$((num - 1))
        echo -e "\n${working}正在重启服务器 ${num} ..."
        RestartSrcds ${index} ${num} 
    fi
    screen -ls
}
RestartSrcds()
{
    index=$1
    servernum=$2
    if [ ${g_array_status[index]} -eq 0 ] # 处于停止状态
    then
        StartSrcds ${servernum}
    else
        CloseSrcds ${servernum}
        StartSrcds ${servernum}
    fi
}
UpdateServer()
{
    echo -e "\n    ${green_font}0. ${normal_font}更新所有服务器(运行中的服务器将会关闭)  "
    for((i=0;i<"${#g_array_status[@]}";i++));
    do
        server_num=$((i + 1))
        if [ "${g_array_status[i]}" == 1 ] 
        then
            printf "    ${green_font}%-2s${normal_font} %-20s %-20s ${green_font}%-20s\n${normal_font}" ${server_num}. ${g_array_name[i]} ${g_array_ip[i]}:${g_array_port[i]} [运行]
        else
            printf "    ${green_font}%-2s${normal_font} %-20s %-20s ${red_font}%-20s\n${normal_font}" ${server_num}. ${g_array_name[i]} ${g_array_ip[i]}:${g_array_port[i]} [停止]
        fi
    done
    echo && read -e -p  "${choose}请选择一个服务器更新[输入对应数字]:  " num
    if [[ ${num} -lt 0 || ${num} -gt ${server_num} ]]
    then
        echo -e "${err}错误的字符'${num}'."
        UpdateServer # 调用自己
    fi

    if [ "${num}" == 0 ]
    then
        echo -e "${working}正在更新所有服务器..."
        for((i=0;i<"${#g_array_status[@]}";i++));
        do
            server_num=$((i + 1))
            if [ "${g_array_status[i]}" == 1 ] 
            then
                echo -e "${working}正在停止服务器${server_num}..."
                CloseSrcds ${server_num}
            fi
        done
        UpdateSrcds 0 ${num}
    else 
        echo -e "\n${working}正在更新服务器 ${num} ..."
        index=$((num - 1))
        if [ "${g_array_status[index]}" == 1 ] 
        then
            CloseSrcds ${num}
        fi
        UpdateSrcds 1 ${num} 
    fi
}
UpdateSrcds() #接收参数 type,0=全部更新,1=部分更新. servernum,服务器序号
{
    if [ $1 -eq 0 ]
    then
        echo -e "@ShutdownOnFailedCommand 0" > ./miuwiki_server_update.conf
        echo -e "@NoPromptForPassword  1" >> ./miuwiki_server_update.conf
        for((i=0;i<"${#g_array_status[@]}";i++));
        do
            temp=${g_array_folder[i]%/*}
            echo -e "force_install_dir ${temp}" >> ./miuwiki_server_update.conf

            if [ $i -eq 0 ]
            then
                echo -e "login anonymous" >> ./miuwiki_server_update.conf
            fi

            echo -e "app_update 222860 validate" >> ./miuwiki_server_update.conf
        done
        echo -e "quit" >> ./miuwiki_server_update.conf
        if ${g_steamcmd_floder} +runscript ../miuwiki_server_update.conf # steamcmd say the need absolute path instead.
        then
            echo -e "${success}服务器全部更新完毕"
        else
            echo -e "${err}服务器更新失败, 脚本退出"
        fi
    else
        servernum=$2
        index=$2-1
        echo -e "@ShutdownOnFailedCommand 1" > ./miuwiki_server_update.conf
        echo -e "@NoPromptForPassword  1" >> ./miuwiki_server_update.conf
        echo -e "force_install_dir ${g_array_folder[index]%/*}/" >> ./miuwiki_server_update.conf
        echo -e "login anonymous" >> ./miuwiki_server_update.conf
        echo -e "app_update 222860 validate" >> ./miuwiki_server_update.conf
        echo -e "quit" >> ./miuwiki_server_update.conf
        if ${g_steamcmd_floder} +runscript ../miuwiki_server_update.conf # steamcmd say the need absolute path instead.
        then
            echo -e "${success}服务器 ${servernum} 更新完毕 "
        else
            echo -e "${err}服务器 ${servernum} 更新失败, 脚本退出"
        fi
    fi
}
CheckServer()
{
    echo -e ""
    for((i=0;i<"${#g_array_status[@]}";i++));
    do
        server_num=$((i + 1))
        if [ "${g_array_status[i]}" == 1 ] 
        then
            printf "    ${green_font}%-2s${normal_font} %-20s %-20s ${green_font}%-20s\n${normal_font}" ${server_num}. ${g_array_name[i]} ${g_array_ip[i]}:${g_array_port[i]} [运行]
        else
            printf "    ${green_font}%-2s${normal_font} %-20s %-20s ${red_font}%-20s\n${normal_font}" ${server_num}. ${g_array_name[i]} ${g_array_ip[i]}:${g_array_port[i]} [停止]
        fi
    done
    echo && read -e -p  "${choose}请选择一个运行中的服务器查看[输入对应数字]:  " num
    if [[ ${num} -lt 1 || "${num}" -gt ${server_num} ]]
    then
        echo -e "${err}错误的字符'${num}'."
        CheckServer
    fi

    index=$((num - 1))
    if [ "${g_array_status[index]}" == 0 ] 
    then
        echo -e "${err}服务器 ${num} 不在运行, 请重新选择"
        CheckServer
    else
        echo -e "\n${working}查看服务器 ${num} ..."
        CheckSrcds "${num}" # 因为停止是通过screen 名称停止的, 因此不需要考虑数组下标影响
    fi
}
CheckSrcds()
{
    server_num=$1
    index=$((server_num - 1))
    screen -r l4d2-conf-port-${g_array_port[$index]}
}
ReloadConfig()
{
    StartShell
}
#let's start the shell!
StartShell