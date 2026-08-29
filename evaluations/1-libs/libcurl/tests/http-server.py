#!/usr/bin/env python3
import argparse
import http.server
import pathlib

parser = argparse.ArgumentParser()
parser.add_argument("--port-file", required=True, type=pathlib.Path)
parser.add_argument("--requests", type=int, default=2)
args = parser.parse_args()

body = b"hello curl\n"


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, message, *values):
        print(f"{self.client_address[0]} {message % values}", flush=True)


server = http.server.HTTPServer(("127.0.0.1", 0), Handler)
args.port_file.write_text(f"{server.server_port}\n")
for _ in range(args.requests):
    server.handle_request()
server.server_close()
