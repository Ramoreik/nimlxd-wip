import parser
import monkeypatch/httpclient
import constants
import parsetoml
import lxd
import std/[uri, strutils, strformat, json, tables]

type 
    Instance* = object
        name*: string   
        config*: Table[string, string]
        kind*: string
        alias*: string
        description*: string    
        profiles*: seq[string]
        architecture*: string   
        devices*: Table[string, Table[string, string]]
        ephemeral*: bool
        status*: string
        location*: string
        status_code*: string
        create_at*: string  
        last_used_at*: string


proc createJson*(i: Instance): JsonNode =
    return %*
        {
            "name": i.name,
            "description": i.description,
            "ephemeral": i.ephemeral,
            "profiles" : i.profiles,
            "source": {
                "type": i.kind,
                "protocol": DOWNLOAD_PROTOCOL,
                "server": IMAGES_REMOTE_SERVER,
                "alias": i.alias
            }
        }  

proc newInstance*(name="", kind="image", alias="kali/current/cloud",
                  description="Default Instance", ephemeral=false, profiles: seq[string] = @[],
                  devices={"root": {"path": "/", "pool": "default", "type": "disk"}.toTable}.toTable): Instance =
    return Instance(
        name: name,
        kind: kind, 
        alias: alias, 
        description: description,
        devices: devices,
        profiles: profiles,
        ephemeral: ephemeral
    )


proc newInstance*(config: TomlValueRef): Instance = 
    let profiles = config{"profiles"}.getElems()
    let devices = config{"devices"}
    return Instance(
        name: config{"name"}.getStr("default"),
        kind: config{"kind"}.getStr("image"),
        alias: config{"alias"}.getStr("kali/current/cloud"),
        description: config{"description"}.getStr(),
        devices: @devices,
        profiles: @profiles,
        ephemeral: config{"ephemeral"}.getBool()
    )


proc get*(lxdc: LXDClient, i: Instance): JsonNode =
    return lxdc.interact(
        parseUri(INSTANCES_ENDPOINT) / i.name, HttpGet, blocking = true)


proc create*(lxdc: LXDClient, i: Instance): JsonNode = 
    ## Create the specified instance
    let content = i.createJson()
    return lxdc.interact(
        INSTANCES_ENDPOINT, HttpPost, $content, blocking = true)



proc create*(lxdc: LXDClient, instances: seq[Instance]) =
  for i in instances:
    discard lxdc.create(i)



proc delete*(lxdc: LXDClient, i: Instance): JsonNode = 
    ## Delete the specified instance
    return lxdc.interact(
        parseUri(INSTANCES_ENDPOINT) / i.name, HttpDelete, "{}", blocking=true)


proc delete*(lxdc: LXDClient, instances: seq[Instance]) =
  for i in instances:
    discard lxdc.delete(i)


proc changeState(lxdc: LXDClient, i: Instance, action: string,
                 force=false, stateful=false, timeout=90): JsonNode =
    ## Change state of the given instance according to the provided action.
    let content = %*
        {
            "action": action,
            "force": force,
            "stateful": stateful,
            "timeout": timeout
        }
    return lxdc.interact(
        INSTANCES_STATE_ENDPOINT % [i.name],
        HttpPut,
        $content,
        blocking = true
    )


proc start*(lxdc: LXDClient, i: Instance): JsonNode =
    result = lxdc.changeState(i, "start")


proc start*(lxdc: LXDClient, instances: seq[Instance]) =
  for i in instances:
    discard lxdc.start(i)


proc stop*(lxdc: LXDClient, i: Instance): JsonNode =
    result = lxdc.changeState(i, "stop")


proc stop*(lxdc: LXDClient, instances: seq[Instance]) =
  for i in instances:
    discard lxdc.stop(i)


proc restart*(lxdc: LXDClient, i: Instance): JsonNode =
    result = lxdc.changeState(i, "restart")


proc freeze*(lxdc: LXDClient, i: Instance): JsonNode =
    result = lxdc.changeState(i, "freeze")


proc unfreeze*(lxdc: LXDClient, i: Instance): JsonNode =
    result = lxdc.changeState(i, "unfreeze")


proc exec*(lxdc: LXDClient, i: Instance, project = "", 
            command: seq[string] = @["whoami"], cwd = "/",
            environment: Table[string, string] = {"foo": "bar"}.toTable,
            user = 1000, group = 1000,
            height = 24, width = 80,
            interactive = false, record_output = false,
            wait_for_websocket = false): (string, string) =
    ## Executes a command on the given instance, returns stderr and stdout
    let content = %*
        {
          "command": command, 
          "cwd": cwd,
          "environment": environment,
          "group": group,
          "height": height,
          "interactive": interactive,
          "record-output": record_output,
          "user": user,
          "wait-for-websocket": wait_for_websocket,
          "width": width
        }
    let output = lxdc.interact(
                parseUri(INSTANCES_EXEC_ENDPOINT % [i.name]) ? {"project": project},
                HttpPost, $content, blocking = true){"metadata"}{"metadata"}{"output"}
    let stdout = lxdc.reqapi(parseUri(output{"1"}.getStr()), HttpGet, "{}").body
    let stderr = lxdc.reqapi(parseUri(output{"2"}.getStr()), HttpGet, "{}").body
    return (stdout, stderr) 


proc log*(lxdc: LXDClient, i: Instance, project = ""): JsonNode =
    ## Fetch logs for the given instance
    return lxdc.interact(
        parseUri(INSTANCES_CONSOLE_ENDPOINT % [i.name]) ? {"project": project},
        HttpGet, "{}")


proc clear*(lxdc: LXDClient, i: Instance, project = ""): JsonNode =
    ## Clears logs for the given instance
    return lxdc.interact(
        parseUri(INSTANCES_CONSOLE_ENDPOINT % [i.name]) ? {"project": project},
        HttpDelete, "{}")

 
proc backups*(lxdc: LXDClient, i: Instance, project = ""): JsonNode =
    ## Returns the JsonNode containing a list of backups
    return lxdc.interact(
        parseUri(INSTANCES_BACKUPS_ENDPOINT % [i.name]) ? {"project": project},
        HttpGet, "{}")


proc backup*(lxdc: LXDClient, i: Instance,
            project = "", compression_algorithm = "gzip", container_only = false,
            expires_at = "", instance_only = false, name = "backup0",
            optimized_storage = true): JsonNode =
    ## Creates a backup returns the JsonNode for the response
    let content = %* 
        {
            "compression_algorithm": compression_algorithm,
            "container_only": container_only,
            "expires_at": expires_at,
            "instance_only": instance_only,
            "name": name,
            "optimized_storage": optimized_storage
        }
    return lxdc.interact(
        parseUri(INSTANCES_BACKUPS_ENDPOINT % [i.name]) ? {"project": project},
        HttpPost, $content)


proc rmbackup*(lxdc: LXDClient, i: Instance, backup: string): JsonNode =
    ## Delete the specified backup for the given instance.
    return lxdc.interact(
        parseUri(INSTANCES_ENDPOINT) / i.name,
            HttpDelete, "{}", blocking = true)
