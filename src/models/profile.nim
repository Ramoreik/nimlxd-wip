import json
import std/tables

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