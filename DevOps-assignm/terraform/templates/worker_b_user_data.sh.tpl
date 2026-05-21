#!/bin/bash
set -e
apt-get update -y
apt-get install -y curl nodejs npm
npm install -g ts-node typescript
mkdir -p /opt/quickstart
cat > /opt/quickstart/worker_b.ts <<'EOF'
import http from "http";

const PORT = 5001;
const server = http.createServer((req, res) => {
  if (req.method === "POST" && req.url === "/infer") {
    let body = "";
    req.on("data", (chunk) => {
      body += chunk;
    });
    req.on("end", () => {
      try {
        const payload = JSON.parse(body);
        const prompt = payload.prompt || "";
        const result = `echo:${prompt}`;
        const response = { result, trace: ["worker-b"] };
        res.writeHead(200, { "Content-Type": "application/json" });
        res.end(JSON.stringify(response));
      } catch (err) {
        res.writeHead(400, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ error: "invalid json" }));
      }
    });
    return;
  }
  res.writeHead(404);
  res.end();
});

server.listen(PORT, "0.0.0.0", () => {
  console.log(`Worker B listening on port ${PORT}`);
});
EOF
cat > /etc/systemd/system/worker-b.service <<'EOF'
[Unit]
Description=Quickstart Worker B (TypeScript)
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/env ts-node /opt/quickstart/worker_b.ts
WorkingDirectory=/opt/quickstart
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable worker-b.service
systemctl start worker-b.service
