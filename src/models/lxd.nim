import uri
import instance
import constants
import std/[strformat, strutils, json, os]
import monkeypatch/httpclient

type 
    LXDClient* = object
        client*: HttpClient


proc newLXDClient*(): LXDClient =
    var c = newHttpClient()
    c.headers = newHttpHeaders({"Content-Type": "application/json"})
    return LXDClient(client: c)


proc interact*(lxdc: LXDClient, endpoint: string|Uri,
               m: HttpMethod, body: string): Response =
    echo fmt"[#] {endpoint} - {m}"
    echo fmt"[?] REQ : " & "\n" & body
    let r = lxdc.client.request(
        parseUri(SOCK) / $endpoint,
        httpMethod = m,
        body = body 
    )
    if r.status != Http202 and r.status != Http200:
        echo "[!!] ERROR: " & r.status & "\n" & r.body
    echo "[?] RES: \n" & r.body
    return r


proc wait(lxdc: LXDClient, operation: string) =
    echo fmt"[?] Waiting for operation : {operation}"
    discard lxdc.interact(
        parseUri(operation) / "wait" ? {"timeout": "15"},
            HttpGet, "{}")

proc create*(lxdc: LXDClient, i: Instance) = 
    let content = %*
        {
            "name": i.name,
            "source": {
                "type": i.kind,
                "protocol": DOWNLOAD_PROTOCOL,
                "server": IMAGES_REMOTE_SERVER,
                "alias": i.alias
            }
        }   
    let r = lxdc.interact(INSTANCES_ENDPOINT, HttpPost, $content)
    let operation = parseJson(r.body){"operation"}.getStr()
    lxdc.wait(operation)


proc delete*(lxdc: LXDClient, i: Instance) = 
    let r = lxdc.interact(
        parseUri(INSTANCES_ENDPOINT) / i.name,
            HttpDelete, "{}")
    let operation = parseJson(r.body){"operation"}.getStr()
    lxdc.wait(operation)


proc changeState(lxdc: LXDClient, i: Instance, action: string,
                 force=false, stateful=false, timeout=90) =
    let content = %*
        {
            "action": action,
            "force": force,
            "stateful": stateful,
            "timeout": timeout
        }
    let r = lxdc.interact(
        INSTANCES_STATE_ENDPOINT % [i.name],
        HttpPut,
        $content
    )
    let operation = parseJson(r.body){"operation"}.getStr()
    lxdc.wait(operation)

proc start*(lxdc: LXDClient, i: Instance) =
    lxdc.changeState(i, "start")

proc stop*(lxdc: LXDClient, i: Instance) =
    lxdc.changeState(i, "stop")

proc restart*(lxdc: LXDClient, i: Instance) =
    lxdc.changeState(i, "restart")

proc freeze*(lxdc: LXDClient, i: Instance) =
    lxdc.changeState(i, "freeze")

proc unfreeze*(lxdc: LXDClient, i: Instance) =
    lxdc.changeState(i, "unfreeze")

proc log*(lxdc: LXDClient, i: Instance, project = ""): string =
    let r = lxdc.interact(
        parseUri(INSTANCES_CONSOLE_ENDPOINT % [i.name]) ? {"project": project},
        HttpGet, "{}")
    return r.body

proc clear*(lxdc: LXDClient, i: Instance, project = "") =
    discard lxdc.interact(
        parseUri(INSTANCES_CONSOLE_ENDPOINT % [i.name]) ? {"project": project},
        HttpDelete, "{}")
 
proc backups*(lxdc: LXDClient, i: Instance, project = ""): JsonNode =
    let r = lxdc.interact(
        parseUri(INSTANCES_BACKUPS_ENDPOINT % [i.name]) ? {"project": project},
        HttpGet, "{}")
    let rjson = try : 
        parseJson(r.body)
    except:
        %*"{}"
    return rjson

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
    let r = lxdc.interact(
        parseUri(INSTANCES_BACKUPS_ENDPOINT % [i.name]) ? {"project": project},
        HttpGet, "{}")
    let rjson = try : 
        parseJson(r.body)
    except:
        %*"{}"
    return rjson


proc newInstance*(name="", kind="image", alias="kali", description="Default Instance"): Instance =
    return Instance(
        name: name,
        kind: kind, 
        alias: alias, 
        description: description
    )
