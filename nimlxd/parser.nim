import json
import parsetoml

#[ 
 ]#


proc `@`*(s: seq[TomlValueRef]): seq[string] =
    for el in s:
        result.add(el.getStr())


proc `@`*(s: TomlValueRef): Table[string, Table[string, string]] = 
    for k, v in pairs(s.getTable()):
        result[k] = initTable[string, string]()
        for k2, v2 in pairs(v.getTable()):
            result[k][k2] = v2.getStr()


proc `@`*(s: TomlTableRef): Table[string, string] = 
    for k, v in pairs(s):
        result[k] = v.getStr()
