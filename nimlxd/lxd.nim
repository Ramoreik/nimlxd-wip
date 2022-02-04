import constants
import monkeypatch/httpclient
import std/[uri, strformat, json]

type 
    ## LXDC
    ## Simple LXDC client using the monkeypatched httpclient with http+unix support.
    LXDClient* = object
        client: HttpClient
        api*: string


proc newLXDClient*(api: string = SOCK): LXDClient =
    var c = newHttpClient()
    c.headers = newHttpHeaders({
        "Content-Type": "application/json",
        "User-Agent": "NimLXD/0.2.0"
    })
    return LXDClient(client: c, api: api)


proc reqapi*(lxdc: LXDClient, endpoint: string|Uri,
         m: HttpMethod, body: string): Response = 
    ## Interact with the API and returns the raw Response object
    let r = lxdc.client.request(
        parseUri(lxdc.api) / $endpoint,
        httpMethod = m,
        body = body 
    )
    if r.status != Http202 and r.status != Http201 and r.status != Http200:
        echo "[!!] ERROR: " & r.status & "\n" & r.body
    return r


proc interact*(lxdc: LXDClient, endpoint: string|Uri,
               m: HttpMethod = HttpGet, body: string = "{}",
               blocking = false): JsonNode =
    ## Interact with API and returns the JsonNode response of the server
    echo fmt"[#] {endpoint} - {m}"
    echo fmt"[?] REQ : " & "\n" & parseJson(body).pretty()
    var r = lxdc.reqapi(endpoint, m, body)
    if blocking:
        let operation = parseJson(r.body){"operation"}.getStr()
        r = lxdc.wait(operation)
    result = try : 
        parseJson(r.body)
    except:
        %*{"content": r.body}
    return result


proc wait*(lxdc: LXDClient, operation: string): Response =
    ## Wait for action to complete using operation/<id>/wait
    echo fmt"[?] Waiting for operation : {operation}"
    return lxdc.reqapi(
        parseUri(operation) / "wait" ? {"timeout": "15"},
            HttpGet, "{}")
