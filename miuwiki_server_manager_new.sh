#!/bin/bash
cd "$(dirname "$0")" || exit # 先切换到脚本所在目录


#请设置Steam账户设置
g_steam_user=""
g_steam_password=""

#Steam CMD 位置
g_steamcmd_dir="./steam"
# 初始服务器文件夹
g_default_server_dir="./mm_l4d2_pure"
# sm 平台缓存文件夹
g_sourcemod_dir="./mm_l4d2_sourcemod"
# extension 缓存文件夹
g_extension_dir="./mm_l4d2_extension"
# log 日志文件夹
g_log_dir="./mm_l4d2_log"

#GitHub源
g_tickrate_github_api="https://api.github.com/repos/accelerator74/Tickrate-Enabler/releases"
g_l4dtoolz_github_api="https://api.github.com/repos/accelerator74/l4dtoolz/releases"
#镜像kgithub
g_tickrate_img="https://api.kgithub.com/repos/accelerator74/Tickrate-Enabler/releases"
g_l4dtoolz_img="https://api.kgithub.com/repos/accelerator74/l4dtoolz/releases"

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

# 全局变量：存储扫描到的服务器列表
# 格式: "index|folder_name|port|screen_name|status"
# 注意：这里使用全局变量是为了在函数间传递数据，避免复杂的返回值处理
g_server_list=()
g_server_count=0

#========== 辅助函数 ==========

# 检查和安装依赖包
CheckAndInstallDependencies()
{
    local dependencies=("unzip" "screen" "lib32gcc-s1" "netstat" "libc6:i386" "libstdc++6:i386")
    local missing_packages=()
    
    echo -e "\n${working} 检查依赖包...\n"
    
    # 检查每个依赖包
    for package in "${dependencies[@]}"; do
        # 对于netstat，直接检查命令是否存在
        if [ "${package}" == "netstat" ]; then
            if ! command -v netstat &> /dev/null; then
                # netstat通常来自net-tools包
                missing_packages+=("net-tools")
                echo -e "${err} 缺少: net-tools (netstat)"
            else
                echo -e "${success} 已安装: netstat"
            fi
        elif dpkg -s "${package}" &>/dev/null 2>&1; then
            echo -e "${success} 已安装: ${package}"
        else
            missing_packages+=("${package}")
            echo -e "${err} 缺少: ${package}"
        fi
    done
    
    # 如果有缺少的包，询问是否安装
    if [ ${#missing_packages[@]} -gt 0 ]; then
        echo -e "\n${choose} 发现缺少以下包: ${missing_packages[*]}"
        echo && read -r -e -p "是否现在安装这些包? [y=是,其余=否]: " install_choice
        
        if [ "${install_choice}" == "y" ]; then
            echo -e "\n${working} 正在更新包管理器...\n"
            if ! sudo apt-get update 2>/dev/null; then
                echo -e "${err} 更新包管理器失败，请手动运行: sudo apt-get update"
                return 1
            fi
            
            echo -e "\n${working} 正在安装缺少的包...\n"
            if ! sudo apt-get install -y "${missing_packages[@]}" 2>/dev/null; then
                echo -e "${err} 某些包安装失败，请手动运行: sudo apt-get install -y ${missing_packages[*]}"
                return 1
            fi
            echo -e "\n${success} 所有缺少的包已安装"
        else
            echo -e "${err} 缺少必要的包，脚本无法继续"
            return 1
        fi
    else
        echo -e "\n${success} 所有依赖包都已安装"
    fi
}

GetServerList()
{
    # 重置全局列表
    g_server_list=()
    g_server_count=0

    # 遍历当前目录下的所有子目录
    for dir in */; do
        local folder_name="${dir%/}"
        
        # 排除初始核心目录
        if [ "${folder_name}" == "${g_default_server_dir}" ]; then
            continue
        fi

        # 检查是否包含 srcds_run 和 run_server.sh
        if [ -f "${folder_name}/srcds_run" ] && [ -f "${folder_name}/run_server.sh" ]; then
            # 提取端口
            local port
            port=$(grep -oP '\-port\s+\K[0-9]+' "${folder_name}/run_server.sh" | head -1)
            
            # 如果没找到端口，跳过
            if [ -z "$port" ]; then
                continue
            fi

            # 定义 screen 名称 (规则: l4d2_文件夹名称)
            local screen_name="l4d2_${folder_name}"
            
            # 检测状态 (检查 screen 会话是否存在)
            local status=0
            if screen -list | grep -q "${screen_name}"; then
                status=1
            fi

            # 添加到全局列表
            g_server_list+=("${g_server_count}|${folder_name}|${port}|${screen_name}|${status}")
            ((g_server_count++))
        fi
    done
}

StartShell()
{
    # 检查Steam CMD安装情况
    echo -e "\n${working} 检查Steam CMD安装情况..."
    if test -f "${g_steamcmd_dir}/steamcmd.sh";
    then
        echo -e "${success}Steam CMD已经安装"
    else
        echo -e "${err} 没有找到 ${g_steamcmd_dir} 目录, 正在尝试下载..."
        mkdir ${g_steamcmd_dir} || return
        cd ${g_steamcmd_dir} || return
        curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf -
        cd ../ || return
        echo -e "${success} Steam CMD 安装完成"
    fi

    # 检查其他必要的工具
    echo -e "\n${working} 检查必要工具..."
    if ! CheckAndInstallDependencies; then
        echo -e "${err} 依赖包安装失败，脚本无法继续"
        exit 1
    fi

    # 检查目录信息:
    if [ -d "${g_default_server_dir}" ] && [ -f "${g_default_server_dir}/srcds_run" ]; then
        download_state="${green_font}已下载"
    else
        download_state="${red_font}未下载"
    fi

    # 1. 检查并创建拓展目录
    if [ ! -d "${g_extension_dir}" ]; 
    then
        echo "${working} 创建拓展缓存目录: ${g_extension_dir}"
        if ! mkdir "${g_extension_dir}"; then
            echo "${err} 创建拓展缓存目录失败, 请检查权限, 脚本退出"
            exit 1
        fi
    fi
    # 检查并创建 sourcemod 目录
    if [ ! -d "${g_sourcemod_dir}" ]; 
    then
        echo "${working} 创建Sourcemod目录: ${g_sourcemod_dir}"
        if ! mkdir "${g_sourcemod_dir}"; then
            echo "${err} 创建Sourcemod目录失败, 请检查权限, 脚本退出"
            return 1
        fi
    fi
    # 检查并创建 log 目录
    if [ ! -d "${g_log_dir}" ]; 
    then
        echo "${working} 创建log目录: ${g_log_dir}"
        if ! mkdir "${g_log_dir}"; then
            echo "${err} 创建log目录失败, 请检查权限, 脚本退出"
            return 1
        fi
    fi

    echo -e "${success} 检查完成, 所有检测已完成."
    #
    username=$(whoami)
    echo -e "
        ———————— https://miuwiki.site ————————
            欢迎使用 Miuwiki 服务器管理系统！
    "
    echo -e "现在是 ${skyblue}$(date)${normal_font}, 当前操作用户: ${green_font}${username}${normal_font} "
    echo -e "\n    当前配置文件下的服务器状态:\n"
    printf "%-5s %-27s %-17s %-20s\n" 序号 服务器名称: 端口: 状态:
    # 需要打印出存在的服务器名称、ip、port和状态
    GetServerList

    for item in "${g_server_list[@]}"; do
        IFS='|' read -r idx folder port sname status <<< "$item"
        
        local display_num=$((idx + 1))
        
        if [ "$status" == "1" ]; then
            printf "%-4s${normal_font} %-20s %-17s ${green_font}%-20s${normal_font}\n" "${display_num}." "${folder}" "Port: ${port}" "[运行]"
        else
            printf "%-4s${normal_font} %-20s %-17s ${red_font}%-20s${normal_font}\n"   "${display_num}." "${folder}" "Port: ${port}" "[停止]"
        fi
    done
    
    echo -e "\n选择您需要的操作:"
    echo -e "
    
        ${green_font}1.${normal_font} 创建 L4D2 服务器
        ${green_font}2.${normal_font} 启动
        ${green_font}3.${normal_font} 关闭
        ${green_font}4.${normal_font} 重启
        ${green_font}5.${normal_font} 更新
        ${green_font}6.${normal_font} 查看控制台
        ${green_font}7.${normal_font} 下载 L4D2 初始服务器 [${download_state}]
        ${green_font}8.${normal_font} 下载 Sourcemod 插件平台 
        ${green_font}9.${normal_font} 下载 Tickrate, L4DTool 拓展
        ————————
        ${green_font}0.${normal_font} 退出脚本
    "
    echo && read -r -e -p "请输入数字 [0-9]: " num
    case "$num" in
    0) ExitShell ;;
    1) CreateServer ;;
    2) StartServer ;;
    3) CloseServer ;;
    4) RestartServer ;;
    5) UpdateServer ;;
    6) CheckServer ;;
    7) InstallServer ;;
    8) InstallSourcemod ;;
    9) InstallExtions ;;
    *) echo -e "请输入正确的数字 [0-9]" ;;
    esac
}

