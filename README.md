# L4D2 Linux 服务器管理脚本

为 Left 4 Dead 2 Linux 服务器编写的中文维护脚本。包含安装、更新、启动与停止等服务器管理功能，以及由 [accelerator74](https://github.com/accelerator74) 提供的 [Tickrate](https://github.com/accelerator74/Tickrate-Enabler) 和 [L4DToolZ](https://github.com/accelerator74/l4dtoolz) 扩展的便捷安装。

### 功能特性

- **服务器管理**: 创建、启动、停止、重启服务器
- **自动更新**: 支持自动更新服务器文件（更新后自动重启）
- **扩展支持**: 一键安装 SourceMod 平台和 Tickrate/L4DToolZ 扩展
- **控制台访问**: 通过 screen 会话管理服务器控制台
- **多服务器支持**: 支持创建和管理多个服务器实例

### 使用前提

- 服务器使用 apt 包管理系统（如 Ubuntu、Debian 等）
- 已创建用于运行脚本的用户（如 steam、l4d2 等）
- 拥有可用的 Steam 账户（用于下载游戏文件）

---
### 从零开始开服流程
#### 第一步：准备环境
- 下载项目中的 `.sh` 文件到您的服务器目录。
- 添加执行权限
```bash
chmod +x ./miuwiki_server_manager_new.sh
```
- 修改脚本中的 `g_steam_user` 和 `g_steam_password` 为您的 Steam 账户信息. **强烈建议使用专门的steam小号**
- 启动脚本，选择"**下载初始服务器**"选项
  
#### 第二步：安装可选组件
- **(可选)** 安装 SourceMod 平台
- **(可选)** 安装 Tickrate 和 L4DToolZ 扩展

#### 第三步：创建服务器
- 选择"**创建服务器**"功能，根据提示完成创建

#### 第四步：配置服务器
   进入服务器文件夹，编辑 `run_server.sh` 中的启动参数：
```bash
# 示例配置（注意反斜杠后不要有空行）
./srcds_run -game left4dead2 +sv_lan 0 +ip 0.0.0.0 -port 30033 +map c1m1_hotel \
-tickrate 60 \
-insecure -console -condebug
```

#### 第五步：启动服务器
- 返回脚本主菜单，选择"启动服务器"
- 启动成功后，服务器将在 screen 会话中后台运行
- 使用脚本的"查看控制台"功能可以访问服务器控制台

#### 第六步：扩展服务器(可选)
- 使用脚本的"创建服务器"功能. 不建议直接复制现有服务器文件夹，可能导致参数错误
---
### 功能列表

| 功能 | 描述 |
|------|------|
| 创建服务器 | 创建新的 L4D2 服务器实例 |
| 启动 | 启动已创建的服务器 |
| 停止 | 停止运行中的服务器 |
| 重启 | 重启服务器（先停止后启动） |
| 更新 | 更新服务器文件并自动重启 |
| 查看控制台 | 访问服务器的 screen 控制台 |
| 下载初始文件 | 下载纯净的服务器文件 |
| 安装 SourceMod | 安装 SourceMod 管理平台 |
| 安装扩展 | 安装 Tickrate 和 L4DToolZ 扩展 |

### 进阶使用

#### ▲简化脚本调用

如果觉得脚本名称太长，可以添加到 PATH 并设置别名：

1. 编辑用户目录下的 `.bashrc` 文件：
```bash
# 添加脚本目录到 PATH
export PATH="$PATH:/home/用户目录/脚本所在文件夹"

# 设置别名（mm 可以替换为任何您喜欢的名称）
alias mm='/home/用户目录/脚本所在文件夹/miuwiki_server_manager_new.sh'

# 参考示例：
# export PATH="$PATH:/home/steam/l4d2_manager"
# alias mm='/home/steam/l4d2_manager/miuwiki_server_manager_new.sh'
```

2. 使配置生效：
```bash
source ~/.bashrc
```

3. 现在可以直接使用别名：
```bash
mm
```

#### ▲服务器自动更新

在 `run_server.sh` 的启动参数中添加自动更新功能：

```bash
# 添加以下参数（请根据实际目录修改）：
-autoupdate -steam_dir /home/steam/l4d2_manager/steam/ -steamcmd_script ../myserver/update_server.txt

# 参数说明：
# -steam_dir: steamcmd.sh 所在目录
# -steamcmd_script: steamcmd.sh 相对于当前文件夹的路径，也可以是 update_server.txt 的绝对路径
```

**注意**: 启用此功能后，每次服务器启动都会执行更新检查，可能导致启动延迟。

#### ▲定时执行脚本

使用 crontab 定时执行脚本功能：

```bash
# 每天凌晨 2 点自动更新所有服务器
# 语法：分 时 日 月 周 命令
0 2 * * * /bin/bash -c 'echo -e "5\n0" | /home/steam/l4d2_manager/miuwiki_server_manager_new.sh'

# 说明：
# echo -e "5\n0" 表示选择菜单项 5（更新全部服务器）和后续确认项 0
# 请使用脚本的绝对路径以避免问题
```

#### ▲手动安装扩展的目录结构

如果您手动下载 SourceMod 和扩展，请按以下结构放置文件：

```
l4d2_manager/
├── steam/
├── miuwiki_server_manager_new.sh
├── mm_l4d2_pure/              # 初始服务器文件
├── mm_l4d2_sourcemod/
│   └── 1.12.0-git-xxxx/       # 必须为 x.xx.x-git-xxxx 格式
│       ├── addons/
│       └── cfg/
├── mm_l4d2_extension/
│   └── 2026-3-22_22-33-44/    # 目录格式无要求
│       └── addons/
├── mm_l4d2_log/
├── 您的服务器文件夹1/
└── 您的服务器文件夹2/
```

- `l4d2_sourcemod` 目录内的子目录必须为 `x.xx.x-git-xxxx` 格式，否则无法识别
- `l4d2_extension` 目录内的子目录格式无特殊要求
---
### 注意事项

1. **Steam 账户要求**: 目前下载 Steam 应用必须登录拥有该游戏库存的 Steam 账户，匿名下载不再可用
2. **权限管理**: 确保运行脚本的用户有适当的文件权限
3. **备份重要数据**: 在进行重大操作前建议备份服务器文件
4. **网络连接**: 确保服务器有稳定的网络连接以下载更新和文件
---

**最后更新**: 2026年3月

如有问题或建议，请提出issue。
