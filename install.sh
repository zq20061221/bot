#!/bin/bash

# 检查是否为 root 用户
if [ "$(id -u)" -ne 0 ]; then
    echo "请使用 root 用户运行此脚本！"
    exit 1
fi

# 更新系统并安装依赖
echo "更新系统并安装依赖..."
if [ -f /etc/redhat-release ]; then
    yum install -y python3 python3-pip nginx
else
    apt update -y && apt install -y python3 python3-pip nginx
fi

# 安装 Flask
pip3 install flask

# 创建流量监控 Python 应用
mkdir -p /opt/traffic-monitor
cat <<EOF > /opt/traffic-monitor/app.py
from flask import Flask, request, jsonify

app = Flask(__name__)

# 示例数据
PORT_TRAFFIC = {
    10001: {"upload": 25, "download": 25, "used": 50, "remaining": 50},
    10002: {"upload": 10, "download": 5, "used": 15, "remaining": 85}
}

@app.route('/api/query', methods=['GET'])
def query_traffic():
    port = request.args.get('port', type=int)
    if not port or port not in PORT_TRAFFIC:
        return jsonify({"error": "端口不存在或无数据"}), 404
    return jsonify({"port": port, **PORT_TRAFFIC[port]})

@app.route('/')
def index():
    return '''
    <html>
    <head><title>流量查询</title></head>
    <body>
        <h1>流量查询页面</h1>
        <form action="/api/query" method="get">
            <label for="port">请输入端口号:</label>
            <input type="text" id="port" name="port" required>
            <button type="submit">查询</button>
        </form>
    </body>
    </html>
    '''

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
EOF

# 创建 Systemd 服务文件
cat <<EOF > /etc/systemd/system/traffic-monitor.service
[Unit]
Description=Traffic Monitor Service
After=network.target

[Service]
ExecStart=/usr/bin/python3 /opt/traffic-monitor/app.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# 启动服务
systemctl daemon-reload
systemctl enable traffic-monitor
systemctl start traffic-monitor

# 配置 Nginx
cat <<EOF > /etc/nginx/conf.d/traffic-monitor.conf
server {
    listen 80;
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF

systemctl restart nginx

echo "部署完成！访问 http://<你的服务器IP> 使用流量查询页面。"
