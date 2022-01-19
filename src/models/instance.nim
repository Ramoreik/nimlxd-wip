import lxd
import std/json
import monkeypatch/httpclient

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
