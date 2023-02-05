#!/usr/bin/env python

import sys
import string
import os
import glob
import textwrap
import re
from pprint import pprint

noConstPtr = False
PRINT_STRUCT = False

kernelA = re.compile("([^<]+)[<]*([^>]*)[>]*")
def get_nim_arraytype( c_type, rename = {} ):
    mo = re.match( '(.*)\[\s*(\d*)\s*\]', c_type )
    if not mo: return c_type
    etype = mo.group( 1 )
    count = mo.group( 2 )
    if count == '':
        return f'ptr {get_nim_type( etype, rename )}'
    else:
        return f'array[{count},{get_nim_type( etype, rename )}]'

def get_nim_proctype( c_type, rename = {} ):
    #TODO: proper proc type
    mo = re.match( '(.*)\s*\(\*\)\((.*)\)', c_type )
    rtype = mo.group(1)
    inner = mo.group(2)
    
    out = "proc("
    count = 0
    # print( c_type )
    if len(inner) > 0:
        for x in inner.split(","):
            if count > 0:
                out = out + ','
            out = out + f'arg_{count}:{get_nim_type(x)}'
            count += 1
    
    if rtype != "void":
        out = out + f'):{get_nim_type( rtype )}' + '{.cdecl}'
    else:
        out = out + ')' + '{.cdecl}'
    return out

def get_nim_type( c_type, rename = {}, returnType = False ):   
    c_type = c_type.strip()
    if c_type.endswith( "]" ):
        return get_nim_arraytype( c_type, rename )

    isVar = True
    isConst = False

    if c_type in ["const void *"]:
        return "ConstPointer"

    if c_type.endswith("const *"):
        isConst = True
        c_type = c_type[:-7]+"*"
        
    if c_type.startswith("class "):
        c_type = c_type[5:].strip()

    if c_type.startswith("const "):
        c_type = c_type[5:].strip()
        isConst = True
        isVar = False

    if not c_type.endswith("&"):
        isVar = False
    else:
        c_type = c_type[:-1]

    c_type = c_type.strip()

    if c_type in ["void *"]:
        return "pointer"
    if c_type in ["long"]:
        return "clong"
    if c_type in ["unsigned long"]:
        return "culong"
    if c_type in ["short"]:
        return "cshort"
    if c_type in ["int"]:
        return "cint"
    if c_type in ["size_t"]:
        return "csize_t"    
    if c_type in ["long long"]:
        return "clonglong"              
    #if c_type in ["signed", "unsigned"]:
    #    return "cint"
    if c_type in ["long double"]:
        return "clongdouble" 
    if c_type in ["float"]:
        return "cfloat"        
    if c_type in ["double *"]:
        return "ptr cdouble"
    if c_type in ["double"]:
        return "cdouble"
    if c_type in ["char *"]:
        if isVar:
            return "cstring"
        else:
            if isConst:
                return "ccstring"
            else:
                return "cstring"

    if c_type in ["char"]:
        return "cchar"
    if c_type in ["signed char"]:
        return "cschar"
    if c_type in ["unsigned char"]:
        return "uint8"
    if c_type in ["unsigned short"]:
        return "uint16"
    if c_type in ["unsigned int"]:
        return "cuint"
    if c_type in ["unsigned long long"]:
        return "culonglong"
    if c_type in ["char**"]:
        return "cstringArray"

    if isVar:
        c_type = f"var {c_type}"

    c_type = c_type.replace("enum ", "")
    c_type = c_type.replace("struct ", "")

    if "(*)" in c_type:
        return get_nim_proctype( c_type, rename )
    # xxxx::yyyy<zzzzz> TODO: MODIFY <map>, [K]
    if "::" in c_type:
        _a, _b = kernelA.findall(c_type)[0]
        _tmp = _a.split("::")[-1]        
        #for _repeatedTypes, _list in repeated.items():
        #    if _tmp == _repeatedTypes:
        #        _tmp = ".".join( _a.split("::")[-2:] )
        #if c_type == "Array::Type":
        for somename in rename.keys():
            if somename.endswith( _a ):
                _tmp = rename[somename]
        #if _a in rename:
        #    _tmp = rename[_a]


        #my_dict["type"][_tmp] = "#" + f'{_tmp}* {{.importcpp: "{_a}", header: "<map>".}} [K] = object'
        # if _tmp.endswith( "const*" ):
        #     _tmp = _tmp[0:-5] + "*"
        # _tmp = _tmp.replace( "*const ", "*" )
        # _tmp = _tmp.replace( "enum ", " " )
        # _tmp = _tmp.replace( "struct ", " " )

        while _tmp[-1] == "*":
            _tmp = f"ptr {_tmp[:-1]}"
        
        if _b != "":
            # There may be several types
            _b = _b.split(", ")
            _b = [get_nim_type(_i, rename) for _i in _b]
            for idx in range(len(_b)):
                if _b[idx][-1] == "*":
                    _b[idx]  = f"ptr {_b[idx][:-1].strip()}"
            _b = ",".join(_b)
            _b = f"[{_b}]"
        c_type = f"{_tmp}{_b}"
        c_type =  get_nim_type( c_type, rename, True )
        if returnType and isConst:
            if c_type.startswith("ptr "):
                return f"ConstPtr[{c_type[4:]}]"
            else:
                return c_type
                # return f"ConstPtr[{c_type}]"
        else:
            return c_type

    if "<" in c_type and ">" in c_type:
        c_type = c_type.replace("<", "[")
        c_type = c_type.replace(">", "]")

    c_type = c_type.strip()
    if c_type:
        while c_type[-1] == "*":
            c_type = f"ptr {c_type[:-1]}"


    if c_type.startswith( "ptr float" ):
        c_type = "ptr cfloat"

    if c_type.startswith( "ptr Char" ):
        c_type = "cstring"

    if c_type.startswith( "ptr ptr void" ):
        c_type = "ptr pointer"

    if returnType and isConst:
        if c_type.startswith("ptr "):
            return f"ConstPtr[{c_type[4:]}]"
            
    return c_type

