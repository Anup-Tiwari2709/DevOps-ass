#!/bin/bash
set -e
apt-get update -y
apt-get install -y python3 python3-pip git curl
python3 -m pip install flask requests
mkdir -p /opt/quickstart
cat > /opt/quickstart/api_server.py <<'EOF'
from flask import Flask, request, jsonify
import os
import requests

app = Flask(__name__)
WORKER_A_HOST = os.environ.get("WORKER_A_HOST", "${worker_a_ip}")
WORKER_A_PORT = int(os.environ.get("WORKER_A_PORT", "5000"))

@app.route("/infer", methods=["POST"])
def infer():
    body = request.get_json(silent=True)
    if not body or "prompt" not in body:
        return jsonify({"error": "request JSON must contain prompt"}), 400
    payload = {"prompt": body["prompt"]}
    resp = requests.post(f"http://{WORKER_A_HOST}:{WORKER_A_PORT}/call", json=payload, timeout=15)
    resp.raise_for_status()
    data = resp.json()
    return jsonify({"result": data["result"], "trace": ["api"] + data.get("trace", [])})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
EOF
cat > /etc/systemd/system/api.service <<'EOF'
[Unit]
Description=Quickstart API gateway
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /opt/quickstart/api_server.py
WorkingDirectory=/opt/quickstart
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable api.service
systemctl start api.service
