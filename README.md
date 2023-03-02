# L4D2-linux_server_manager_shell
为L4D2 linux服务器编写的中文维护脚本. 包含安装, 更新, 启动与停止等服务器功能, 以及由 accelerator74 大佬提供的 Tickrate 和 L4DToolZ 拓展的便捷安装.

### 使用前提:
- 服务器安装有 screen 服务.
- 服务器能够成功运行 steamcmd .

### 配置文件介绍:
配置文件用来添加需要管理的服务器. 每个服务器之间用{}隔开, 例如一个服务器:
```
{
    name = xxxx
    ip = xxx.xx.xx.xx
    port = xxxx
    folder = xxxxx
    md = +xxx -xxx
}
```
其中

- name   填写你喜欢的名字就行, 不影响服务器hostname
- ip     填服务器公网ip 或 0.0.0.0
- port   填写你的服务器端口
- folder 填写你的服务器srcds_run.sh的所在路径
- cmd    填写服务器需要的启动命令, 其中 -ip 跟 -port 两个cmd不需要填写, 脚本会自动根据上面的ip和port自动添加.

### 可能会遇到的问题:
1. github内陆经常抽风, 因此安装服务器时选择同时安装 tickrate 和 L4DToolZ 的朋友可能经常失败. 如果发生这种情况请直接下载这个项目. 项目内已经含有了这两个拓展.
2. 暂时没想到...

### 联系方式:
尽量使用 pr 提交问题, 确实需要帮助可以联系 QQ:1157201809.

