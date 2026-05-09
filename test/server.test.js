import test from "node:test";
import assert from "node:assert/strict";

import { handleRequest } from "../src/server.js";

function invoke(url) {
  let statusCode;
  let headers;
  let body;

  const request = { url };
  const response = {
    writeHead(code, responseHeaders) {
      statusCode = code;
      headers = responseHeaders;
    },
    end(payload) {
      body = payload;
    }
  };

  handleRequest(request, response);

  return {
    statusCode,
    headers,
    body: JSON.parse(body)
  };
}

test("GET /health returns status payload", () => {
  const response = invoke("/health");

  assert.equal(response.statusCode, 200);
  assert.equal(response.headers["content-type"], "application/json; charset=utf-8");
  assert.equal(response.body.status, "ok");
  assert.equal(response.body.service, "damolak-devops-demo");
});

test("unknown routes return 404", () => {
  const response = invoke("/missing");

  assert.equal(response.statusCode, 404);
  assert.equal(response.body.error, "not_found");
});
