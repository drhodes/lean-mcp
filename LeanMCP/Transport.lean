import Lean
import LeanMCP.JsonRpc

open Lean

namespace LeanMCP

-- Thread-safe spinlock using Lean's atomic IO.Ref operations
structure Lock where
  ref : IO.Ref Bool

def newLock : IO Lock := do
  let ref ← IO.mkRef false
  return { ref := ref }

partial def Lock.acquire (l : Lock) : IO Unit := do
  let locked ← l.ref.modifyGet (fun val => (val, true))
  if locked then
    IO.sleep 1  -- Yield and wait 1ms
    l.acquire
  else
    pure ()

def Lock.release (l : Lock) : IO Unit := do
  l.ref.set false

structure StdIOTransport where
  stdin  : IO.FS.Stream
  stdout : IO.FS.Stream
  lock   : Lock

def newStdIOTransport : IO StdIOTransport := do
  let stdin ← IO.getStdin
  let stdout ← IO.getStdout
  let lock ← newLock
  return { stdin := stdin, stdout := stdout, lock := lock }

partial def StdIOTransport.readMessage (t : StdIOTransport) : IO (Option Message) := do
  let line ← t.stdin.getLine
  if line.isEmpty then
    return none
  let trimmed := line.trimAscii
  if trimmed.isEmpty then
    t.readMessage
  else
    match Json.parse trimmed.toString with
    | Except.error err =>
      IO.eprintln s!"Error parsing JSON-RPC line: {err}"
      t.readMessage
    | Except.ok json =>
      match fromJson? json with
      | Except.error err =>
        IO.eprintln s!"Error decoding JSON-RPC message: {err}"
        t.readMessage
      | Except.ok msg =>
        return some msg

def StdIOTransport.sendMessage (t : StdIOTransport) (msg : Message) : IO Unit := do
  let json := toJson msg
  let raw := json.compress
  t.lock.acquire
  try
    t.stdout.putStrLn raw
    t.stdout.flush
  finally
    t.lock.release

end LeanMCP
