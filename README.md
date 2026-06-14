# LeanMCP

A native, statically-typed Model Context Protocol (MCP) SDK for **Lean 4**, ported from functional Haskell implementations (`hs-mcp`).

This library provides the foundational types and standard I/O transport layers required to build native MCP servers in Lean 4. This enables LLM agents (like Claude or Cursor) to interface directly with Lean 4, run tools, read resources, and navigate prompt libraries.

---

## Features

* **JSON-RPC 2.0 Core**: Custom, robust serialization/deserialization for JSON-RPC messages (Requests, Responses, Notifications, and Error Responses).
* **Strict Spec Compliance**: Precise serialization that automatically omits `none`/`null` fields, preventing schema validation failures in strict clients.
* **Line-Framed Transport**: Standard input/output transport layer (`StdIOTransport`) supporting line-framed JSON communication.
* **Thread-Safe Dispatcher**: Asynchronous task processing using Lean's `IO.asTask` and an atomic-backed spinlock to prevent interleaving output writes on `stdout`.
* **Zero External Dependencies**: Built entirely using the Lean 4 standard library and compiler primitives.

---

## Prerequisites

* **Lean 4 & Lake**: Managed via `elan` (the Lean version manager).
* **Python 3**: Optional, only required to run integration tests.

---

## Quick Start

### 1. Adding to your Lake Project

To use LeanMCP as a dependency in your Lean 4 project, add it to your `lakefile.toml`:

```toml
[[require]]
name = "LeanMCP"
path = "git@github.com:drhodes/lean-mcp.git"  # Or git URL once published
```

### 2. Building the Project

Run `lake build` to compile the library and the demo/test binaries:

```bash
make build
```

This compiles the following targets:
* `LeanMCP` (Library)
* `lean-mcp-demo` (Demo executable located at `.lake/build/bin/lean-mcp-demo`)
* `lean-mcp-test` (Test runner located at `.lake/build/bin/lean-mcp-test`)

---

## Usage Example

Below is a complete, minimal server registration example using LeanMCP (adapted from `Main.lean`):

```lean
import Lean
import LeanMCP

open Lean
open LeanMCP

-- 1. Define a tool
def helloTool : Tool := {
  name := "hello"
  description := some "Returns a friendly greeting"
  inputSchema := Json.mkObj [
    ("type", "object"),
    ("properties", Json.mkObj [
      ("name", Json.mkObj [("type", "string"), ("description", "Name to greet")])
    ]),
    ("required", Json.arr #[Json.str "name"])
  ]
}

-- 2. Define a tool execution handler
def toolHandler (req : CallToolRequest) : IO CallToolResult := do
  if req.name == "hello" then
    let name ← match req.arguments.getObjVal? "name" with
      | Except.ok (Json.str s) => pure s
      | _ => throw (IO.userError "Invalid 'name' argument")

    let content : ToolContent := { type := "text", text := some s!"Hello, {name}!" }
    return { content := [content], isError := false }
  else
    throw (IO.userError s!"Unknown tool: {req.name}")

-- 3. Initialize and run the server
def main : IO Unit := do
  let info : Implementation := { name := "my-mcp-server", version := "1.0.0" }
  let caps : ServerCapabilities := { tools := some { listChanged := false } }
  
  let server ← createServer info caps (some "My Lean 4 MCP Server")
  server.registerTools [helloTool]
  server.registerToolCallHandler toolHandler

  let transport ← newStdIOTransport
  IO.eprintln "Starting Lean MCP Server..."
  server.run transport
```

---

## Running Tests

To run the unit test suite and integration verification test suite:

```bash
make test
```

### Manual Testing / Subprocess Inspection

You can run the Python-based integration runner to simulate JSON-RPC requests over the stdin/stdout channel of the compiled server:

```bash
python3 tests/integration_test.py
```

---

## Acknowledgements

We want to express our sincere gratitude to **Bryan Buecking**, the author of the [hs-mcp](https://github.com/buecking/hs-mcp) library. 

His elegant, functional Haskell implementation served as the reference architecture for this Lean 4 port. Having a clean, functional specification made it incredibly efficient to map Algebraic Data Types (ADTs) and standard I/O transport layers directly to Lean 4 constructs. Thank you, Bryan, for your contribution to the open-source MCP ecosystem!

---

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
