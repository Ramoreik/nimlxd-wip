import lxd, parser, constants,
       parsetoml, monkeypatch/httpclient
import std/[uri, json, tables]

type 
    Profile* = object
        name*: string    
        description*: string
        config*: Table[string, string]
        devices*: Table[string, Table[string, string]]
        used_by*: seq[string]


proc createJson*(p: Profile): JsonNode =
    return %*{
        "name": p.name,
        "description":  p.description,
        "config": p.config,
        "devices": p.devices,
        "used_by": p.used_by
    }

proc newProfile*(name: string, config: Table[string, string],
                devices: Table[string, Table[string, string]] = 
                    {"devices": {"name": "eth0", "network": "lxdbr0", "type":"nic"}.toTable}.toTable,
                description = "", used_by: seq[string] = @[] ): Profile =
    return Profile(
            name: name,
            description: description,
            config: config,
            devices: devices,
            used_by: used_by
        )

proc newProfile*(config: TomlValueRef): Profile = 
    let 
        devices = config{"devices"}
        used_by = config{"used_by"}.getElems()
        pconfig = config{"config"}.getTable()
    return Profile(
        name: config{"name"}.getStr("default"),
        description: config{"description"}.getStr(),
        config: @pconfig,
        devices: @devices,
        used_by: @used_by
    )


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