NIM_KEYWORDS = ["addr", "array", "and", "as", "asm", "bind", "block", "break",
                "case", "cast", "concept", "const", "continue", "converter",
                "defer", "discard", "distinct", "div", "do", "elif", "else",
                "end", "enum", "except", "export", "finally", "for", "from",
                "func", "if", "import", "in", "include", "interface", "is",
                "isnot", "iterator", "let", "macro", "method", "mixin", "mod",
                "nil", "not", "notin", "object", "of", "or", "out", "proc", "ptr",
                "raise", "ref", "return", "shl", "shr", "static", "template",
                "try", "tuple", "type", "using", "var", "when", "while", "xor",
                "yield"]

def clean(txt):
    txt = txt.replace("const", "")
    txt = txt.strip()
    if txt[-2:] == " &":
        txt = txt[:-2]
    if txt[0] == "_":
        # txt = txt[1:]
        txt = "v_" + txt[1:]
    if txt in NIM_KEYWORDS:
        txt = f"`{txt}`"
    return txt
#----------- EXPORTING  

def export_params(params, rename = {}):
    _params = ""
    n = 0
    for p in  params:
        if n > 0:
            _params += ", "
        if p[0]:
            _params += clean(p[0]) + ": "
        else:
            _params += f'a{n:02d}: '

        _type = get_nim_type(p[1], rename)
        if len(p) > 2 and not _type.startswith("array"):
            if p[2] != None:
                p2 = p[2]
                if _type.endswith("Enum") and p2 != "nil":
                    p2 = _type + "." + p[2]
                p2 = p2.replace("|"," or ")
                p2 = p2.replace("||"," or ")
                p2 = p2.replace("&"," and ")
                p2 = p2.replace("&&"," and ")
                _type += f" = {p2}"

        _params += _type
        n += 1
    return _params 

