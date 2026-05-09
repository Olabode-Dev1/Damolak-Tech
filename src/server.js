import http from "node:http";

const port = Number.parseInt(process.env.PORT ?? "3000", 10);
const version = process.env.APP_VERSION ?? "local";
const startedAt = new Date().toISOString();

function buildPayload() {
  return {
    service: "damolak-devops-demo",
    status: "ok",
    version,
    uptimeSeconds: Number(process.uptime().toFixed(2)),
    startedAt
  };
}

function sendJson(response, statusCode, payload) {
  response.writeHead(statusCode, { "content-type": "application/json; charset=utf-8" });
  response.end(JSON.stringify(payload));
}

export function handleRequest(request, response) {
  if (request.url === "/health" || request.url === "/ready") {
    sendJson(response, 200, buildPayload());
    return;
  }

  if (request.url === "/") {
    sendJson(response, 200, {
      message: "Damolak Technologies DevOps challenge service",
      docs: "/health"
    });
    return;
  }

  sendJson(response, 404, { error: "not_found" });
}

export function createServer() {
  return http.createServer(handleRequest);
}

const isExecutedDirectly = import.meta.url === `file://${process.argv[1]}`;

if (isExecutedDirectly) {
  const server = createServer();

  server.listen(port, "0.0.0.0", () => {
    console.log(`service listening on ${port}`);
  });
}
