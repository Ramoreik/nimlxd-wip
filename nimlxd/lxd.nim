import monkeypatch/httpclient
import profile, instance, constants
import std/[uri, tables, strformat, strutils, json, os]

type 
    ## LXDC
    ## Simple LXDC client using the monkeypatched httpclient with http+unix support.
    LXDClient* = object
        client*: HttpClient


proc newLXDClient*(): LXDClient =
    var c = newHttpClient()
    c.headers = newHttpHeaders({
        "Content-Type": "application/json",
        "User-Agent": "NimLXD/0.1.0"
    })
    return LXDClient(client: c)


proc api(lxdc: LXDClient, endpoint: string|Uri,
         m: HttpMethod, body: string): Response = 
    ## Interact with the API and returns the raw Response object
    let r = lxdc.client.request(
        parseUri(SOCK) / $endpoint,
        httpMethod = m,
        body = body 
    )
    if r.status != Http202 and r.status != Http201 and r.status != Http200:
        echo "[!!] ERROR: " & r.status & "\n" & r.body
    return r


proc interact(lxdc: LXDClient, endpoint: string|Uri,
               m: HttpMethod = HttpGet, body: string = "{}",
               blocking = false): JsonNode =
    ## Interact with API and returns the JsonNode response of the server
    echo fmt"[#] {endpoint} - {m}"
    echo fmt"[?] REQ : " & "\n" & parseJson(body).pretty()
    var r = lxdc.api(endpoint, m, body)
    if blocking:
        let operation = parseJson(r.body){"operation"}.getStr()
        r = lxdc.wait(operation)
    result = try : 
        parseJson(r.body)
    except:
        %*{"content": r.body}
    return result


proc wait(lxdc: LXDClient, operation: string): Response =
    ## Wait for action to complete using operation/<id>/wait
    echo fmt"[?] Waiting for operation : {operation}"
    return lxdc.api(
        parseUri(operation) / "wait" ? {"timeout": "15"},
            HttpGet, "{}")


## Instance - - code will move eventually - -
proc get*(lxdc: LXDClient, i: Instance): JsonNode =
    return lxdc.interact(
        INSTANCES_ENDPOINT / i.name, HttpGet, blocking = true)


proc create*(lxdc: LXDClient, i: Instance): JsonNode = 
    ## Create the specified instance
    let content = i.createJson()
    return lxdc.interact(
        INSTANCES_ENDPOINT, HttpPost, $content, blocking = true)



proc create*(lxdc: LXDClient, instances: seq[Instance]): seq[Instance] =
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
    let stdout = lxdc.api(parseUri(output{"1"}.getStr()), HttpGet, "{}").body
    let stderr = lxdc.api(parseUri(output{"2"}.getStr()), HttpGet, "{}").body
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



## Profiles - - Code will move eventually - -
proc profiles*(lxdc: LXDClient): JsonNode =
    return lxdc.interact(
        parseUri(PROFILES_ENDPOINT), HttpGet)


proc get*(lxdc: LXDClient, p: Profile): JsonNode =
    return lxdc.interact(
        parseUri(PROFILES_ENDPOINT) / p.name, HttpGet)


proc create*(lxdc: LXDClient, p: Profile): JsonNode =
    return lxdc.interact(
        parseUri(PROFILES_ENDPOINT) ,
        HttpPost, $p.createJson(), blocking = true)


proc create*(lxdc: LXDClient, profiles: seq[Profile]) = 
    ## Delete a list of profiles
    for p in profiles:
        discard lxdc.create(p)


proc delete*(lxdc: LXDClient, p: Profile): JsonNode =
    return lxdc.interact(
        parseUri(PROFILES_ENDPOINT) / p.name,
        HttpDelete, blocking = true)


proc delete*(lxdc: LXDClient, profiles: seq[Profile]) = 
    for p in profiles:
        discard lxdc.delete(p)


proc rename*(lxdc: LXDClient, p: Profile, name: string): JsonNode =
    let content = %*{
        "name": name
    }
    return lxdc.interact(
        parseUri(PROFILES_ENDPOINT) / p.name,
        HttpPost, $content, blocking = true)


proc update*(lxdc: LXDClient, p: Profile): JsonNode =
    return lxdc.interact(
        parseUri(PROFILES_ENDPOINT) / p.name,
        HttpPut, $p.createJson(), blocking = true)


# Not tested
proc partial_update*(lxdc: LXDClient, p: Profile): JsonNode =
    return lxdc.interact(
        parseUri(PROFILES_ENDPOINT) / p.name,
        HttpPost, $p.createJson(), blocking = true)