def get_comment(data, n = 4):
    spc = " " * n
    _tmp = ""
    _comment = data["comment"]
    if  _comment != None:
        _comment = textwrap.fill(_comment, width=70).split("\n")
        for i in _comment:
            _tmp += f"{spc}## {i}\n"
    return _tmp

def get_template_parameters(methodname):  # ÑAPA
    if '<' in methodname and '>' == methodname[-1]:
        _a, _b = methodname.split('<')
        _b = _b[:-1]
        return (_a, f"[{_b}]")
    else:
        return(methodname, '')

def export_params_for_constructor(params, rename = {}):
    output = []
    n = 0
    for p in params:
        _part = ""
        _hasDefault = False
        if n > 0:
            _part += ", "
        if p[0]:
            _part += clean(p[0]) + ": "
        else:
            _part += f'a{n:02d}: '
        _type = get_nim_type(p[1], rename)
        # print( p )
        if len(p) > 2:
            if p[2] != None:
                _hasDefault = True
        _part += _type
        output.append( ( _part, _hasDefault ) )
        n += 1
    return output 

def get_constructor(data,rename = {}, _dup={}):
    _paramParts = export_params_for_constructor(data["params"], rename)
    _tmp = ""
    methodname, templateparams = get_template_parameters(data["name"])
    if len(_paramParts) == 0:
        # no args
        _tmp = f'proc new{methodname}*{templateparams}(): {data["class_name"]} {{.constructor,importcpp: "{data["fully_qualified"]}".}}\n'
        _tmp += get_comment(data)  + "\n"
    else:
        #workaround for constant expr default parameters\
        _paramsTest = export_params(data["params"], rename)   
        # print("constructor", data["class_name"], _paramsTest )

        n = len( _paramParts )
        k = 0
        added = False
        for r in range( n-1, 0, -1 ):
            _outputparts = [ part[0] for part in _paramParts[0:r+1]]
            _params = "".join( _outputparts )
            _proc = f'proc new{methodname}*{templateparams}({_params}): {data["class_name"]} {{.constructor,importcpp: "{data["fully_qualified"]}(@)".}}\n'
            if not _dup.get( _proc, None ):
                _dup[_proc] = True
                _tmp += _proc
                added = True
            if not _paramParts[r][1]: 
                # print("END at", _paramParts[r])
                break
        if added:
            _tmp += get_comment(data)  + "\n"

    return _tmp    

def get_method(data, rename = {}, visited=None, varargs={} ):
    # Parameters
    # print(data["params"])
    rawparams = data["params"]
    hasValist = False
    if len(rawparams) > 0:
        lastType = rawparams[len(rawparams)-1][1]
        if lastType == "va_list":
            hasValist = True
            rawparams=rawparams[0:len(rawparams)-1]

    _params = export_params(rawparams, rename)
    # - Bear in mind the 'in-place' case
    _classname = "ptr " + data["class_name"]
    # if not data["const_method"]:
    #     _classname = f"var {_classname}"
    if not data["plain_function"]:
        _importMethod = "importcpp"
        _importName = data["name"]
        if _params != "":
            _params = f'self: {_classname},{_params}'
        else:
            _params = f'self: {_classname}'
    else:
        _importName = data["fully_qualified"]    
        _importMethod = "importc"

    isVararg = hasValist or (_importName in varargs)

    # Returned type
    _return = ""
    if data["result"] not in ["void"]:
        _result = data["result"].strip()
        # if _result.startswith("const "):
        #     _result = _result[6:]
        isRef = _result[-1] == "&"
        if isRef:
            _result = _result[:-1].strip()
        _result = get_nim_type( _result, rename, True )
        if isRef:
            _result = "var " + _result
        _return = f': {_result}'

    # Method name (lowercase the first letter)
    _methodName = data["name"]
    _methodName = _methodName[0].lower() + _methodName[1:]
    # _importName = data["name"]

    # Operator case
    _isOperator = False
    if _importName.startswith("`") and _importName.endswith("`"):
        _importName = _importName[1:-1]
        _importName = f"# {_importName} #"
        _isOperator = True
    
    # Templates
    _pragmas = ""
    _templParams = ""
    if "template_params" in data:
        if len(data["template_params"]) > 0:
            _templParams = "[" + ";".join( data["template_params"] ) + "]"
            
    _methodName = clean(_methodName)
    if isVararg:
        _pragmas += ", varargs"

    if _isOperator and _methodName in ["`=`"]:
        _tmp = f'proc assign*{_templParams}({_params})  {{.{_importMethod}: "{_importName}"{_pragmas}.}}\n'

    elif _isOperator and _methodName in ["`[]`"]:
        _importName = "#[#]"
        _tmp = f'proc {_methodName}*{_templParams}({_params}) {_return} {{.{_importMethod}: "{_importName}"{_pragmas}.}}\n'  

    elif _isOperator and _methodName in ["`()`"]:
        # continue #Ignore
        return False

    else:
        _tmp = f'proc {_methodName}*{_templParams}({_params}){_return}  {{.{_importMethod}: "{_importName}"{_pragmas}.}}\n'

    if _tmp in visited: return False
    visited.add( _tmp )
    _tmp += get_comment(data) + "\n"
    return _tmp