# exit
ExitShell()
{
    echo -e "退出脚本"
    exit 1
}

CreateServer()
{
    echo -e "\n${skyblue}========== 创建新服务器 ==========${normal_font}"

    # 1. 检查 ${g_default_server_dir} 是否存在且完整
    if [ ! -d "${g_default_server_dir}" ] || [ ! -f "${g_default_server_dir}/srcds_run" ]; then
        echo -e "${err} 未找到完整的服务器核心文件。"
        echo -e "${choose} 请先使用脚本的下载功能安装初始服务器。"
        return 1
    fi

    # 2. 询问是否安装 SourceMod
    local install_sm="n"
    local selected_sm_dir=""
    
    echo && read -r -e -p "[-]是否安装 SourceMod 平台? [Y/n]: " install_sm
    
    if [[ "${install_sm}" =~ ^[Yy]$ ]]; then
        if [ ! -d "${g_sourcemod_dir}" ]; then
            echo -e "${err} SourceMod 缓存目录不存在: ${g_sourcemod_dir}"
            echo -e "${choose} 请先使用脚本下载 SourceMod 平台。"
            return 1
        fi

        # 列出所有 git-xxx 目录
        local sm_versions=()
        local i=1
        
        # 查找以 git- 开头的目录 (适配 git-xxx 格式)
        for dir in "${g_sourcemod_dir}"/*-git-*; do
            if [ -d "$dir" ]; then
                dir_name=$(basename "$dir")
                echo -e "  ${green_font}$i.${normal_font} ${dir_name}"
                sm_versions+=("$dir_name")
                ((i++))
            fi
        done

        if [ ${#sm_versions[@]} -eq 0 ]; then
            echo -e "${err} 未找到任何 SourceMod 版本。"
            echo -e "${choose} 请先使用脚本下载 SourceMod 平台。"
            return 1
        fi

        echo -e "\n${working} 检测到以上可用的 SourceMod 版本:"
        # 用户选择版本
        while true; do
            echo && read -r -e -p "[-]请选择 SourceMod 版本序号 [1-${#sm_versions[@]}]: " sm_choice
            if [[ "$sm_choice" =~ ^[0-9]+$ ]] && [ "$sm_choice" -ge 1 ] && [ "$sm_choice" -le ${#sm_versions[@]} ]; then
                selected_sm_dir="${g_sourcemod_dir}/${sm_versions[$((sm_choice-1))]}"
                echo -e "${success} 已选择: ${selected_sm_dir}"
                break
            else
                echo -e "${err} 输入无效，请重试。"
            fi
        done
    fi

    # 3. 询问是否安装 Extension
    local install_ext="n"
    local selected_ext_dir=""

    echo && read -r -e -p "[-]是否安装 Extension (Tickrate/L4DTool)? [y/N]: " install_ext

    if [[ "${install_ext}" =~ ^[Yy]$ ]]; then
        if [ ! -d "${g_extension_dir}" ]; then
            echo -e "${err} Extension 缓存目录不存在: ${g_extension_dir}"
            echo -e "${choose} 请先使用脚本下载 Extension。"
            return 1
        fi

        # 列出所有时间戳目录
        local ext_versions=()
        local i=1
  
        for dir in "${g_extension_dir}"/*/; do
            if [ -d "${dir}" ]; then
                echo -e "  ${green_font}$i.${normal_font} ${dir}"
                ext_versions+=("$dir")
                ((i++))
            fi
        done

        if [ ${#ext_versions[@]} -eq 0 ]; then
            echo -e "${err} 未找到任何 Extension 版本。"
            echo -e "${choose} 请先使用脚本下载 Extension。"
            return 1
        fi

        echo -e "\n${working} 检测到以上Extension 文件夹:"
        # 用户选择版本
        while true; do
            echo && read -r -e -p "[-]请选择 Extension 版本序号 [1-${#ext_versions[@]}]: " ext_choice
            if [[ "$ext_choice" =~ ^[0-9]+$ ]] && [ "$ext_choice" -ge 1 ] && [ "$ext_choice" -le ${#ext_versions[@]} ]; then
                selected_ext_dir="${ext_versions[$((ext_choice-1))]}"
                echo -e "${success} 已选择: ${selected_ext_dir}"
                break
            else
                echo -e "${err} 输入无效，请重试。"
            fi
        done
    fi

    # 4. 输入服务器名称
    local server_name=""
    while true; do
        echo && read -r -e -p "[-]请输入新服务器名称 (仅限英文、数字、下划线, 不能包含空格和.): " server_name
        # 校验：只允许字母、数字、下划线、短横线，不允许空格和点
        if [[ "$server_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            # 检查是否已存在同名文件夹
            if [ -d "./${server_name}" ]; then
                echo -e "${err} 目录 ./${server_name} 已存在，请更换名称。"
            else
                break
            fi
        else
            echo -e "${err} 名称包含非法字符。请仅使用英文、数字或下划线，且不能包含空格和.。"
        fi
    done

    # 5. 开始创建流程
    echo -e "\n${working} 开始创建服务器..."
    
    # 5.1 复制 ${g_default_server_dir} 到新目录
    echo -e "${working} 正在复制核心文件 (这可能需要几分钟)..."
    # cp -a 保持属性，递归复制
    if cp -af "${g_default_server_dir}" "./${server_name}"; then
        echo -e "${success} 核心文件复制完成"
    else
        echo -e "${err} 核心文件复制失败 \n"
        return 1
    fi

    # 定义目标路径常量，避免重复书写
    local target_server_dir="./${server_name}"
    local target_addons="${target_server_dir}/left4dead2/addons"
    local target_cfg="${target_server_dir}/left4dead2/cfg"

    # 5.2 复制 SourceMod
    if [ -n "${selected_sm_dir}" ]; then
        echo -e "${working} 正在安装 SourceMod..."
        
        # 创建目标目录以防万一
        mkdir -p "${target_addons}"
        mkdir -p "${target_cfg}"

        # 复制 addons (路径: ./l4d2_sourcemod/git-xxx/addons/*)
        if [ -d "${selected_sm_dir}/addons" ]; then
            cp -rf "${selected_sm_dir}/addons/"* "${target_addons}/"
            echo -e "${success} SourceMod addons 安装完成"
        else
            echo -e "${err} 未找到 SourceMod addons 目录: ${selected_sm_dir}/addons"
        fi

        # 复制 cfg (路径: ./l4d2_sourcemod/git-xxx/cfg/*)
        if [ -d "${selected_sm_dir}/cfg" ]; then
            cp -rf "${selected_sm_dir}/cfg/"* "${target_cfg}/"
            echo -e "${success} SourceMod cfg 安装完成"
        else
            echo -e "${err} 未找到 SourceMod cfg 目录: ${selected_sm_dir}/cfg"
        fi
    fi

    # 5.3 复制 Extension
    if [ -n "${selected_ext_dir}" ]; then
        echo -e "${working} 正在安装 Extension..."
        
        # 复制 addons (路径: ./l4d2_extension/20231027_153045/addons/*)
        if [ -d "${selected_ext_dir}/addons" ]; then
            cp -rf "${selected_ext_dir}/addons/"* "${target_addons}/"
            echo -e "${success} Extension 安装完成"
        else
            echo -e "${err} 未找到 Extension addons 目录: ${selected_ext_dir}/addons"
        fi
    fi

    # 5.4 创建启动脚本 run_server.sh
    echo -e "${working} 正在生成启动脚本..."
    
    # 写入更新脚本
    local update_script="${target_server_dir}/update_server.txt"
    if [ -n "${g_steam_user}" ] && [ "${g_steam_user}" != "anonymous" ]
    then
        login="login ${g_steam_user} ${g_steam_password}"
    else
        login="login anonymous"
    fi
    {
        echo "@ShutdownOnFailedCommand 1 //set to 0 if updating multiple servers at once"
        echo "@NoPromptForPassword 1"
        echo "force_install_dir ../${server_name}"
        echo "${login}"
        echo "app_update 222860 validate" 
        echo "quit"
    } > "${update_script}"
    local run_script="${target_server_dir}/run_server.sh"
    # 写入默认启动参数
    {
        echo "#!/bin/bash"
        echo "# 服务器启动脚本"
        echo "# 请根据需要修改下方的启动参数"
        echo ""
        echo "./srcds_run -game left4dead2 -console -condebug +ip 0.0.0.0 -port 27015"
    } > "${run_script}"

    # 添加执行权限
    if chmod +x "${run_script}"; then
        echo -e "${success} 启动脚本已创建: ${run_script}"
    else
        echo -e "${err} 启动脚本权限设置失败 \n"
    fi
            
    echo -e "\n${success}========== 服务器创建完成 =========="
    echo -e "服务器目录: ${skyblue}${target_server_dir}${normal_font}"
    echo -e "请前往${target_server_dir}/run_server.sh 设置该服务器的启动参数\n"
    
    # 可选：询问是否立即添加到配置文件
    # echo && read -r -e -p "[-]是否将此服务器添加到管理列表? [y/N]: " add_to_conf
    # if [[ "${add_to_conf}" =~ ^[Yy]$ ]]; then
    #     # 这里调用添加配置的逻辑
    # fi
}

# start the server on config
StartServer()
{
    echo -e "\n${skyblue}========== 启动服务器 ==========${normal_font}"
    # 1. 扫描目录并检测状态
    echo -e "${working} 正在扫描服务器目录..."
    
    # 遍历当前目录下的所有子目录
    GetServerList

    if [ ${g_server_count} -eq 0 ]; then
        echo -e "${err} 未找到任何有效的服务器目录。"
        return 1
    fi

    # 2. 显示列表
    echo -e "\n${green_font}0.${normal_font} =>启动所有停止的服务器"
    for item in "${g_server_list[@]}"; do
        IFS='|' read -r idx folder port sname status <<< "$item"
        
        local display_num=$((idx + 1))
        
        if [ "$status" == "1" ]; then
            printf "${green_font}%-2s${normal_font} %-20s %-15s ${green_font}%-20s${normal_font}\n" "${display_num}." "${folder}" "Port:${port}" "[运行]"
        else
            printf "${green_font}%-2s${normal_font} %-20s %-15s ${red_font}%-20s${normal_font}\n" "${display_num}." "${folder}" "Port:${port}" "[停止]"
        fi
    done

    # 3. 用户选择
    echo && read -r -e -p "${choose} 请选择要启动的服务器编号: " num

    # 校验输入
    if ! [[ "${num}" =~ ^[0-9]+$ ]]; then
        echo -e "${err} 输入无效"
        return 1
    fi

    if [ "${num}" -lt 0 ] || [ "${num}" -gt ${g_server_count} ]; then
        echo -e "${err} 输入超出范围"
        return 1
    fi

    # 4. 执行启动
    if [ "${num}" == "0" ]; then
        echo -e "${working} 正在批量启动停止的服务器..."
        local started_count=0
        for item in "${g_server_list[@]}"; do
            IFS='|' read -r idx folder port sname status <<< "$item"
            if [ "$status" == "0" ]; then
                echo -e "${working} 正在启动: ${folder} (Port: ${port})..."
                # 进入目录执行脚本，使用 screen -dmS
                # 使用子shell (cd ...) 确保不影响主脚本目录
                if cd "${folder}" && screen -dmS "${sname}" bash run_server.sh; then
                    echo -e "${success} 启动指令已发送: ${sname}"
                    ((started_count++))
                else
                    echo -e "${err} 启动失败: ${folder}"
                fi
                # 串行启动：等待2秒，确保上一个服务器开始加载，减少资源瞬间峰值
                # 必须切换回脚本目录
                cd "$(dirname "$0")" || continue
                sleep 2
            fi
        done
        echo -e "${success} 操作完成，共尝试启动 ${started_count} 个服务器。"
    else
        # 启动单个服务器
        local index=$((num - 1))
        # 获取对应的服务器信息
        IFS='|' read -r idx folder port sname status <<< "${g_server_list[$index]}"

        if [ "$status" == "1" ]; then
            echo -e "${err} 服务器 ${folder} 已经在运行中。"
            return 1
        fi

        echo -e "${working} 正在启动: ${folder}..."
        # 进入目录执行脚本，使用 screen -dmS
        if cd "${folder}" && screen -dmS "${sname}" bash run_server.sh; then
            echo -e "${success} 启动指令已发送，Screen 会话名: ${sname}"
            echo -e "${choose} 使用 'screen -r ${sname}' 可进入控制台。"
        else
            echo -e "${err} 启动失败 \n"
        fi
    fi
    
    # 最后显示一下 screen 列表
    screen -ls
    exit 0
}

CloseServer()
{
    echo -e "\n${skyblue}========== 关闭服务器 ==========${normal_font}"
    echo -e "${working} 正在扫描服务器目录..."
    
    # 遍历当前目录下的所有子目录
    # 调用公共函数获取列表
    GetServerList

    if [ ${g_server_count} -eq 0 ]; then
        echo -e "${err} 未找到任何有效的服务器目录。"
        return 1
    fi

    # 2. 显示列表
    echo -e "\n${green_font}0.${normal_font} =>关闭所有运行中的服务器"
    for item in "${g_server_list[@]}"; do
        IFS='|' read -r idx folder port sname status <<< "$item"
        
        local display_num=$((idx + 1))
        
        if [ "$status" == "1" ]; then
            printf "${green_font}%-2s${normal_font} %-20s %-15s ${green_font}%-20s${normal_font}\n" "${display_num}." "${folder}" "Port:${port}" "[运行]"
        else
            printf "${green_font}%-2s${normal_font} %-20s %-15s ${red_font}%-20s${normal_font}\n" "${display_num}." "${folder}" "Port:${port}" "[停止]"
        fi
    done

    # 3. 用户选择
    echo && read -r -e -p "${choose} 请选择要关闭的服务器编号: " num

    # 校验输入
    if ! [[ "${num}" =~ ^[0-9]+$ ]]; then
        echo -e "${err} 输入无效"
        return 1
    fi

    if [ "${num}" -lt 0 ] || [ "${num}" -gt ${g_server_count} ]; then
        echo -e "${err} 输入超出范围"
        return 1
    fi

    # 4. 执行关闭
    if [ "${num}" == "0" ]; then
        echo -e "${working} 正在批量关闭运行中的服务器..."
        local stopped_count=0
        for item in "${g_server_list[@]}"; do
            IFS='|' read -r idx folder port sname status <<< "$item"
            if [ "$status" == "1" ]; then
                echo -e "${working} 正在关闭: ${folder} (Port: ${port})..."
                # 进入目录执行脚本，使用 screen -dmS
                if screen -S "${sname}" -X quit; then
                    echo -e "${success} 关闭指令已发送: ${sname}"
                    sleep 2
                    ((stopped_count++))
                else
                    echo -e "${err} 关闭失败: ${folder}"
                    sleep 2
                fi
            fi
        done
        echo -e "${success} 操作完成，共尝试关闭 ${stopped_count} 个服务器。"
    else
        # 关闭单个服务器
        local index=$((num - 1))
        # 获取对应的服务器信息
        IFS='|' read -r idx folder port sname status <<< "${g_server_list[$index]}"

        if [ "$status" == "0" ]; then
            echo -e "${err} 服务器 ${folder} 未在运行。"
            return 1
        fi

        echo -e "${working} 正在关闭: ${folder}..."

        if screen -S "${sname}" -X quit; then
            echo -e "${success} 服务器 ${folder} 已关闭。"
        else
            echo -e "${err} 关闭失败 \n"
        fi
    fi
    
    # 最后显示一下 screen 列表
    screen -ls
    exit 0
}

RestartServer()
{
    local auto_restart_num=""
    if [ $# -gt 0 ]; then
        auto_restart_num="$1"
    fi

    # 调用公共函数获取列表
    GetServerList

    if [ ${g_server_count} -eq 0 ]; then
        echo -e "${err} 未找到任何有效的服务器目录。"
        return 1
    fi

    # 3. 用户选择 - 如果没有传递参数, 则提示信息让用户选择
    if [ -z "${auto_restart_num}" ]; 
    then
        echo -e "\n${skyblue}========== 重启服务器 ==========${normal_font}"
        # 1. 扫描目录并检测状态
        echo -e "${working} 正在扫描服务器目录..."
        # 2. 显示列表
        echo -e "\n${green_font}0.${normal_font} =>重启所有服务器"
        for item in "${g_server_list[@]}"; do
            IFS='|' read -r idx folder port sname status <<< "$item"
            
            local display_num=$((idx + 1))
            
            if [ "$status" == "1" ]; then
                printf "${green_font}%-2s${normal_font} %-20s %-15s ${green_font}%-20s${normal_font}\n" "${display_num}." "${folder}" "Port:${port}" "[运行]"
            else
                printf "${green_font}%-2s${normal_font} %-20s %-15s ${red_font}%-20s${normal_font}\n" "${display_num}." "${folder}" "Port:${port}" "[停止]"
            fi
        done

        echo && read -r -e -p "${choose} 请选择要重启的服务器编号: " num

        if ! [[ "${num}" =~ ^[0-9]+$ ]]; then
            echo -e "${err} 输入无效"
            return 1
        fi

        if [ "${num}" -lt 0 ] || [ "${num}" -gt ${g_server_count} ]; then
            echo -e "${err} 输入超出范围"
            return 1
        fi
    else
        num="${auto_restart_num}"
        echo -e "${working} 自动启动服务器编号: ${num}"
    fi

    # 4. 执行重启
    if [ "${num}" == "0" ]; then
        echo -e "${working} 正在批量重启所有服务器..."
        for item in "${g_server_list[@]}"; do
            IFS='|' read -r idx folder port sname status <<< "$item"
            
            # 统一提示
            echo -e "${working} 正在重启: ${folder}..."
            
            if [ "$status" == "1" ]; then
                # 1. 发送关闭指令
                screen -S "${sname}" -X quit
                
                # 2. 等待3秒
                sleep 3
                
                # 3. 检测是否完全关闭
                # 检查 Screen 会话是否存在
                local session_running=0
                if screen -list | grep -q "${sname}"; then
                    session_running=1
                fi
                
                # 检查端口是否被占用 (netstat 或 ss)
                local port_running=0
                if netstat -tuln 2>/dev/null | grep -q ":${port} "; then
                    port_running=1
                fi
                
                # 4. 判断结果
                if [ "${session_running}" == "1" ] || [ "${port_running}" == "1" ]; then
                    echo -e "${err} 重启失败: ${folder} (进程或端口未释放，请手动检查)"
                    # 跳过后续启动逻辑，直接进入下一个循环
                    # 必须先切换回脚本目录
                    sleep 2
                    cd "$(dirname "$0")" || continue
                    continue
                fi
            fi
            
            # 5. 执行启动
            if cd "${folder}" && screen -dmS "${sname}" bash run_server.sh; then
                echo -e "${success} 重启成功: ${sname} \n"
            else
                echo -e "${err} 启动失败: ${folder}"
            fi
            
            # 6. 服务器间隔
            # 必须先切换回脚本目录
            cd "$(dirname "$0")" || continue
            sleep 2
        done
        echo -e "${success} 批量重启操作完成, 如果出现错误, 请查看错误对应的服务器文件夹."
    else
        # 重启单个服务器
        local index=$((num - 1))
        IFS='|' read -r idx folder port sname status <<< "${g_server_list[$index]}"

        echo -e "${working} 正在重启: ${folder}..."
        
        if [ "$status" == "1" ]; then
            echo -e "${working} 正在发送关闭指令..."
            screen -S "${sname}" -X quit
            echo -e "${working} 等待进程关闭 (3s)..."
            sleep 3
            
            # 检测
            local session_running=0
            if screen -list | grep -q "${sname}"; then
                session_running=1
            fi
            
            local port_running=0
            if netstat -tuln 2>/dev/null | grep -q ":${port} "; then
                port_running=1
            fi
            
            if [ "${session_running}" == "1" ] || [ "${port_running}" == "1" ]; then
                echo -e "${err} 重启失败: 进程或端口未释放，请手动检查。"
                return 1
            fi
        fi

        echo -e "${working} 正在发送启动指令..."
        
        if cd "${folder}" && screen -dmS "${sname}" bash run_server.sh; then
            echo -e "${success} 重启成功，Screen 会话名: ${sname} \n"
        else
            echo -e "${err} 启动失败 \n"
        fi
    fi
    
    screen -ls
    exit 0
}

UpdateServer()
{
    echo -e "\n${skyblue}========== 更新服务器 ==========${normal_font}"

    # 1. 扫描目录并检测状态
    echo -e "${working} 正在扫描服务器目录..."
    
    GetServerList

    if [ ${g_server_count} -eq 0 ]; then
        echo -e "${err} 未找到任何有效的服务器目录。"
        return 1
    fi

    # 2. 显示列表
    echo -e "\n${green_font}0.${normal_font} =>更新所有服务器"
    for item in "${g_server_list[@]}"; do
        IFS='|' read -r idx folder port sname status <<< "$item"
        
        local display_num=$((idx + 1))
        
        if [ "$status" == "1" ]; then
            printf "${green_font}%-2s${normal_font} %-20s %-15s ${green_font}%-20s${normal_font}\n" "${display_num}." "${folder}" "Port:${port}" "[运行]"
        else
            printf "${green_font}%-2s${normal_font} %-20s %-15s ${red_font}%-20s${normal_font}\n" "${display_num}." "${folder}" "Port:${port}" "[停止]"
        fi
    done

    # 3. 用户选择
    echo && read -r -e -p "${choose} 请选择要更新的服务器编号: " num

    if ! [[ "${num}" =~ ^[0-9]+$ ]]; then
        echo -e "${err} 输入无效"
        return 1
    fi

    if [ "${num}" -lt 0 ] || [ "${num}" -gt ${g_server_count} ]; then
        echo -e "${err} 输入超出范围"
        return 1
    fi

    # 准备日志文件
    if [ ! -d "${g_log_dir}" ]; then
        mkdir -p "${g_log_dir}"
    fi
    local current_date
    current_date=$(date +"%Y-%-m-%-d")
    local log_file="${g_log_dir}/${current_date}.log"

    # 4. 执行更新
    if [ "${num}" == "0" ]; then
        echo -e "${working} 正在批量更新所有服务器..."
        for item in "${g_server_list[@]}"; do
            IFS='|' read -r idx folder port sname status <<< "$item"
            
            echo -e "\n${working} 正在处理: ${folder}..."
            
            # 如果正在运行，先停止
            if [ "$status" == "1" ]; then
                echo -e "  -> 正在停止服务器..."
                screen -S "${sname}" -X quit
                sleep 3
                
                if screen -list | grep -q "${sname}"; then
                    echo -e "${err}   -> 服务器停止失败，跳过更新。"
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [Update] [${folder}] 错误: 服务器停止失败，跳过更新。" >> "${log_file}"
                    continue
                fi
            fi
            
            # 执行更新
            if [ -f "${folder}/update_server.txt" ]; then
                echo -e "  -> 正在执行更新..."
                # 使用修正后的变量 g_steamcmd_dir
                if "${g_steamcmd_dir}/steamcmd.sh" +runscript "../${folder}/update_server.txt"; then
                    echo -e "${success} -> 更新成功 \n"
                    # 记录成功日志
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [Update] [${folder}] 更新成功。" >> "${log_file}"
                else
                    echo -e "${err}   -> 更新失败"
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [Update] [${folder}] 错误: SteamCMD 更新流程返回错误。" >> "${log_file}"
                fi
            else
                echo -e "${err}   -> 未找到 update_server.txt, 跳过更新"
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] [Update] [${folder}] 错误: 未找到 update_server.txt。" >> "${log_file}"
            fi
            
            sleep 2
        done
        echo -e "${success} 批量更新操作完成。"

        RestartServer "0"
    else
        # 更新单个服务器
        local index=$((num - 1))
        IFS='|' read -r idx folder port sname status <<< "${g_server_list[$index]}"

        echo -e "\n${working} 正在更新: ${folder}..."
        
        # 如果正在运行，先停止
        if [ "$status" == "1" ]; then
            echo -e "${working} 正在停止服务器..."
            screen -S "${sname}" -X quit
            sleep 3
            
            if screen -list | grep -q "${sname}"; then
                echo -e "${err} 服务器停止失败，无法更新。"
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] [Update] [${folder}] 错误: 服务器停止失败。" >> "${log_file}"
                return 1
            fi
        fi

        # 执行更新
        if [ -f "${folder}/update_server.txt" ]; then
            echo -e "${working} 正在执行更新..."
            # 使用修正后的变量 g_steamcmd_dir
            if "${g_steamcmd_dir}/steamcmd.sh" +runscript "../${folder}/update_server.txt"; then
                echo -e "${success} 更新成功 \n"
                # 记录成功日志
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] [Update] [${folder}] 更新成功。" >> "${log_file}"
            else
                echo -e "${err} 更新失败 \n"
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] [Update] [${folder}] 错误: SteamCMD 更新流程返回错误。" >> "${log_file}"
            fi
        else
            echo -e "${err} 未找到 update_server.txt"
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] [Update] [${folder}] 错误: 未找到 update_server.txt。" >> "${log_file}"
        fi

        RestartServer "${num}"
    fi
}

CheckServer()
{
    echo -e "\n${skyblue}========== 查看服务器控制台 ==========${normal_font}"

    # 1. 扫描目录并检测状态
    echo -e "${working} 正在扫描服务器目录..."
    
    # 调用公共函数获取列表
    GetServerList

    if [ ${g_server_count} -eq 0 ]; then
        echo -e "${err} 未找到任何有效的服务器目录。"
        return 1
    fi

    # 2. 显示列表
    echo -e "\n请选择要进入的服务器:"
    for item in "${g_server_list[@]}"; do
        IFS='|' read -r idx folder port sname status <<< "$item"
        
        local display_num=$((idx + 1))
        
        if [ "$status" == "1" ]; then
            printf "${green_font}%-2s${normal_font} %-20s %-15s ${green_font}%-20s${normal_font}\n" "${display_num}." "${folder}" "Port:${port}" "[运行]"
        else
            printf "${green_font}%-2s${normal_font} %-20s %-15s ${red_font}%-20s${normal_font}\n" "${display_num}." "${folder}" "Port:${port}" "[停止]"
        fi
    done

    # 3. 用户选择
    while true; do
        echo && read -r -e -p "${choose} 请选择一个运行中的服务器编号: " num

        # 校验输入是否为数字
        if ! [[ "${num}" =~ ^[0-9]+$ ]]; then
            echo -e "${err} 输入无效，请输入数字。"
            continue
        fi

        # 校验范围
        if [ "${num}" -lt 1 ] || [ "${num}" -gt ${g_server_count} ]; then
            echo -e "${err} 输入超出范围。"
            continue
        fi

        # 获取选择的服务器信息
        local index=$((num - 1))
        IFS='|' read -r idx folder port sname status <<< "${g_server_list[$index]}"

        # 校验状态
        if [ "$status" == "0" ]; then
            echo -e "${err} 服务器 ${folder} 未运行，请重新选择。"
            continue
        fi

        # 4. 执行连接
        echo -e "\n${working} 正在连接到 ${folder} 的控制台..."
        echo -e "${choose} 提示: 使用 ${skyblue}Ctrl+A+D${normal_font} 组合键退出控制台而不关闭服务器。"
        
        # 使用 screen -r 连接
        screen -r "${sname}"
        
        # screen -r 执行后，脚本会暂停在这里，直到用户退出 screen 会话
        # 用户退出后，脚本继续执行
        break
    done
}

# install a server
InstallServer()
{
    # 1. 添加用户确认提示
    echo "${working} 注意：重复下载初始服务器等于更新初始服务器的文件。"
    # -p: 指定提示符
    # -r: 防止反斜杠转义（处理文件名时是个好习惯）
    # -e: 使用 readline 读取（支持方向键等，可选）
    echo && read -r -e -p "${choose} 是否开始下载/更新初始服务器? [Y/n, 默认=y]: " input
    
    # 2. 逻辑判断
    # 如果 input 为空（直接回车），或者是 y/Y，则继续执行
    # ${input^^} 是 bash 4.0+ 特性，将字符串转为大写，这样只需判断是否等于 Y
    if [[ "${input}" =~ ^[Yy]$ ]]; then
        echo -e "\n[*] 信息获取成功, 请确保当前目录具有读写权限. 正在启动Steam CMD进行下载...\n"
        
        # --- 原有的下载逻辑开始 ---
        
        # 构建steamcmd命令
        local steam_cmd="${g_steamcmd_dir}/steamcmd.sh +force_install_dir ../${g_default_server_dir}"
        if [ -n "${g_steam_user}" ] && [ "${g_steam_user}" != "anonymous" ]
        then
            steam_cmd="${steam_cmd} +login ${g_steam_user} ${g_steam_password}"
        else
            steam_cmd="${steam_cmd} +login anonymous"
        fi
        steam_cmd="${steam_cmd} +app_update 222860 +quit"
        
        if eval "${steam_cmd}"
        then
            echo -e "${success} 成功下载服务端..."
            StartShell
        else
            echo -e "${err} 服务端下载失败, 请检查网络连接. 脚本退出."
            exit 1
        fi
        
        # --- 原有的下载逻辑结束 ---

    else
        # 3. 用户输入 n 或其他内容，退出脚本
        echo -e "${err} 用户取消操作, 脚本退出."
        exit 0
    fi
}

InstallSourcemod()
{
    URL="https://www.sourcemod.net/downloads.php?branch=stable"
    html=$(curl -s "$URL")
    stable_version=$(printf '%s\n' "$html" | grep -oP 'sourcemod-\K[0-9]+\.[0-9]+\.[0-9]+(?=-git)' | head -n 1)
    URL="https://www.sourcemod.net/downloads.php?branch=dev"
    html=$(curl -s "$URL")
    dev_version=$(printf '%s\n' "$html" | grep -oP 'sourcemod-\K[0-9]+\.[0-9]+\.[0-9]+(?=-git)' | head -n 1)

    while true; do
        echo && read -r -e -p "${choose} 需要下载哪个版本的 Sourcemod 插件平台[${stable_version}, ${dev_version}] ? " state
        if [ "${state}" = "${stable_version}" ]
        then
            sm_version="${stable_version%.0}"
            URL="https://www.sourcemod.net/downloads.php?branch=${sm_version}-dev&all=1"
            break
        elif [ "${state}" = "${dev_version}" ]
        then
            sm_version="master"
            URL="https://www.sourcemod.net/downloads.php?branch=${sm_version}&all=1"
            break
        else
            echo "${err} 无效输入, 请重试!"
            continue
        fi
    done
    html=$(curl -s "$URL")

    # 从文件名中的 gitXXXX 提取构建号
    builds=$(printf '%s\n' "$html" | grep -oP 'git\K[0-9]+(?=-linux\.tar\.gz)')

    if [ -z "$builds" ]; 
    then
        echo "${err} 未找到任何构建号, 脚本退出"
        exit 1
    fi

    builds_sorted=$(printf '%s\n' "$builds" | sort -n | uniq)

    min_build=$(printf '%s\n' "$builds_sorted" | head -n 1)
    max_build=$(printf '%s\n' "$builds_sorted" | tail -n 1)
    # echo "最旧构建号: $min_build"
    # echo "最新构建号: $max_build"

    # 询问用户下载哪个版本
    while true; do
        echo && read -r -e -p "${choose} 请输入需要下载的构建号 [$min_build - $max_build]: " target_build
        
        # 检查输入是否为空
        if [ -z "$target_build" ]; then
            echo "${err} 输入不能为空。"
            continue
        fi

        # 检查输入是否为数字
        if ! [[ "$target_build" =~ ^[0-9]+$ ]]; then
            echo "${err} 请输入有效的数字。"
            continue
        fi

        # 检查数字是否在范围内
        if [ "$target_build" -ge "$min_build" ] && [ "$target_build" -le "$max_build" ]; then
            echo "${working} 已选择构建号: $target_build"
            break
        else
            echo "${err} 输入的数字不在范围内，请重新输入。"
        fi
    done
    
    # 5. 定义缓存目录路径并创建
    # 这里定义的是目录路径，例如 ./platform/git6931
    if [ "${sm_version}" = "master" ]
    then
        cache_dir="${g_sourcemod_dir}/${dev_version}-git-${target_build}"
        download_url="https://www.sourcemod.net/smdrop/${dev_version%.0}/sourcemod-${dev_version}-git${target_build}-linux.tar.gz"
    else
        cache_dir="${g_sourcemod_dir}/${stable_version}-git-${target_build}"
        download_url="https://www.sourcemod.net/smdrop/${stable_version%.0}/sourcemod-${stable_version}-git${target_build}-linux.tar.gz"
    fi

    mkdir -p "${cache_dir}"

    # 从官方获取最新版本
    sm_name=$(basename "${download_url}")
    echo -e "${working} 正在下载: ${sm_name}..."
    echo -e "${working} 下载地址: ${download_url}"
    
    if wget -t 10 -T 10 --no-check-certificate "${download_url}"; # 2>/dev/null 我们需要下载进度
    then
        # 下载成功，保存到缓存
        if mv "${sm_name}" "${cache_dir}" 2>/dev/null; 
        then
            echo -e "${success} 下载完成并缓存: $cache_dir/${sm_name}"
        else
            echo -e "${success} 下载完成（缓存失败，但继续）: ${sm_name}"
        fi

    else
        echo -e "${err} 下载失败: ${download_url}, 脚本退出"
        return 1
    fi

    # 根据sm_version版本安装对应的mmsource
    
    if [ "${sm_version}" == "master" ]
    then
        URL="https://www.metamodsource.net/downloads.php/?branch=master"
    else
        URL="https://www.metamodsource.net/downloads.php/?branch=stable"
    fi

    html=$(curl -s "$URL")
    mms_version=$(printf '%s\n' "$html" | grep -oP 'mmsource-\K[0-9]+\.[0-9]+\.[0-9]+(?=-git)' | head -n 1)

    # 从文件名中的 gitXXXX 提取构建号
    builds=$(printf '%s\n' "$html" | grep -oP 'git\K[0-9]+(?=-linux\.tar\.gz)')

    if [ -z "$builds" ]; 
    then
        echo "${err} 未找到任何构建号, 脚本退出"
        exit 1
    fi

    builds_sorted=$(printf '%s\n' "$builds" | sort -n | uniq)
    max_build=$(printf '%s\n' "$builds_sorted" | tail -n 1)

    # https://mms.alliedmods.net/mmsdrop/2.0/mmsource-2.0.0-git1383-linux.tar.gz
    download_url="https://mms.alliedmods.net/mmsdrop/${mms_version%.0}/mmsource-${mms_version}-git${max_build}-linux.tar.gz"
    mms_name=$(basename "${download_url}")
    echo -e "${working} 正在下载: ${mms_name}..."
    echo -e "${working} 下载地址: ${download_url}"

    if wget -t 10 -T 10 --no-check-certificate "${download_url}"; # 2>/dev/null 我们需要下载进度
    then
        # 下载成功，保存到缓存
        if mv "${mms_name}" "${cache_dir}" 2>/dev/null; 
        then
            echo -e "${success} 下载完成并缓存: $cache_dir/${mms_name}"
        else
            echo -e "${success} 下载完成（缓存失败，但继续）: ${mms_name}"
        fi

    else
        echo -e "${err} 下载失败: ${download_url}, 脚本退出"
        exit 1
    fi

    # 9. 统一解压
    echo -e "\n${working} 开始解压文件到 ${cache_dir}"
    
    # 检查文件是否存在
    if [ -f "${cache_dir}/${sm_name}" ] && [ -f "${cache_dir}/${mms_name}" ]; then
        # 解压 SourceMod
        echo -e "${working} 正在解压 ${sm_name}..."
        if tar -zxvf "${cache_dir}/${sm_name}" -C "${cache_dir}" > /dev/null 2>&1; then
            echo -e "${success} ${sm_name} 解压成功 \n"
            # 解压后删除压缩包
            # rm -f "${cache_dir}/${sm_name}"
        else
            echo -e "${err} ${sm_name} 解压失败 \n"
            return 1
        fi

        # 解压 MetaMod
        echo -e "${working} 正在解压 ${mms_name}..."
        if tar -zxvf "${cache_dir}/${mms_name}" -C "${cache_dir}" > /dev/null 2>&1; then
            echo -e "${success} ${mms_name} 解压成功 \n"
            # 解压后删除压缩包
            # rm -f "${cache_dir}/${mms_name}"
        else
            echo -e "${err} ${mms_name} 解压失败 \n"
            return 1
        fi
        
        echo -e "${success} 所有文件已安装至: ${cache_dir}"
    else
        echo -e "${err} 文件缺失，无法解压。请检查 ${cache_dir} 目录。"
        return 1
    fi

    return 0
}

InstallExtions()
{
    # 1. 用户确认
    echo && read -r -e -p "${choose} 即将从Github获取最新Tickrate和L4DTool拓展, 是否继续? [Y/n] " state

    # 允许直接回车默认为 Y，或者输入 y/Y
    if [ "${state}" = "n" ] || [ "${state}" = "N" ]; then
        echo -e "${err} 用户取消操作"
        return 1
    fi
    # 如果输入的不是 y/Y/n/N 也不是空，则报错（可选，这里简化逻辑允许非n都继续）
    
    # 2. 下载 Tickrate
    local latest_download_url=""
    echo -e "${working} 尝试从GitHub获取最新版本..."
    echo -e "${working} 获取Tickrate拓展中...[${g_tickrate_github_api}]"
    
    latest_download_url=$(curl -s "${g_tickrate_github_api}" 2>/dev/null | grep -E '"browser_download_url":.*l4d2.*\.zip"' | head -1 | cut -d'"' -f4)

    if [ -z "${latest_download_url}" ]; then
       echo -e "${err} GitHub获取失败, 尝试使用镜像源..."
       latest_download_url=$(curl -s "${g_tickrate_img}" 2>/dev/null | grep -E '"browser_download_url":.*l4d2.*\.zip"' | head -1 | cut -d'"' -f4)

       if [ -z "${latest_download_url}" ]; then
           echo -e "${err} 镜像源获取失败 \n"
           return 1
       fi
    fi

    tickrate_filename=$(basename "${latest_download_url}")
    echo -e "${working} 已获取Tickrate拓展: ${tickrate_filename}, 下载中..."
    if wget -t 10 -T 10 --no-check-certificate "${latest_download_url}"; # 2>/dev/null 我们需要下载进度
    then
        echo -e "${success} ${tickrate_filename} 下载完成 \n"
    else
        echo -e "${err} ${tickrate_filename} 下载失败 \n"
        return 1
    fi

    # 3. 下载 L4DToolZ
    echo -e "${working} 获取L4DTool拓展中...[${g_l4dtoolz_github_api}]"
    latest_download_url=$(curl -s "${g_l4dtoolz_github_api}" 2>/dev/null | grep -E '"browser_download_url":.*l4d2.*\.tar.gz"' | head -1 | cut -d'"' -f4)
    
    if [ -z "${latest_download_url}" ]; then
        echo -e "${err} GitHub获取失败, 尝试使用镜像源..."
        latest_download_url=$(curl -s "${g_l4dtoolz_img}" 2>/dev/null | grep -E '"browser_download_url":.*l4d2.*\.tar.gz"' | head -1 | cut -d'"' -f4)
        if [ -z "${latest_download_url}" ]; then
            echo -e "${err} 镜像源获取失败"
            return 1
        fi
    fi

    l4dtoolz_filename=$(basename "${latest_download_url}")
    echo -e "${working} 已获取L4DTool拓展: ${l4dtoolz_filename}, 下载中..."
    # 注意：L4DToolZ 在 GitHub 上通常是 zip 格式，这里假设你确定是 tar.gz
    # 如果实际下载的是 zip，请将下面的 .tar.gz 改为 .zip，并使用 unzip 解压
    if wget -t 10 -T 10 --no-check-certificate "${latest_download_url}"; then # 2>/dev/null 我们需要下载进度
        echo -e "${success} ${l4dtoolz_filename} 下载完成 \n"
    else
        echo -e "${err} ${l4dtoolz_filename} 下载失败 \n"
        return 1
    fi

    # 4. 准备目录
    # 确保基础目录存在
    if [ ! -d "${g_extension_dir}" ]; then
        mkdir -p "${g_extension_dir}"
    fi

    timestamp_dir=$(date +"%Y-%m-%d_%H-%M-%S")
    target_dir="${g_extension_dir}/${timestamp_dir}"
    mkdir -p "${target_dir}"

    # 5. 移动文件
    # 使用 mv 命令移动文件
    if [ -f "${tickrate_filename}" ]; then
        mv "${tickrate_filename}" "${target_dir}/"
    else
        echo -e "${err} 未找到 ${tickrate_filename}, 无法移动"
        return 1
    fi

    if [ -f "${l4dtoolz_filename}" ]; then
        mv "${l4dtoolz_filename}" "${target_dir}/"
    else
        echo -e "${err} 未找到 ${l4dtoolz_filename}, 无法移动"
        return 1
    fi

    # 6. 解压文件
    echo -e "${working} 开始解压文件..."
    
    # 解压 Tickrate (使用 -d 指定目录)
    if unzip -o "${target_dir}/${tickrate_filename}" -d "${target_dir}" > /dev/null 2>&1; then
        echo -e "${success} ${tickrate_filename} 解压成功"
        # rm -f "${target_dir}/Tickrate.zip"
    else
        echo -e "${err} ${tickrate_filename} 解压失败, 请查看 ${target_dir} 目录"
        return 1
    fi

    # 解压 L4DToolZ (使用 -C 指定目录)
    if tar -zxvf "${target_dir}/${l4dtoolz_filename}" -C "${target_dir}" > /dev/null 2>&1; then
        echo -e "${success} ${l4dtoolz_filename} 解压成功"
        # rm -f "${target_dir}/L4DTool.tar.gz"
    else
        echo -e "${err} L4DTool.tar.gz 解压失败, 请查看 ${target_dir} 目录"
        return 1
    fi

    echo -e "${success} 拓展已解压到: ${target_dir}"
    return 0
}

#let's start the shell!
StartShell