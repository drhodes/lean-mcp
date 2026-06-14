import Lean
import LeanMCP

open Lean
open LeanMCP

-- Helper to test JSON serialization/deserialization isomorphism
def testJsonRoundtrip [FromJson α] [ToJson α] (msg : String) (val : α) : IO Unit := do
  let encoded := toJson val
  match fromJson? encoded with
  | Except.error err =>
    throw (IO.userError s!"{msg}: Failed to decode serialized JSON: {err}")
  | Except.ok (decoded : α) =>
    let reEncoded := toJson decoded
    if encoded.compress != reEncoded.compress then
      throw (IO.userError s!"{msg}: Re-encoded JSON mismatch!\n  Original: {encoded.compress}\n  Roundtrip: {reEncoded.compress}")

def main : IO Unit := do
  IO.println "Running LeanMCP Test Suite..."

  -- 1. JSON Serialization Tests
  IO.println "  Running JSON Serialization Tests..."

  let serverInfo : Implementation := { name := "test-server", version := "1.0.0" }
  testJsonRoundtrip "Server Info" serverInfo

  let clientInfo : Implementation := { name := "test-client", version := "1.0.0" }
  testJsonRoundtrip "Client Info" clientInfo

  let resource : Resource := {
    uri := "file:///test/resource"
    name := "Test Resource"
    description := some "A test resource"
    mimeType := some "text/plain"
    template := none
  }
  testJsonRoundtrip "Resource" resource

  let tool : Tool := {
    name := "test-tool"
    description := some "A test tool"
    inputSchema := Json.mkObj [("type", "object")]
  }
  testJsonRoundtrip "Tool" tool

  let promptArg : PromptArgument := {
    name := "testArg"
    description := some "A test argument"
    required := true
  }
  testJsonRoundtrip "PromptArgument" promptArg

  let prompt : Prompt := {
    name := "test-prompt"
    description := some "A test prompt"
    arguments := [promptArg]
  }
  testJsonRoundtrip "Prompt" prompt

  let clientOpts : ClientInitializeOptions := {
    protocolVersion := "2024-11-05"
    clientInfo := clientInfo
    capabilities := { roots := none, sampling := none }
  }
  testJsonRoundtrip "ClientInitializeOptions" clientOpts

  let listResourcesResult : ListResourcesResult := {
    resources := [resource]
  }
  testJsonRoundtrip "ListResourcesResult" listResourcesResult

  let readReq : ReadResourceRequest := { uri := "file:///test/resource" }
  testJsonRoundtrip "ReadResourceRequest" readReq

  let content : ResourceContent := {
    uri := "file:///test/resource"
    mimeType := some "text/plain"
    text := some "Test content"
    blob := none
  }
  let readResult : ReadResourceResult := {
    contents := [content]
  }
  testJsonRoundtrip "ReadResourceResult" readResult

  let callReq : CallToolRequest := {
    name := "test-tool"
    arguments := Json.mkObj [("param", "value")]
  }
  testJsonRoundtrip "CallToolRequest" callReq

  let toolContent : ToolContent := {
    type := "text"
    text := some "Test result"
  }
  let callResult : CallToolResult := {
    content := [toolContent]
    isError := false
  }
  testJsonRoundtrip "CallToolResult" callResult

  IO.println "  JSON Serialization Tests passed!"

  -- 2. Server & Protocol Tests
  IO.println "  Running Server & Protocol Tests..."

  let caps : ServerCapabilities := {
    resources := some { listChanged := true }
    tools := some { listChanged := true }
    prompts := some { listChanged := true }
  }
  let server ← createServer serverInfo caps (some "Test Instructions")

  -- Check initial server state
  if server.info.name != "test-server" then
    throw (IO.userError "Server name mismatch")
  if server.info.version != "1.0.0" then
    throw (IO.userError "Server version mismatch")

  -- Test resource registration
  server.registerResources [resource]
  let regResources ← server.resources.get
  if regResources.length != 1 then
    throw (IO.userError "Resource registration length mismatch")
  if (regResources.head?.map (·.uri)).getD "" != "file:///test/resource" then
    throw (IO.userError "Registered Resource URI mismatch")

  -- Test tool registration
  server.registerTools [tool]
  let regTools ← server.tools.get
  if regTools.length != 1 then
    throw (IO.userError "Tool registration length mismatch")
  if (regTools.head?.map (·.name)).getD "" != "test-tool" then
    throw (IO.userError "Registered Tool name mismatch")

  -- Test prompt registration
  server.registerPrompts [prompt]
  let regPrompts ← server.prompts.get
  if regPrompts.length != 1 then
    throw (IO.userError "Prompt registration length mismatch")
  if (regPrompts.head?.map (·.name)).getD "" != "test-prompt" then
    throw (IO.userError "Registered Prompt name mismatch")

  IO.println "  Server & Protocol Tests passed!"
  IO.println "All tests passed successfully!"