def get_typedef(name, data, include = None, rename={}):   # TODO: añadir opción si no está referenciado, comentar
    #_type = ""
    #if "underlying_deps" in data:
    #    print(data["underlying"])
    #else:
    _deftype = data["typedef_type"]
    if _deftype == "struct":
        return get_struct( name, data, include, rename )

    underlying =  data["underlying"]
    _type = get_nim_type( underlying, rename )
    _include = ""
    if include != None:
        _include = f'header: "{include}", '
    
    if _deftype == "function":
        # ActiveTextureProc* = proc (texture: GLenum)
        _return = ""
        if data["result"] not in ["void", "void *"]:
            _result = data["result"].strip()
            # if _result.startswith("const "):
            #     _result = _result[6:]
            if _result[-1] == "&":
                _result = _result[:-1].strip()
            _result = get_nim_type( _result, rename )
            _return = f': {_result}'        
        _params = export_params(data["params"], rename)
        #if _params != "":
        #    _params = ", ".join(_params)
        
        _tmp = f"proc ({_params}){_return} {{.cdecl.}}"
        _name = clean(name)
        # _name = _name[0].upper() + _name[1:]
        
        return f'  {_name}* {{.{_include}importcpp: "{data["fully_qualified"]}".}} = {_tmp}\n'

    # elif _deftype == "ref":
    #     _name = clean(name)  
    #     _name = _name[0].upper() + _name[1:]
    #     # _data["underlying"]
    #     if _type.startswith( 'struct ' ):
    #         _type = 'Struct' + _type[7:]
    #     return f'  {_name}* {{.{_include}importcpp: "{data["fully_qualified"]}".}} = {_type}\n'

    else:
        _name = clean(name)  
        # _name = _name[0].upper() + _name[1:]
        if _type.startswith( 'struct ' ):
            _type = _type[7:]

        if _name == _type: #ignore struct/typedef with same name
            return ''
        return f'  {_name}* {{.{_include}importcpp: "{data["fully_qualified"]}".}} = {_type}\n'
    #_data[_file]["typedefs"].append((i["name"], _type))

def get_class(name, data, include = None, byref = True, rename = {}, inheritable=False):
    #)
    _include = ""
    if include != None:
        _include = f'header: "{include}", '
    _byref = ", byref" 
    if not byref:
        _byref = ", bycopy"
    _inheritance = ""
    if len(data["base"]) > 0:
        _inheritance = " of "
        _inheritance += get_nim_type( data["base"][0], rename )   # Nim does not support multiple inheritance

    _nameClean = clean(name)
    _name = data["fully_qualified"]
    _template = ""

    if inheritable :
        _inheritable = "inheritable, "
    else:
        _inheritable = ""

    if len(data["template_params"]) > 0:
        _tmpList = []
        for i in data["template_params"]:
            #if name == "TemplateArray":
            #    print(i)
            #    pprint(rename)
            if type(i) == tuple:
                _tmp = i[0] + ":" + get_nim_type(i[1], rename )
                _tmpList.append(_tmp)
            else:
                _tmpList.append(i)
        _template = f'[{"; ".join(_tmpList)}]'

        #_template = f'[{", ".join(data["template_params"])}] '
    _tmp = f'  {_nameClean}*{_template} {{.{_inheritable}{_include}importcpp: "{_name}"{_byref}.}} = object{_inheritance}\n'
    _tmp += get_comment(data) + "\n"
    return _tmp    

