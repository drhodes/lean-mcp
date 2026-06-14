import Lean
import LeanMCP.Types
import LeanMCP.Transport
import LeanMCP.JsonRpc

open Lean

namespace LeanMCP

def ResourceReadHandler := ReadResourceRequest → IO ReadResourceResult
def ToolCallHandler := CallToolRequest → IO CallToolResult
def PromptHandler := GetPromptRequest → IO GetPromptResult

structure Server where
  info            : Implementation
  capabilities    : ServerCapabilities
  instructions    : Option String := none
  resources       : IO.Ref (List Resource)
  tools           : IO.Ref (List Tool)
  prompts         : IO.Ref (List Prompt)
  resourceHandler : IO.Ref (Option ResourceReadHandler)
  toolHandler     : IO.Ref (Option ToolCallHandler)
  promptHandler   : IO.Ref (Option PromptHandler)

def createServer (info : Implementation) (caps : ServerCapabilities) (instructions : Option String := none) : IO Server := do
  let resources ← IO.mkRef []
  let tools ← IO.mkRef []
  let prompts ← IO.mkRef []
  let resourceHandler ← IO.mkRef none
  let toolHandler ← IO.mkRef none
  let promptHandler ← IO.mkRef none
  return {
    info := info
    capabilities := caps
    instructions := instructions
    resources := resources
    tools := tools
    prompts := prompts
    resourceHandler := resourceHandler
    toolHandler := toolHandler
    promptHandler := promptHandler
  }

def Server.registerResources (s : Server) (resources : List Resource) : IO Unit :=
  s.resources.set resources

def Server.registerResourceReadHandler (s : Server) (handler : ResourceReadHandler) : IO Unit :=
  s.resourceHandler.set (some handler)

def Server.registerTools (s : Server) (tools : List Tool) : IO Unit :=
  s.tools.set tools

def Server.registerToolCallHandler (s : Server) (handler : ToolCallHandler) : IO Unit :=
  s.toolHandler.set (some handler)

def Server.registerPrompts (s : Server) (prompts : List Prompt) : IO Unit :=
  s.prompts.set prompts

def Server.registerPromptHandler (s : Server) (handler : PromptHandler) : IO Unit :=
  s.promptHandler.set (some handler)

def Server.handleRequest (s : Server) (req : Request) : IO Response := do
  let method := req.method
  let params := req.params.getD Json.null
  match method with
  | "initialize" =>
    match fromJson? params with
    | Except.error err =>
      return { id := req.id, error := some { code := -32602, message := s!"Invalid initialize parameters: {err}" } }
    | Except.ok (_opts : ClientInitializeOptions) =>
      let initResult := ServerInitializeOptions.mk "2024-11-05" s.info s.capabilities s.instructions
      return { id := req.id, result := some (toJson initResult) }

  | "resources/list" =>
    let resList ← s.resources.get
    let result := ListResourcesResult.mk resList
    return { id := req.id, result := some (toJson result) }

  | "resources/read" =>
    let handler? ← s.resourceHandler.get
    match handler? with
    | none =>
      return { id := req.id, error := some { code := -32603, message := "No resource read handler registered" } }
    | some handler =>
      match fromJson? params with
      | Except.error err =>
        return { id := req.id, error := some { code := -32602, message := s!"Invalid read parameters: {err}" } }
      | Except.ok (readReq : ReadResourceRequest) =>
        try
          let result ← handler readReq
          return { id := req.id, result := some (toJson result) }
        catch e =>
          return { id := req.id, error := some { code := -32603, message := s!"Resource read error: {e.toString}" } }

  | "tools/list" =>
    let toolList ← s.tools.get
    let result := ListToolsResult.mk toolList
    return { id := req.id, result := some (toJson result) }

  | "tools/call" =>
    let handler? ← s.toolHandler.get
    match handler? with
    | none =>
      return { id := req.id, error := some { code := -32603, message := "No tool call handler registered" } }
    | some handler =>
      match fromJson? params with
      | Except.error err =>
        return { id := req.id, error := some { code := -32602, message := s!"Invalid tool call parameters: {err}" } }
      | Except.ok (callReq : CallToolRequest) =>
        try
          let result ← handler callReq
          return { id := req.id, result := some (toJson result) }
        catch e =>
          return { id := req.id, error := some { code := -32603, message := s!"Tool call error: {e.toString}" } }

  | "prompts/list" =>
    let promptList ← s.prompts.get
    let result := ListPromptsResult.mk promptList
    return { id := req.id, result := some (toJson result) }

  | "prompts/get" =>
    let handler? ← s.promptHandler.get
    match handler? with
    | none =>
      return { id := req.id, error := some { code := -32603, message := "No prompt handler registered" } }
    | some handler =>
      match fromJson? params with
      | Except.error err =>
        return { id := req.id, error := some { code := -32602, message := s!"Invalid prompt get parameters: {err}" } }
      | Except.ok (getReq : GetPromptRequest) =>
        try
          let result ← handler getReq
          return { id := req.id, result := some (toJson result) }
        catch e =>
          return { id := req.id, error := some { code := -32603, message := s!"Prompt get error: {e.toString}" } }

  | _ =>
    return { id := req.id, error := some { code := -32601, message := s!"Method not found: {method}" } }

partial def Server.run (s : Server) (t : StdIOTransport) : IO Unit := do
  match ← t.readMessage with
  | none =>
    pure ()
  | some (Message.request req) =>
    let _ ← IO.asTask do
      let resp ← s.handleRequest req
      t.sendMessage (Message.response resp)
    s.run t
  | some (Message.notification _) =>
    -- Notifications are fire-and-forget, no response is sent.
    s.run t
  | some (Message.response _) =>
    s.run t

end LeanMCP
