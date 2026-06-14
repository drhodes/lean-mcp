import Lean

open Lean

namespace LeanMCP

-- Helper to construct JSON objects with omitted optional fields
def mkObj (fields : List (String × Option Json)) : Json :=
  let active := fields.filterMap (fun (k, v?) => v?.map (fun v => (k, v)))
  Json.mkObj active

-- 1. Implementation
structure Implementation where
  name    : String
  version : String
  deriving FromJson, ToJson, Inhabited

-- 2. Capabilities
structure ResourcesCapability where
  listChanged : Bool
  deriving FromJson, ToJson, Inhabited

structure ToolsCapability where
  listChanged : Bool
  deriving FromJson, ToJson, Inhabited

structure PromptsCapability where
  listChanged : Bool
  deriving FromJson, ToJson, Inhabited

structure ServerCapabilities where
  resources : Option ResourcesCapability := none
  tools     : Option ToolsCapability := none
  prompts   : Option PromptsCapability := none
  deriving FromJson, Inhabited

instance : ToJson ServerCapabilities where
  toJson caps := mkObj [
    ("resources", caps.resources.map toJson),
    ("tools", caps.tools.map toJson),
    ("prompts", caps.prompts.map toJson)
  ]

structure ClientCapabilities where
  roots    : Option Json := none
  sampling : Option Json := none
  deriving FromJson, Inhabited

instance : ToJson ClientCapabilities where
  toJson caps := mkObj [
    ("roots", caps.roots.map toJson),
    ("sampling", caps.sampling.map toJson)
  ]

-- 3. Resources
structure Resource where
  uri         : String
  name        : String
  description : Option String := none
  mimeType    : Option String := none
  template    : Option String := none
  deriving FromJson, Inhabited

instance : ToJson Resource where
  toJson r := mkObj [
    ("uri", some (toJson r.uri)),
    ("name", some (toJson r.name)),
    ("description", r.description.map toJson),
    ("mimeType", r.mimeType.map toJson),
    ("template", r.template.map toJson)
  ]

structure ResourceContent where
  uri      : String
  mimeType : Option String := none
  text     : Option String := none
  blob     : Option String := none
  deriving FromJson, Inhabited

instance : ToJson ResourceContent where
  toJson c := mkObj [
    ("uri", some (toJson c.uri)),
    ("mimeType", c.mimeType.map toJson),
    ("text", c.text.map toJson),
    ("blob", c.blob.map toJson)
  ]

-- 4. Tools
structure Tool where
  name        : String
  description : Option String := none
  inputSchema : Json
  deriving FromJson, Inhabited

instance : ToJson Tool where
  toJson t := mkObj [
    ("name", some (toJson t.name)),
    ("description", t.description.map toJson),
    ("inputSchema", some t.inputSchema)
  ]

structure ToolContent where
  type : String := "text"
  text : Option String := none
  deriving FromJson, Inhabited

instance : ToJson ToolContent where
  toJson tc := mkObj [
    ("type", some (toJson tc.type)),
    ("text", tc.text.map toJson)
  ]

-- 5. Prompts
structure PromptArgument where
  name        : String
  description : Option String := none
  required    : Bool
  deriving FromJson, Inhabited

instance : ToJson PromptArgument where
  toJson a := mkObj [
    ("name", some (toJson a.name)),
    ("description", a.description.map toJson),
    ("required", some (toJson a.required))
  ]

structure Prompt where
  name        : String
  description : Option String := none
  arguments   : List PromptArgument
  deriving FromJson, Inhabited

instance : ToJson Prompt where
  toJson p := mkObj [
    ("name", some (toJson p.name)),
    ("description", p.description.map toJson),
    ("arguments", some (toJson p.arguments))
  ]

structure PromptContent where
  type : String := "text"
  text : String
  deriving FromJson, ToJson, Inhabited

structure PromptMessage where
  role    : String
  content : PromptContent
  deriving FromJson, ToJson, Inhabited

structure Root where
  uri  : String
  name : String
  deriving FromJson, ToJson, Inhabited

-- 6. Initialization
structure ServerInitializeOptions where
  protocolVersion : String
  serverInfo      : Implementation
  capabilities    : ServerCapabilities
  instructions    : Option String := none
  deriving FromJson, Inhabited

instance : ToJson ServerInitializeOptions where
  toJson o := mkObj [
    ("protocolVersion", some (toJson o.protocolVersion)),
    ("serverInfo", some (toJson o.serverInfo)),
    ("capabilities", some (toJson o.capabilities)),
    ("instructions", o.instructions.map toJson)
  ]

structure ClientInitializeOptions where
  protocolVersion : String
  clientInfo      : Implementation
  capabilities    : ClientCapabilities
  deriving FromJson, ToJson, Inhabited

-- 7. Request / Result structures
structure ListResourcesResult where
  resources : List Resource
  deriving FromJson, ToJson, Inhabited

structure ReadResourceRequest where
  uri : String
  deriving FromJson, ToJson, Inhabited

structure ReadResourceResult where
  contents : List ResourceContent
  deriving FromJson, ToJson, Inhabited

structure ListToolsResult where
  tools : List Tool
  deriving FromJson, ToJson, Inhabited

structure CallToolRequest where
  name      : String
  arguments : Json
  deriving FromJson, ToJson, Inhabited

structure CallToolResult where
  content : List ToolContent
  isError : Bool
  deriving FromJson, ToJson, Inhabited

structure ListPromptsResult where
  prompts : List Prompt
  deriving FromJson, ToJson, Inhabited

structure GetPromptRequest where
  name      : String
  arguments : Option Json := none
  deriving FromJson, ToJson, Inhabited

structure GetPromptResult where
  description : Option String := none
  messages    : List PromptMessage
  deriving FromJson, Inhabited

instance : ToJson GetPromptResult where
  toJson r := mkObj [
    ("description", r.description.map toJson),
    ("messages", some (toJson r.messages))
  ]

structure ListRootsResult where
  roots : List Root
  deriving FromJson, ToJson, Inhabited

end LeanMCP