def get_struct(name, data, include = None, rename={}, inheritable = False, nofield = False ):
    if data["incomplete" ]:
        return ''

    if name == "":
        return ''
    _include = ""
    if include != None:
        _include = f'header: "{include}", '
    _byref = ", byref" 

    _nameClean = clean(name)
    _name = data["fully_qualified"]
    # print( data )

    _inheritance = ""
    if len(data["base"]) > 0:
        _inheritance = " of "
        base = get_nim_type( data["base"][0], rename )
        _inheritance += base  # Nim does not support multiple inheritance

    _template = ""
    """
    if len(data["template_params"]) > 0:
        _tmpList = []
        for i in data["template_params"]:
            if type(i) == tuple:
                _tmp = i[0] + ":" + get_nim_type(i[1], rename)
                _tmpList.append(_tmp)
            else:
                _tmpList.append(i)
        _template = f'[{"; ".join(_tmpList)}]'

        #_template = f'[{", ".join(data["template_params"])}] '
    """
    #_tmp = f'  {_nameClean}*{_template} {{.{_include}importcpp: "{_name}"{_byref}.}} = object{_inheritance}\n'
    if inheritable :
        _inheritable = "inheritable, "
    else:
        _inheritable = ""

    _tmp = f'  {_nameClean}* {{.{_inheritable}{_include}importcpp: "{_name}".}} = object{_inheritance}\n'
    if PRINT_STRUCT:  print( '>>', name )
    if not nofield:
        for f in data["fields"]:
            if PRINT_STRUCT: print( " ..", f )
            fname = f["name"]
            if not fname: continue
            #TODO: anonymous inner struct
            if f["type"].startswith("struct "):continue
            fname = clean( fname )
            tname = get_nim_type( f["type"], rename )
            if fname.startswith("_"):
                continue
            if fname.endswith("_"):
                _tmp += f'    {fname[:-1]}* {{.importcpp:"{fname}".}}: {tname}\n'
            else:
                _tmp += f'    {fname}* : {tname}\n' 

    _tmp += get_comment(data) + "\n"
    return _tmp

def get_enum(name, data, include = None, rename = {}):
    _name = name.split("::")[-1]    
    if name in rename:
        _name = rename[name]


    _prefix = "" #remove_vowels( _name )

    _include = ""
    if include != None:
        _include = f'header: "{include}", '

    _type = get_nim_type(data["type"], rename)
    _type = f"size:sizeof({_type})"

    _itemsTxt = ""
    _items = data["items"]
    n = len(_items)
    for i in range(len(_items)):
        _i = _items[i]
        #print(_i)
        _itemsTxt += f'    {_prefix}{_i["name"]} = {_i["value"]}'            
        if i<n-1:
            _itemsTxt += ","
        _itemsTxt += "\n"
        if _i["comment"] != None:
            _itemsTxt += get_comment(_i, n=6)

    #_items = ", ".join(_items)

    _tmp = f'  {_name}* {{.{_type},{_include}importcpp: "{name}", pure.}} = enum\n'
    if data["comment"] != None:
        _tmp += get_comment(data) + "\n"
    _tmp += _itemsTxt + "\n"
    return _tmp 

def get_const(data, include = None):
    _tmp = ""
    for i in data["items"]:
        _tmp += f'  {i["name"]}* = {i["value"]}\n'
        if i["comment"] != None:
            _tmp += get_comment(data) + "\n"
    return _tmp

