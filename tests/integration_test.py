import subprocess
import json
import sys

def test():
    # Start the server process
    proc = subprocess.Popen(
        ['./.lake/build/bin/lean-mcp-demo'],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )
    
    try:
        # Read start message from stderr
        stderr_msg = proc.stderr.readline().strip()
        print("Stderr start msg:", stderr_msg)
        if "Lean MCP Demo Server starting..." not in stderr_msg:
            print("ERROR: Unexpected start message on stderr")
            sys.exit(1)
        
        # 1. Send initialize request
        init_req = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "protocolVersion": "2024-11-05",
                "clientInfo": {"name": "test-client", "version": "1.0.0"},
                "capabilities": {"roots": {}, "sampling": {}}
            }
        }
        
        print("\nSending initialize request...")
        proc.stdin.write(json.dumps(init_req) + '\n')
        proc.stdin.flush()
        
        # Read response
        resp = proc.stdout.readline()
        print("Initialize Response:", resp.strip())
        resp_json = json.loads(resp)
        if resp_json.get("error") is not None:
            print("ERROR: Initialize returned error", resp_json.get("error"))
            sys.exit(1)
        
        # 2. Send tools/list request
        list_req = {
            "jsonrpc": "2.0",
            "id": 2,
            "method": "tools/list",
            "params": {}
        }
        print("\nSending tools/list request...")
        proc.stdin.write(json.dumps(list_req) + '\n')
        proc.stdin.flush()
        
        # Read response
        resp = proc.stdout.readline()
        print("Tools/List Response:", resp.strip())
        resp_json = json.loads(resp)
        tools = resp_json.get("result", {}).get("tools", [])
        if not any(t.get("name") == "hello" for t in tools):
            print("ERROR: 'hello' tool not found in list")
            sys.exit(1)
        
        # 3. Send tools/call request
        call_req = {
            "jsonrpc": "2.0",
            "id": 3,
            "method": "tools/call",
            "params": {
                "name": "hello",
                "arguments": {"name": "Antigravity"}
            }
        }
        print("\nSending tools/call request...")
        proc.stdin.write(json.dumps(call_req) + '\n')
        proc.stdin.flush()
        
        # Read response
        resp = proc.stdout.readline()
        print("Tools/Call Response:", resp.strip())
        resp_json = json.loads(resp)
        content = resp_json.get("result", {}).get("content", [])
        if not any("Hello, Antigravity!" in c.get("text", "") for c in content):
            print("ERROR: Tool call returned incorrect content")
            sys.exit(1)
        
        print("\nAll integration checks passed successfully!")
    finally:
        proc.terminate()

if __name__ == '__main__':
    test()
