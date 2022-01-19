import uri
import instance
import constants
import std/[tables, strformat, strutils, json, os]
import monkeypatch/httpclient

type 
    LXDClient* = object
        client*: HttpClient


proc newLXDClient*(): LXDClient =
    var c = newHttpClient()
    c.headers = newHttpHeaders({"Content-Type": "application/json"})
    return LXDClient(client: c)


proc api(lxdc: LXDClient, endpoint: string|Uri,
         m: HttpMethod, body: string): Response = 
    let r = lxdc.client.request(
        parseUri(SOCK) / $endpoint,
        httpMethod = m,
        body = body 
    )
    if r.status != Http202 and r.status != Http200:
        echo "[!!] ERROR: " & r.status & "\n" & r.body
    return r


proc interact*(lxdc: LXDClient, endpoint: string|Uri,
               m: HttpMethod, body: string, blocking = false): JsonNode =
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
    echo fmt"[?] Waiting for operation : {operation}"
    return lxdc.api(
        parseUri(operation) / "wait" ? {"timeout": "15"},
            HttpGet, "{}")



proc create*(lxdc: LXDClient, i: Instance): JsonNode = 
    let content = i.createJson()
    return lxdc.interact(
        INSTANCES_ENDPOINT, HttpPost, $content, blocking = true)

proc delete*(lxdc: LXDClient, i: Instance): JsonNode = 
    return lxdc.interact(
        parseUri(INSTANCES_ENDPOINT) / i.name, HttpDelete, "{}", blocking=true)

proc changeState(lxdc: LXDClient, i: Instance, action: string,
                 force=false, stateful=false, timeout=90): JsonNode =
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

proc stop*(lxdc: LXDClient, i: Instance): JsonNode =
    result = lxdc.changeState(i, "stop")

proc restart*(lxdc: LXDClient, i: Instance): JsonNode =
    result = lxdc.changeState(i, "restart")

proc freeze*(lxdc: LXDClient, i: Instance): JsonNode =
    result = lxdc.changeState(i, "freeze")

proc unfreeze*(lxdc: LXDClient, i: Instance): JsonNode =
    result = lxdc.changeState(i, "unfreeze")


# refactor
proc exec*(lxdc: LXDClient, i: Instance, project = "", 
            command: seq[string] = @["whoami"], cwd = "/",
            environment: Table[string, string] = {"foo": "bar"}.toTable,
            user = 1000, group = 1000,
            height = 24, width = 80,
            interactive = false, record_output = false,
            wait_for_websocket = false): (string, string) =
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
    return lxdc.interact(
        parseUri(INSTANCES_CONSOLE_ENDPOINT % [i.name]) ? {"project": project},
        HttpGet, "{}")


proc clear*(lxdc: LXDClient, i: Instance, project = ""): JsonNode =
    return lxdc.interact(
        parseUri(INSTANCES_CONSOLE_ENDPOINT % [i.name]) ? {"project": project},
        HttpDelete, "{}")

 
proc backups*(lxdc: LXDClient, i: Instance, project = ""): JsonNode =
    return lxdc.interact(
        parseUri(INSTANCES_BACKUPS_ENDPOINT % [i.name]) ? {"project": project},
        HttpGet, "{}")


proc backup*(lxdc: LXDClient, i: Instance,
            project = "", compression_algorithm = "gzip", container_only = false,
            expires_at = "", instance_only = false, name = "backup0",
            optimized_storage = true): JsonNode =
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


proc delete(lxdc: LXDClient, i: Instance, backup: string): JsonNode =
    return lxdc.interact(
        parseUri(INSTANCES_ENDPOINT) / i.name,
            HttpDelete, "{}", blocking = true)
