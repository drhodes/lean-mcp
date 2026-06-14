import Lean

open Lean

namespace LeanMCP

structure ErrorResponse where
  code    : Int
  message : String
  data    : Option Json := none
  deriving FromJson, ToJson, Inhabited

structure Request where
  jsonrpc : String := "2.0"
  id      : Json
  method  : String
  params  : Option Json := none
  deriving FromJson, ToJson, Inhabited

structure Response where
  jsonrpc : String := "2.0"
  id      : Json
  result  : Option Json := none
  error   : Option ErrorResponse := none
  deriving FromJson, ToJson, Inhabited

structure Notification where
  jsonrpc : String := "2.0"
  method  : String
  params  : Option Json := none
  deriving FromJson, ToJson, Inhabited

inductive Message where
  | request (req : Request)
  | response (res : Response)
  | notification (notif : Notification)
  deriving Inhabited

instance : FromJson Message where
  fromJson? json := do
    let id? := match json.getObjVal? "id" with
      | Except.ok idVal => some idVal
      | Except.error _ => none
    let method? := match json.getObjVal? "method" with
      | Except.ok (Json.str m) => some m
      | _ => none

    match id?, method? with
    | some id, some method =>
      let jsonrpc := match json.getObjVal? "jsonrpc" with
        | Except.ok (Json.str s) => s
        | _ => "2.0"
      let params := match json.getObjVal? "params" with
        | Except.ok p => some p
        | Except.error _ => none
      return Message.request { jsonrpc := jsonrpc, id := id, method := method, params := params }
    | some id, none =>
      let jsonrpc := match json.getObjVal? "jsonrpc" with
        | Except.ok (Json.str s) => s
        | _ => "2.0"
      let result := match json.getObjVal? "result" with
        | Except.ok r => some r
        | Except.error _ => none
      let error? := match json.getObjVal? "error" with
        | Except.ok errJson => match fromJson? errJson with
          | Except.ok err => some err
          | Except.error _ => none
        | _ => none
      return Message.response { jsonrpc := jsonrpc, id := id, result := result, error := error? }
    | none, some method =>
      let jsonrpc := match json.getObjVal? "jsonrpc" with
        | Except.ok (Json.str s) => s
        | _ => "2.0"
      let params := match json.getObjVal? "params" with
        | Except.ok p => some p
        | Except.error _ => none
      return Message.notification { jsonrpc := jsonrpc, method := method, params := params }
    | _, _ => Except.error "Invalid JSON-RPC message"

instance : ToJson Message where
  toJson
    | Message.request req => toJson req
    | Message.response res => toJson res
    | Message.notification notif => toJson notif

end LeanMCP
