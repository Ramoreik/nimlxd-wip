import json
import constants

type 
    Instance* = object
        name*: string   
        config*: string 
        kind*: string
        alias*: string
        description*: string    
        profiles*: string   
        architecture*: string   
        devices*: string    
        ephemeral*: string  
        expanded_config*: string    
        expanded_devices*: string   
        status*: string
        location*: string
        status_code*: string
        create_at*: string  
        last_used_at*: string

proc createJson(i: Instance): JsonNode =
    let content = %*
        {
            "name": i.name,
            "description": i.description,
            "ephemeral": i.ephemeral,
            "source": {
                "type": i.kind,
                "protocol": DOWNLOAD_PROTOCOL,
                "server": IMAGES_REMOTE_SERVER,
                "alias": i.alias
            }
        }  
    return content