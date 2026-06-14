import Lean
import LeanMCP

open Lean
open LeanMCP

def helloTool : Tool := {
  name := "hello"
  description := some "Returns a friendly greeting"
  inputSchema := Json.mkObj [
    ("type", "object"),
    ("properties", Json.mkObj [
      ("name", Json.mkObj [("type", "string"), ("description", "The name of the person to greet")])
    ]),
    ("required", Json.arr #[Json.str "name"])
  ]
}

def toolHandler (req : CallToolRequest) : IO CallToolResult := do
  if req.name == "hello" then
    let args := req.arguments
    let name ← match args.getObjVal? "name" with
      | Except.error _ => throw (IO.userError "Missing argument 'name'")
      | Except.ok (Json.str s) => pure s
      | Except.ok _ => throw (IO.userError "Argument 'name' must be a string")

    let content : ToolContent := {
      type := "text"
      text := some s!"Hello, {name}!"
    }
    return { content := [content], isError := false }
  else
    throw (IO.userError s!"Unknown tool: {req.name}")

def main : IO Unit := do
  let info : Implementation := {
    name := "lean-mcp-demo"
    version := "0.1.0"
  }
  let caps : ServerCapabilities := {
    tools := some { listChanged := false }
  }
  let server ← createServer info caps (some "Lean 4 Demo Server")
  server.registerTools [helloTool]
  server.registerToolCallHandler toolHandler

  let transport ← newStdIOTransport
  IO.eprintln "Lean MCP Demo Server starting..."
  server.run transport
