import std/[json, strutils, strformat, os, tables]
import models/[lxd, instance, constants, profile]
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

proc main() =
    echo "[#] - - NimLXD -- >>--:>"
    echo "[#] Creating LXDC -"
    var lxdc = newLXDClient()
    var instance = newInstance(name="dev-xyz", alias="ubuntu/xenial/cloud")

    echo "[#] Creating Instance -"
    echo lxdc.create(instance).pretty()

    echo "[#] Starting Instance -"
    echo lxdc.start(instance).pretty()

    echo "[#] Executing - {whoami} -"
    let (stdout, stderr) = lxdc.exec(
            instance,
            command = @["cat", "/etc/passwd"],
            record_output=true
         )

    echo "[#] STDOUT : \n"
    echo stdout

    echo "[#] STDERR : \n"
    echo stderr

    echo "[#] Creating backup - "
    echo lxdc.backup(instance, name = "dev-syz-bkp-1").pretty()


    echo "[#] Listing backups -"
    echo lxdc.backups(instance).pretty()


    # necessary even if im waiting for the operation to finish.
    # gotta figure out why :(
    sleep(1000)

    echo "[#] Fetching logs -"
    let logs = lxdc.log(instance){"content"}
    if logs != nil:
        echo logs.getStr()

    echo "[#] Clearing logs - "
    echo lxdc.clear(instance).pretty()

    echo "[#] Stop Instance -"
    echo lxdc.stop(instance).pretty()

    echo "[#] Deleting Instance"
    echo lxdc.delete(instance).pretty()


proc test_profile() =
    let lxdc = newLXDClient()
    let p = newProfile(
        "flask",
        config = {
            "user.user-data": """
#cloud-config
package_update: true
packages:
  - python3
  - python3-pip
runcmd:
  - pip install flask
  - bash /setup.d/entrypoint.sh
            """
        }.toTable,
        devices = {
            "eth0": {
              "name": "eth0",
              "network": "lxdbr0",
              "type": "nic"
            }.toTable,
            "root": {
              "type": "disk",
              "path": "/",
              "pool": "default"
            }.toTable
        }.toTable)
    echo lxdc.create(p).pretty()

    echo "[#] Creating + Starting instance"
    let i = newInstance(name = "test", profiles = @["flask"])
    echo lxdc.create(i).pretty()
    echo lxdc.start(i).pretty()

    sleep(1000)

    echo "[#] Stop + Delete instance .."
    echo lxdc.stop(i).pretty()
    echo lxdc.delete(i).pretty()

    echo "[#] Delete profile .."
    echo lxdc.delete(p).pretty()



when isMainModule:
    test_profile()
    # main()


