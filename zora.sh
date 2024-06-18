#!/bin/bash

# 节点安装功能
function install_node() {
	sudo apt-get update && sudo apt-get upgrade -y
	sudo apt install curl build-essential git screen jq pkg-config libssl-dev libclang-dev ca-certificates gnupg lsb-release -y
	sudo mkdir -p /etc/apt/keyrings
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
	echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
	sudo chmod a+r /etc/apt/keyrings/docker.gpg
	sudo apt-get update
	sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose
	
	sudo systemctl enable docker
	sudo systemctl start docker
	sudo groupadd docker
	sudo usermod -aG docker $USER
	docker version
	echo "部署完成..."
}

# 启动节点
function start_node(){
	# 无限循环，直到输入的节点名称没有重复
	while true; do
	    read -p "请输入节点名称:" node_name
	    # 检查目录是否存在
	    if [[ -d "zora_$node_name" ]]; then
	        echo "错误：$node_name 已存在，请输入一个新的节点名称。"
	    else
	        read -p "请输入l1 rpc:" NEW_OP_NODE_L1_ETH_RPC
	        break
	    fi
	done
	
	git clone https://github.com/conduitxyz/node.git "zora_$node_name"
	cd "zora_$node_name"
	./download-config.py zora-mainnet-0
	export CONDUIT_NETWORK=zora-mainnet-0
	cp .env.example .env
	
	# 定义新的值
	NEW_OP_NODE_L1_BEACON="https://beaconstate.info"
	# 使用 sed 替换 .env 文件中的值
	sed -i "s#OP_NODE_L1_ETH_RPC=.*#OP_NODE_L1_ETH_RPC=$NEW_OP_NODE_L1_ETH_RPC#" .env
	sed -i "s#OP_NODE_L1_BEACON=.*#OP_NODE_L1_BEACON=$NEW_OP_NODE_L1_BEACON#" .env
	screen -S "zora_$node_name" -dm bash -c 'docker compose up --build'
	echo "节点已启动在 screen 会话 zora_$node_name 中。"
}

# 查看日志
function view_logs(){
	# 获取当前运行的screen会话列表
	screens=$(screen -ls | grep -oP '\t\K[\d]+\.[^\s]+')
	# 检查是否有screen会话
	if [ -z "$screens" ]; then
	    echo "没有找到正在运行的screen会话。"
	    exit 1
	fi
	
	# 显示screen会话列表供用户选择
	echo "检测到以下screen会话："
	echo "$screens"
	echo ""
	
	# 提示用户输入
	read -p "请输入您想查看的screen会话名称: " choice
	
	# 检查用户输入是否为有效会话
	if [[ $screens == *$choice* ]]; then
	    # 连接到用户选择的screen会话
	    echo "3秒后显示，按键盘 Ctra + a + d 退出"; sleep 3
	    screen -r $choice
	else
	    echo "输入错误或会话不存在。"
	    exit 1
	fi
}

# 卸载节点
function uninstall_node(){
    echo "你确定要卸载Zora节点程序吗？这将会删除所有相关的数据。[Y/N]"
    read -r -p "请确认: " response
    case "$response" in
        [yY][eE][sS]|[yY]) 
            echo "开始卸载节点程序..."
            screen -ls | grep 'zora_' | cut -d. -f1 | awk '{print $1}' | xargs -I {} screen -X -S {} quit
            docker ps -a --filter "name=zora_" --format "{{.ID}}" | xargs -r docker stop
			docker ps -a --filter "name=zora_" --format "{{.ID}}" | xargs -r docker rm
			docker images --filter "reference=zora_*" --format "{{.Repository}}:{{.Tag}}" | xargs -r docker rmi
			rm -rf zora_*
            echo "节点程序卸载完成。"
            ;;
        *)
            echo "取消卸载操作。"
            ;;
    esac
}

# 主菜单
function main_menu() {
	while true; do
	    clear
	    echo "===================Zora 一键部署脚本==================="
		echo "沟通电报群：https://t.me/lumaogogogo"
		echo "官方推荐：8C16G200G；测试推荐：2C4G200G"
	    echo "请选择要执行的操作:"
	    echo "1. 部署节点 install_node"
	    echo "2. 启动节点 start_node"
	    echo "3. 查看日志 view_logs"
	    echo "1618. 卸载节点 uninstall_node"
	    echo "0. 退出脚本 exit"
	    read -p "请输入选项: " OPTION
	
	    case $OPTION in
	    1) install_node ;;
	    2) start_node ;;
	    3) view_logs ;;
	    1618) uninstall_node ;;
	    0) echo "退出脚本。"; exit 0 ;;
	    *) echo "无效选项，请重新输入。"; sleep 3 ;;
	    esac
	    echo "按任意键返回主菜单..."
        read -n 1
    done
}

main_menu