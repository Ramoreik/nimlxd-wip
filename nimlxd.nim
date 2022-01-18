import httpclient_unixsocket_patched
import std/[json, strutils, strformat]

const SOCK = "http+unix://%2fvar%2fsnap%2flxd%2fcommon%2flxd%2funix.socket"
const LIST_ENDPOINT = "/1.0/instances"

#https://github.com/nim-lang/Nim/blob/version-1-6/lib/pure/httpcore.nim#L284

#[ 
    DISCLAIMER
    This is an extremely experimental Nim client for the LXD api.
    I had to monkey patch the httpclient.nim library to be able to interact in http+unix, without re-implementing or modifying other codebases extensively.

    I implement a check that enables the client to handle the http+unix:// scheme. 

    I check the scheme just before a client's socket is instantiated, if it matches, I get the path that is considered the hostname and use it to bind the unix socket. 
    *The path is urlencoded so the uri package will see it as a hostname.*
    Afterwards the httpclient handles the request normally and everything seems to work fine for my uses.

    This is until further notice, just a learning project.
    Im learning Nim as I go, if anything is horribly implemented, feel free to contribute or scold me.

    Below is just a simple creation + starting of an instance.
 ]# 

let instance = %*{
    "name": "NimLXD",
    "source": {
        "type": "image",
        "protocol": "simplestreams",
        "server": "https://images.linuxcontainers.org",
        "alias": "debian/sid"
        }
    }

let start = %*{
    "action": "start",
}

when isMainModule:
    echo "[#] Starting test"
    var client = newHttpClient()

    client.headers = newHttpHeaders({"Content-Type": "application/json"})

    echo "[#] Creating instance -"
    let response = client.request(SOCK & LIST_ENDPOINT, httpMethod = HttpPost,body = $instance)
    if response.status != Http202 and response.status != Http200:
        echo "[!!] ERROR: " & response.status & "\n" & response.body
    var instances = parseJson(response.body){"metadata"}{"resources"}{"instances"}

    echo "[#] Starting instance -"
    if instances != nil:
        var url = instances[0].getStr() & "/state"
        echo fmt"[?] URL: {url}"
        let r_start = client.request(SOCK & url, httpMethod = HttpPut, body = $start)
        if r_start.status != Http202 and r_start.status != Http200:
            echo "[!!] ERROR: " & response.status & "\n" & response.body
    else:
        echo "[!!] ERROR: No Instances in Response."

