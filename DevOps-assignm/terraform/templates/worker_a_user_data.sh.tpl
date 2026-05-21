#!/bin/bash
set -e
apt-get update -y
apt-get install -y python3 python3-pip git curl
python3 -m pip install flask requests
mkdir -p /opt/quickstart
cat > /opt/quickstart/worker_a.py <<'EOF'
from flask import Flask, request, jsonify
import os
import requests

app = Flask(__name__)
WORKER_B_HOST = os.environ.get("WORKER_B_HOST", "${worker_b_ip}")
WORKER_B_PORT = int(os.environ.get("WORKER_B_PORT", "5001"))

@app.route("/call", methods=["POST"])
def call():
    body = request.get_json(silent=True)
    if not body or "prompt" not in body:
        return jsonify({"error": "request JSON must contain prompt"}), 400
    payload = {"prompt": body["prompt"]}
    resp = requests.post(f"http://{WORKER_B_HOST}:{WORKER_B_PORT}/infer", json=payload, timeout=15)
    resp.raise_for_status()
    data = resp.json()
    return jsonify({"result": data["result"], "trace": ["worker-a"] + data.get("trace", [])})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
EOF
cat > /etc/systemd/system/worker-a.service <<'EOF'
[Unit]
Description=Quickstart Worker A (Python)
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /opt/quickstart/worker_a.py
WorkingDirectory=/opt/quickstart
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable worker-a.service
systemctl start worker-a.service