def get_root(_blob):
    # Case where a specific file is given (no blob)
    if "*" not in _blob and "?" not in _blob:
        _tmp = _blob.split("/")
        _out = ""
        for i in _tmp[:-1]:
            _out += i + "/"
        return _out
    # Blob case
    _tmp = _blob.split("/")
    _out = ""
    for i in _tmp:
        if "*" not in i:
            _out += i + "/"
    return _out

# def get_params_from_node(mynode):
#     _params = []
#     for i in mynode.get_children():
#         if i.kind == clang.cindex.CursorKind.PARM_DECL:
#             _paramName = i.displayname

#             _default = None
#             # Getting default values in params
#             for j in i.get_children():
#                 for k in j.get_children():                                  
#                     if k.kind == clang.cindex.CursorKind.UNEXPOSED_EXPR:
#                         for m in k.get_tokens():
#                             _default = m.spelling
#                     if k.kind == clang.cindex.CursorKind.INTEGER_LITERAL:
#                         try:
#                             _default = k.get_tokens().__next__().spelling 
#                         except:
#                             pass  
#             _params.append((i.displayname, i.type.spelling, _default))                                                          
#     return _params    

def fully_qualified(c):
    if c is None:
        return ''
    elif c.kind == clang.cindex.CursorKind.TRANSLATION_UNIT:
        return ''
    else:
        res = fully_qualified(c.semantic_parent)
        if res != '':
            return res + '::' + c.spelling
    return c.spelling

NORMAL_TYPES = ["void", "long", "unsigned long", "int", "size_t", "long long", "long double", 
                "float", "double", "char", "signed char", "unsigned char", "unsigned short", 
                "unsigned int", "unsigned long long", "char*", "bool" ]

def cleanit(tmp):
    if tmp.startswith("const "):
        tmp = tmp[6:]
    if tmp[-1] in ["&", "*"]:
        tmp = tmp[:-2]    
    return tmp

def get_nodes(node,depth=0):
    """Traverse the AST tree
    """
    yield (depth, node)
    for child in node.get_children():
        yield from get_nodes(child, depth = depth+1)

def get_template_dependencies(tmp):
    result = []
    _tmp = cleanit(tmp)
    if _tmp[-1] == ">" and "<" in _tmp: # In case is based on a template
        _tmp = [i.split('>') for i in _tmp.split('<')]
        _tmp = flatten(_tmp)
        _tmp = [i.split(',') for i in _tmp]
        _tmp = flatten(_tmp)
        _tmp = [i.strip() for i in _tmp if i.strip() != '']
        _tmp = [cleanit(i) for i in _tmp if not i.isdigit()]
        result = _tmp           
    return result

def export_txt_option(option={}):
    global noConstPtr
    noConstPtr = option.get( 'no_const', None )

