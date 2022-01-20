import json
import std/tables
import constants

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

