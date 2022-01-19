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


proc interact*(lxdc: LXDClient, endpoint: string,
               m: HttpMethod, body: string): Response =
    echo fmt"[#] {endpoint} - {m}"
    echo fmt"[?] REQ : " & "\n" & body
    let r = lxdc.client.request(
        SOCK & endpoint,
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
        operation & "/wait", HttpGet, "{}")


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
    sleep(200)


proc start*(lxdc: LXDClient, i: Instance) =
    let content = %*
        {
            "action": "start"
        }
    let r = lxdc.interact(
        INSTANCES_STATE_ENDPOINT % [i.name],
        HttpPut,
        $content
    )
    let operation = parseJson(r.body){"operation"}.getStr()
    lxdc.wait(operation)


proc newInstance*(name="", kind="image", alias="kali", description="Default Instance"): Instance =
    return Instance(
        name: name,
        kind: kind, 
        alias: alias, 
        description: description
    )