def export_txt(filename, data,  root= "/", rename = {}, ignore={}, ignorefields = [], inheritable={}, varargs={}):
    _txt = ""
    _txt += "import wrapping_tools\n"
    _txt += "import builtin_types\n"
    #if "AlphaFunc" in filename:
    #    _t = [i for i in data if "AlphaFunc" in i[0]]
    #    _t = [i for i in data if filename == i[0]]        
    #    pprint(_t)    
    #    print(filename)
    # Pragma
    _pragma = [i for i in data if i[0] == filename and i[2] == "pragma"]    
    for i in _pragma:
        _txt += i[4] + "\n\n"

    # Imports
    _imports = [i[3] for i in data if i[0] == filename and i[2] == "import"]
    #if len(_imports) > 0:
    for items in _imports:
        _items = [os.path.splitext( i )[0] for i in items]
        _tmp = ", ".join(_items)
        _txt += f"import {_tmp}\n"
        # _txt += f"export {_tmp}\n"
    if len( _imports ) > 0:
        _txt += "\n\n"
     

    #_consts = []
    #if "consts" in _data:
    #    _consts = _data["const"]
    #_filters = []
    #if "const" in _filter:
    #    _filters = _filter["const"]
    # Consts
    _consts = [i[3] for i in data if i[0] == filename and i[2] == "const"]    
    if len(_consts) > 0:
        _txt += "const\n"
    for i in _consts:
        _txt += get_const(i)
    if len(_consts) > 0:            
        _txt += "\n\n"


    #_n = len(_filter["enum"]) + len(_filter["typedef"]) + \
    #     len(_filter["class"]) + len(_filter["struct"])
    _n = [i for i in data if i[0] == filename and i[2] in ["enum", "class", "struct", "typedef"]] 
    #if (len(_data.get("typedefs",[])) + len(_data.get("classes", [])) + \
    #    len(_data.get("enums",[])) + len(_data.get("structs",[])) - _n) > 0:
    if len(_n) > 0:
        _txt += "type\n"

    # Enums
    _enums = [i for i in data if i[0] == filename and i[2] == "enum"] 
    for _, _filename, _, name, values in _enums:
        if ignore and ( name in ignore): continue
        # print( name, ignore )
        _fname = os.path.relpath( _filename, root )
        _txt += get_enum( name, values, _fname, rename = rename)


    _segment = ""
    _segmentPre = ""

    _structsPre = []
    # Structs
    _structs = [(i[1], i[3], i[4]) for i in data if i[0] == filename and i[2] == "struct"] 
    for _filename, name, values in _structs:
        if ignore and ( name in ignore): continue
        _fname = os.path.relpath( _filename, root )
        nofield = name in ignorefields
        if name in inheritable:
            _part = get_struct( name, values, _fname, rename = rename, inheritable = True, nofield = nofield )
            _structsPre.append( (name, _part ))
        else:
            _segment += get_struct( name, values, _fname, rename = rename, nofield = nofield) 

    _structsPre.sort( key = lambda x: inheritable.index(x[0]) )
    _segmentPre = "".join(x[1] for x in _structsPre)
    _txt += _segmentPre
    _txt += _segment

    _segment = ""
    _segmentPre = ""
    _classesPre = []
    # Classes
    _classes = [(i[1], i[3],i[4]) for i in data if i[0] == filename and i[2] == "class"]     
    for _filename, name, values in _classes:
        if ignore and ( name in ignore): continue
        _fname = os.path.relpath( _filename, root )
        if name in inheritable:
            _part = get_class( name, values, _fname, rename = rename, inheritable = True )
            _classesPre.append((name, _part))
        else:
            _segment += get_class( name, values, _fname, rename = rename)   

    _classesPre.sort( key = lambda x: inheritable.index(x[0]) )
    _segmentPre = "".join(x[1] for x in _classesPre)
    _txt += _segmentPre
    _txt += _segment
    _segment = ""
    _segmentPre = ""
    # Typedefs
    _typedefs = [(i[1], i[3],i[4]) for i in data if i[0] == filename and i[2] == "typedef"] 
    for _filename, name, values in _typedefs:
        if ignore and ( name in ignore): continue
        _fname = os.path.relpath( _filename, root )
        _txt += get_typedef(name, values, _fname, rename = rename)
    
    if len(_n) > 0:
        _txt += "\n\n"

    _n = [i for i in data if i[0] == filename and i[2] in ["constructor", "method"]]

    if len(_n) > 0:
        _fname = os.path.relpath( _n[0][1], root )        
        _txt += f'{{.push header: "{_fname}".}}\n\n'

    _constructors = [i for i in data if i[0] == filename and i[2] == "constructor"]
    _dup = {}
    for i in _constructors:
        _txt += get_constructor(i[4], rename, _dup)

    _methods = [i for i in data if i[0] == filename and i[2] == "method"]
    #if "AlphaFunc" in filename:
    #    print("dntro")
    #    pprint(_methods)
    #    pprint( [i for i in data if i[0] == filename ]  )
    _visited = set()
    for i in _methods:
        _m = get_method(i[4], rename, _visited, varargs )
        if _m:
            _txt += _m

    if len(_n) > 0:
        _fname = os.path.relpath( _n[0][1], root )        
        _txt += f'{{.pop.}}  # header: "{_fname}"\n'
    
    return _txt
