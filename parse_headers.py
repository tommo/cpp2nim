#!/usr/bin/env python
""" Usage: call with <filename> <typename>
python cpp2nim.py "/usr/include/opencascade/gp_*.hxx" occt
python cpp2nim.py /usr/include/osg/Geode geode

python cpp2nim.py "/usr/include/osg/**/*" osg
python cpp2nim.py "/usr/include/osgViewer/**/*" osgViewer
>>> import clang.cindex
>>> index = clang.cindex.Index.create()
>>> tu = index.parse("/usr/include/opencascade/gp_Pnt.hxx", ['-x', 'c++',  "-I/usr/include/opencascade"], None, clang.cindex.TranslationUnit.PARSE_DETAILED_PROCESSING_RECORD)

clang -Xclang -ast-dump=json -x c++ -I/usr/include/osg -fsyntax-only /usr/include/osg/Geode  > geode.json

clang -Xclang -ast-dump -fno-diagnostics-color miniz.c
c2nim --cpp --header --out:gp_Pnt.nim /usr/include/opencascade/gp_Pnt.hxx

clang -Xclang -ast-dump -x c++ -I /usr/include/osg ./osg.hpp -fsyntax-only > osg.ast

"""

import sys
import clang.cindex
import string
import os
import glob
import textwrap
import re
from pprint import pprint
from pathlib import Path
import collections

PRINT_STRUCT = False

files = {}
def getCodeSpan( cursor ):
    filename = cursor.location.file.name
    extent = cursor.extent
    lines = files.get( filename, None )
    if lines == None:
        fp = open( filename, 'r' )
        lines = fp.readlines()
        files[filename] = lines
    output = ''
    lineIdx = extent.start.line - 1
    off0 = extent.start.column - 1
    off1 = extent.end.column - 1
    if extent.start.line < extent.end.line:
        off1 = -1
    l = lines[lineIdx]
    if off1 < 0:
        return l[off0:]
    else:
        return l[off0:off1]


def test_traverse(node, level):
    print('%s %-35s %-20s %-10s [%-6s:%s - %-6s:%s] %s %s ' % (' ' * level,
    node.kind, node.spelling, node.type.spelling, node.extent.start.line, node.extent.start.column,
    node.extent.end.line, node.extent.end.column, node.location.file, node.mangled_name))
    if node.kind == clang.cindex.CursorKind.CALL_EXPR:
        for arg in node.get_arguments():
            print("ARG=%s %s" % (arg.kind, arg.spelling))

    for child in node.get_children():
        test_traverse(child, level+1)

def print_line(node, field, spc, ident= 0):
    try:
        param = getattr(node, field)
        if callable(param):
            param = param()
        print(f"{spc}{field}: {param}")
        if isinstance( param, clang.cindex.Cursor):
            pp(_tmp, ident+ 4)
        elif isinstance(param, clang.cindex.Type):
            pptype(param, ident+4)

        elif hasattr(param,'__iter__'):#isinstance(param, collections.Iterable):
            pass
              
    except:
        print(f"{spc}{field}:  raises an exception!")    
        pass

def pptype(t, ident = 0):
    spc = " " * ident
    print(f"{spc}kind: ", node.kind) 
    print(f"{spc}spelling: ", node.spelling)    
    for i in dir(t):
        if not i.startswith("_") and i not in ["kind", "spelling"]:
            print_line(node, i, spc, ident)

def pp(node, ident = 0):
    """Pretty printer to inspect the nodes"""
    spc = " " * ident
    if ident == 0:
        print("======= TOP =======")
    else:
        print(f"{spc}------")
    print(f"{spc}kind: {node.kind}") 
    print(f"{spc}spelling: {node.spelling}" )
    for i in dir(node):
        if i not in ["kind", "spelling"] and not i.startswith("_"):
            print_line(node, i, spc, ident)   
    if ident == 0:
        print("======= BOTTOM =======")    
    else:
        print(f"{spc}------")

def flatten(L):
    if len(L) == 1:
        if type(L[0]) == list:
            result = flatten(L[0])   
        else:
            result = L
    elif type(L[0]) == list:
        result = flatten(L[0]) + flatten(L[1:])   
    else:
        result = [L[0]] + flatten(L[1:])
    return result

NIM_KEYWORDS = ["addr", "and", "as", "asm", "bind", "block", "break",
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
    # txt = txt.replace("const", "")
    txt = txt.strip()
    if txt[-2:] == " &":
        txt = txt[:-2]
    if txt[0] == "_":
        txt = "prefix" + txt[1:]
    if txt in NIM_KEYWORDS:
        txt = f"`{txt}`"
    return txt
#----------- EXPORTING  

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

def get_params_from_node(mynode):
    _params = []
    for i in mynode.get_children():
        if i.kind == clang.cindex.CursorKind.PARM_DECL:
            _paramName = i.displayname
            _default = None
            # Getting default values in params
            if _paramName == "_init":
                test_traverse( i, 0 )
            for j in i.get_children():
                iscall = False
                if j.kind == clang.cindex.CursorKind.DECL_REF_EXPR:
                    for m in j.get_tokens():
                        _default = m.spelling
                    continue

                elif j.kind == clang.cindex.CursorKind.CALL_EXPR:
                    _default = getCodeSpan( j )
                    continue
                    # _default = j.spelling + "("
                    # iscall = True

                elif j.kind == clang.cindex.CursorKind.BINARY_OPERATOR:
                    _default = getCodeSpan( j )
                    continue

                elif j.kind == clang.cindex.CursorKind.UNARY_OPERATOR:
                    _default = getCodeSpan( j )
                    continue

                elif j.kind == clang.cindex.CursorKind.PAREN_EXPR:
                    _default = getCodeSpan( j )
                    continue

                elif j.kind == clang.cindex.CursorKind.UNEXPOSED_EXPR:
                    _default = getCodeSpan( j )
                    if _default[0:1] == "=":
                        _default = _default[1:].lstrip()
                    continue

                elif j.kind in [clang.cindex.CursorKind.CXX_BOOL_LITERAL_EXPR] :
                    _default = getCodeSpan( j )
                    continue
                    # try:
                    #     _default = j.get_tokens().__next__().spelling 
                    # except:
                    #     _default = "???"

                elif j.kind in [clang.cindex.CursorKind.INTEGER_LITERAL, clang.cindex.CursorKind.FLOATING_LITERAL]:
                    _default = getCodeSpan( j )
                    continue
                    # try:
                    #     _default = j.get_tokens().__next__().spelling 
                    # except:
                    #     _default = "???"
                        # pass

                count = 0
                for k in j.get_children():
                    if iscall and count > 0:
                        _default += ", "
                    count+=1
                    # print( ">>:", _paramName, k.kind )
                    if k.kind == clang.cindex.CursorKind.UNEXPOSED_EXPR:
                        if _default == None: _default = ""
                        for m in k.get_tokens():
                            _default += m.spelling

                    elif k.kind == clang.cindex.CursorKind.CALL_EXPR:
                        for m in k.get_tokens():
                            if m.spelling == "=": continue
                            _default += m.spelling

                    elif k.kind == clang.cindex.CursorKind.GNU_NULL_EXPR:
                        _default = "nil"

                    elif k.kind == clang.cindex.CursorKind.STRING_LITERAL:
                        try:
                            _default = k.get_tokens().__next__().spelling 
                        except:
                            pass  

                    elif k.kind in [clang.cindex.CursorKind.INTEGER_LITERAL, clang.cindex.CursorKind.FLOATING_LITERAL] :
                        if _default == None: _default = ""
                        try:
                            _default += k.get_tokens().__next__().spelling 
                        except:
                            _default += "???"
                if iscall:
                    _default += ")"
            if _default == "NULL":
                _default = "nil"
            _params.append((i.displayname, i.type.spelling, _default))                                                          
    return _params    

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

def fully_qualified_constructor(c):
    if c is None:
        return ''
    elif c.kind == clang.cindex.CursorKind.TRANSLATION_UNIT:
        return ''
    else:
        res = fully_qualified(c.semantic_parent)
        if res != '':
            return res
            # return res + '::' + c.spelling
    return c.spelling


NORMAL_TYPES = ["void", "long", "unsigned long", "int", "size_t", "long long", "long double", 
                "float", "double", "char", "signed char", "unsigned char", "unsigned short", 
                "unsigned int", "unsigned long long", "char*", "bool" ]

def cleanit(tmp):
    if tmp.endswith("const *"):
        tmp0 = tmp
        tmp = tmp[:-7]+"*"
        print( tmp0, "---->", tmp )
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
        return _tmp
            
    return [_tmp]


def parse_include_file(filename, dependsOn, provides, search_paths = [], extra_args =[]):
    """This will parse a include file and return the data
    """
    #_data = {"filename" : filename, "imports" : [] }
    _data = []

    _index = clang.cindex.Index.create()

    searchFlags = [ f"-I{pathitem}" for pathitem in search_paths ]
    _args = []
    _args += ['-x', 'c++' ]
    _args += ['-std=c++17']

    _args += extra_args
    # _args += ['-include', 'hack.h']
    
    _args += searchFlags

    print( _args )
    #opts = TranslationUnit.PARSE_INCOMPLETE | TranslationUnit.PARSE_SKIP_FUNCTION_BODIES # a bitwise or of TranslationUnit.PARSE_XXX flags.
    _opts = clang.cindex.TranslationUnit.PARSE_DETAILED_PROCESSING_RECORD | \
            clang.cindex.TranslationUnit.PARSE_PRECOMPILED_PREAMBLE | \
            clang.cindex.TranslationUnit.PARSE_SKIP_FUNCTION_BODIES | \
            clang.cindex.TranslationUnit.PARSE_INCOMPLETE
    _tu = _index.parse(filename, _args, None, _opts)
    for diag in _tu.diagnostics:
        print(diag)

    _consts, _enums, _repeated = _parse_enums(filename, _tu)  # (list, dict, dict)

    for i in _consts:
        _data.append( (filename, "const", i))
        #pprint(i)
    for key,value in _enums.items():
        _data.append( (filename, "enum", key, value))

    for key,value in _repeated.items():
        _data.append( (filename, "repeated", key, value))

    _typedefs     = _parse_typedef(filename, _tu) # dict
    for key,value in _typedefs.items():
        _data.append( (filename, "typedef", key, value))    
    
    _classes      = _parse_class(filename, _tu)
    for key,value in _classes.items():
        _data.append( (filename, "class", key, value))
    
    _structs      = _parse_struct(filename, _tu)
    for key,value in _structs.items():
        _data.append( (filename, "struct", key, value))    
    
    _constructors = _parse_constructors(filename, _tu)
    for i in _constructors:
        #pprint(i)
        _data.append( (filename, "constructor", i["fully_qualified"], i))       
    
    _methods      = _parse_methods(filename, _tu)
    for i in _methods:
        _data.append( (filename, "method", i["fully_qualified"], i)) 


    _dependsOn = _find_depends_on( filename, _data )
    #_data.append( (filename, "dependsOn", _dependsOn)) 
    _provides  = _find_provided( filename, _data, _dependsOn )
    #_data.append( (filename, "provides", _provides))     
 
    _missing   = _missing_dependencies( filename, _data, _dependsOn, _provides )
    #_data.append( (filename, "missing", _missing))  
    #for key,value in _missing.items():
    #    _data.append( (filename, "missing", key, value))      
    return _data, _dependsOn, _provides, _missing


def _parse_enums(filename, _tu):
    """This function aims to extract all the anonymous enums"""
    _consts = []
    _repeated = {}
    _enums = {}
    _visited = set()
    for depth,node in get_nodes( _tu.cursor, depth=0 ):
        # if node in _visited: continue
        # _visited.add( node )
        _tmp = {}
        _isConst = False
        if node.kind == clang.cindex.CursorKind.ENUM_DECL and \
           node.is_definition() and node.location.file.name == filename:
            _typeName = fully_qualified(node.referenced)
            if node.spelling == "":
                _isConst = True
            else:
                _isConst = False
            _tmp = {"comment": node.brief_comment,
                    "type": node.enum_type.spelling,
                    "name": node.spelling,
                    "items" : []}
            for _depth, n in get_nodes(node, depth):
                if n.kind == clang.cindex.CursorKind.ENUM_CONSTANT_DECL:                        
                    _tmp["items"].append( { "name"   : n.spelling,
                                            "comment": n.brief_comment,
                                            "value"  : n.enum_value} )

            if _isConst:
                #_tmp.pop("name")
                _consts.append(_tmp) # Just in case there are several const definitions
            else:
                # Sort list
                _values = [i["value"] for i in _tmp["items"]]
                _values = list(set(_values))
                _values.sort()
                _names = [i["name"] for i in _tmp["items"]]                    
                _new = []
                for i in _values:
                    for item in _tmp["items"]:
                        if item["value"] == i:
                            _new.append( item )
                            _names.remove(item["name"])
                            break
                for _name in _names:
                    for item in _tmp["items"]:
                        if item["name"] == _name:
                            _repeated[_name] = item
                _tmp["items"] = _new
                _enums.update({_typeName : _tmp})
    return _consts, _enums, _repeated

def _parse_typedef(filename, _tu):
    _typedefs = {}
    for depth,node in get_nodes( _tu.cursor, depth=0 ):
        if node.access_specifier == clang.cindex.AccessSpecifier.PRIVATE: continue
        if not ( node.location.file and node.location.file.name == filename ): continue
        if node.kind in [clang.cindex.CursorKind.TYPE_REF]:
            refKind = node.referenced.kind
            _name = node.referenced.spelling
            if refKind in [ clang.cindex.CursorKind.ENUM_DECL, clang.cindex.CursorKind.TYPEDEF_DECL ]: continue
            # print( _name, refKind, node.displayname )
            _tmp = { 
                        "underlying": node.displayname,
                        "typedef_type": "ref",
                        "fully_qualified": fully_qualified(node.referenced),
                        "result": node.result_type.spelling              
                    }
            # _typedefs.update({_name : _tmp})

        elif node.kind in [clang.cindex.CursorKind.TYPEDEF_DECL]:
            _name = node.displayname

            _tmp = { 
                        "underlying": node.underlying_typedef_type.spelling,
                        "typedef_type": False,
                        "fully_qualified": fully_qualified(node.referenced),
                        "result": node.result_type.spelling              
                    }


            # Underlying dependencies
            _tmp["underlying_deps"] = get_template_dependencies(_tmp["underlying"])


            # The typedef might be for a function
            _tmp["params"] = get_params_from_node(node)
            
            _kind = node.underlying_typedef_type.kind

            if _kind == clang.cindex.TypeKind.POINTER:
                _pointee = node.underlying_typedef_type.get_pointee()
                if _pointee.kind == clang.cindex.TypeKind.FUNCTIONPROTO:
                    _result = _pointee.get_result().spelling
                    _tmp["result"] = _result
                    _tmp["typedef_type"] = "function"  

            elif _kind == clang.cindex.TypeKind.FUNCTIONPROTO:
                    _result = node.underlying_typedef_type.get_result().spelling
                    _tmp["result"] = _result
                    _tmp["typedef_type"] = "function"  
                    print("_name", _tmp )
            _typedefs.update({_name : _tmp})
    return _typedefs

def _parse_class(filename, _tu):
    """Parse classes (not forward declarations)"""
    _classes = {}
    for depth,node in get_nodes( _tu.cursor, depth=0 ):
        if node.access_specifier == clang.cindex.AccessSpecifier.PRIVATE: continue
        if node.kind in [clang.cindex.CursorKind.CLASS_DECL, clang.cindex.CursorKind.CLASS_TEMPLATE] and \
            node.is_definition() and node.location.file.name == filename:             
            _tmp = { "name" : node.spelling,
                        "comment": node.brief_comment,
                        "base" : [],
                        "fully_qualified": fully_qualified(node.referenced),
                        "template_params" : []
                    }                    
            #access_specifier: AccessSpecifier.PUBLIC
            #availability: AvailabilityKind.AVAILABLE
            for _, n in get_nodes( node, depth=depth ):
                if n.kind == clang.cindex.CursorKind.CXX_BASE_SPECIFIER:
                    _tmp["base"].append(n.displayname)

            # Get template parameters
            if node.kind == clang.cindex.CursorKind.CLASS_TEMPLATE:
                #print(depth)         
                for _depth, n in get_nodes(node, depth):
                    #print(_depth, n.spelling, n.kind)
                    if n.kind == clang.cindex.CursorKind.TEMPLATE_TYPE_PARAMETER:
                        _flag = False
                        _tmp["template_params"].append(n.spelling)
                    elif n.kind == clang.cindex.CursorKind.TEMPLATE_NON_TYPE_PARAMETER:
                        _templateParam = (n.spelling,n.type.spelling)
                        _flag = False
                        _tmp["template_params"].append(_templateParam)                            
                    elif n.kind in [clang.cindex.CursorKind.CLASS_TEMPLATE, clang.cindex.CursorKind.TYPE_REF]:
                        pass 
                    else:
                        break

            _name = _tmp["name"]
            _tmp.pop("name")
            _classes[_name] = _tmp          
    return _classes

def _parse_struct(filename, _tu):
    _structs = {}
    _visited = set()
    for depth, node in get_nodes( _tu.cursor, depth = 0 ):
        if node.access_specifier == clang.cindex.AccessSpecifier.PRIVATE: continue
        if node.kind == clang.cindex.CursorKind.STRUCT_DECL and \
            node.is_definition() and node.location.file.name == filename:
            # if not node.is_definition():
            #     continue

            structname = node.spelling
            # if structname in _visited: 
            #     continue
            # _visited.add( structname )

            fields = []
            deps = []
            
            if PRINT_STRUCT: print( ">>>>>>parse_struct", node.spelling, node.kind, node.type.kind )
            for fnode in node.type.get_fields():
                if fnode.is_anonymous():
                    for fnode2 in fnode.type.get_fields():
                        if PRINT_STRUCT:  print( " []:", fnode2.spelling, fnode2.type.spelling )
                        fields.append( { 
                            "name" : fnode2.spelling,
                            "type" : fnode2.type.spelling, #TODO:template/array?
                        }) 
                        deps+= get_template_dependencies(fnode2.type.spelling)
                else:
                    if PRINT_STRUCT: print( " ", fnode.spelling, fnode.type.spelling )
                    fields.append( { 
                        "name" : fnode.spelling,
                        "type" : fnode.type.spelling, #TODO:template/array?
                    }) 
                    deps+= get_template_dependencies(fnode.type.spelling)

            _tmp = { "name" : node.spelling,
                        "comment": node.brief_comment,
                        "base" : [],
                        "fully_qualified": fully_qualified(node.referenced),
                        "template_params" : [],
                        "underlying_deps" : deps,
                        "fields" : fields,
                        "incomplete" : node.type.get_size() < 0
                    }

            for _, n in get_nodes( node, depth = depth ):
                if n.kind == clang.cindex.CursorKind.CXX_BASE_SPECIFIER:
                    _tmp["base"].append(n.displayname)

            if (not node.is_definition()) and (structname in _structs):
                continue

            if node.type.get_size() >= 0:
                _structs.update( {structname : _tmp} )              
    return _structs

def _parse_constructors(filename, _tu):
    _constructors = []
    for depth,node in get_nodes( _tu.cursor, depth=0 ):
        if node.kind in [clang.cindex.CursorKind.CONSTRUCTOR] and \
            node.location.file.name == filename:   
            _tmp = { "name" : node.spelling,
                "class_name": node.semantic_parent.spelling,
                "comment": node.brief_comment,
                "fully_qualified": fully_qualified_constructor(node.referenced) }
            # print( ">>>>>>>>>>>>", node.spelling, fully_qualified_constructor(node.referenced) )
            _tmp["params"] = get_params_from_node(node)
            _constructors.append(_tmp)
    return _constructors

def _parse_methods(filename, _tu):
    """Parse methods and operators"""
    _methods = []
    for depth,node in get_nodes( _tu.cursor, depth=0 ):
        if node.access_specifier == clang.cindex.AccessSpecifier.PRIVATE: continue
        if node.kind in [clang.cindex.CursorKind.VAR_DECL] and node.type.kind == clang.cindex.TypeKind.TYPEDEF and\
            node.location.file.name == filename:
            vtype_decl = node.type.get_declaration()
            _pointee = vtype_decl.underlying_typedef_type.get_pointee()
            if _pointee.kind != clang.cindex.TypeKind.FUNCTIONPROTO:
                continue
            _tmp = {"name" : node.spelling,
                "fully_qualified" : fully_qualified(node.referenced),
                "result" : _pointee.get_result().spelling,
                "class_name": "",
                "const_method": False,
                "comment" : "",
                "plain_function" :True,
                "file_origin" : node.location.file.name }
            _tmp["params"] = get_params_from_node(vtype_decl)
            _tmp["result_deps"] = get_template_dependencies(_tmp["result"])
            _methods.append(_tmp)
                

    for depth,node in get_nodes( _tu.cursor, depth=0 ):
        if node.access_specifier == clang.cindex.AccessSpecifier.PRIVATE: continue
        if node.kind in [clang.cindex.CursorKind.CXX_METHOD, clang.cindex.CursorKind.FUNCTION_DECL] and \
            node.location.file.name == filename:    
            _name = node.spelling
            if _name.startswith("operator"):
                _tmp = _name[8:]
                if re.match("[+-=*\^/]+", "+-+=*^"):
                    _name = f'`{_tmp}`'

            _tmp = {"name" : _name,
                    "fully_qualified" : fully_qualified(node.referenced),
                    "result" : node.result_type.spelling,
                    "class_name": node.semantic_parent.spelling,
                    "const_method": node.is_const_method(),
                    "comment" : node.brief_comment,
                    "plain_function" :node.kind ==  clang.cindex.CursorKind.FUNCTION_DECL,
                    "file_origin" : node.location.file.name }
                
            #print(_tmp["result"])                    
            #pprint(_tmp["result_deps"])
            #if "<" in _tmp["result"]:
            _tmp["result_deps"] = get_template_dependencies(_tmp["result"])
            # print(_tmp)
            # Methods dependencies for results

            _tmp["params"] = get_params_from_node(node)
            _methods.append(_tmp)
    return _methods

def _find_depends_on(filename, _data):
    """Find all dependences in the file"""
    _dependsOn = []
    for _tmp in _data:
        if len(_tmp) == 4:
            _filename, _type, _name, _values = _tmp
            if _filename == filename:
                if _type in ["method", "constructor"]:                     
                    for param in _values["params"]:
                        _tmp1 = get_template_dependencies(param[1])
                        if _tmp1 != []:
                            for j in _tmp1:
                                _dependsOn.append(j)
                        else:
                            _dependsOn.append(cleanit(param[1]))

                        if param[2] != None:
                            _dependsOn.append(param[2])

                    if "result" in _values:
                        if _values["result"] != None:
                            if _values["result_deps"] != []:
                                for j in _values["result_deps"]:
                                    _dependsOn.append( j )
                            else:
                                _dependsOn.append(cleanit(_values["result"]))

                elif _type in ["typedefs"]:      
                    if _values["underlying_deps"] != []:
                        for _i in _values["underlying_deps"]:
                            _dependsOn.append( _values )
                    else:            
                        _tmp = cleanit(_values["underlying"])
                        _dependsOn.append( _tmp )
                
                # Some classes are templates; and those params might depend on other types
                elif _type in ["class"]:
                    if "template_params" in _values:
                        for i in _values["template_params"]:
                            if type(i) == tuple:
                                _dependsOn.append( i[1] )
                                
                elif _type in ["struct"]:
                    for _f, _ft in _values["fields"]:
                        _dependsOn.append( _ft )

    return set(_dependsOn)


def _find_provided(filename, _data, _dependsOn):
    """Find all types that the file might provide to others"""
    # Dependencies
    _provides = []
    for _tmp in _data:  #_name, _values
        if len(_tmp) == 4:
            _filename, _type, _name, _values = _tmp
            if _filename == filename:
                if _type == "const":    
                    for item in _values["items"]:
                        #_dependsOn = dependsOn[_filename]
                        if item["name"] in _dependsOn:
                            _provides.append(item["name"])
                elif _type == "enum":
                    for i in _values["items"]:
                        _provides.append((i["name"],_name))
                    _provides.append(_name)
                elif _type == "class":
                    _provides.append(_values["fully_qualified"])
                elif _type == "struct":
                    _provides.append(_values["fully_qualified"])            
                elif _type == "typedef":
                    _provides.append(_values["fully_qualified"])

    return set(_provides)

def _missing_dependencies(filename, _data, _dependsOn, _provides):
    _missing = set([])
    #_dependsOn = dependsOn.get(filename,[])
    #_provides = provides.get(filename, [])
            
    for i in _dependsOn:
        if i not in NORMAL_TYPES:
            if i not in _provides:
                _tmp = [k[0] for k in _provides if type(k) is tuple]
                if i not in _tmp:
                    _missing.add( i )
    return _missing

#==============================================================
def do_parse( _root, _folders, _dest, search_paths = [], extra_args =[], ignore = [] ):
    # Get the files list
    _files = []
    _dirs = []
    for _folder in _folders:
        _allfiles = glob.glob(_folder, recursive = True)
        _files += [f for f in _allfiles if os.path.isfile(f)]
        _dirs  += [f for f in _allfiles if not os.path.isfile(f)]

    print("Root folder: ", _root)

    _path = os.getcwd()
    _delete_folder = os.path.join(_dest, "__parsed")
    _destination_folder = os.path.join(_path, _dest)
    if not os.path.isdir(_destination_folder):
        os.mkdir(_destination_folder)       
    if not os.path.isdir(_delete_folder):    
        os.mkdir(_delete_folder) 
    # Create folders if needed
    for i in _dirs:
        _rel = os.path.relpath(i, _root)
        _folder = os.path.join(_dest,_rel)
        Path(_folder).mkdir(parents=True, exist_ok=True)
   
    # Start parsing all the include files
    files = []
    _dependsOn = {}
    _provides = {}
    _missing = {}
    _nTotal = len(_files)
    _n = 1
    for include_file in _files:
        if include_file in ignore: continue
        print(f"Parsing ({_n}/{_nTotal}): {include_file}")
        _n += 1
        _data, _deps, _prov, _miss = parse_include_file(include_file, _dependsOn, _provides, search_paths = search_paths, extra_args = extra_args )
        #pprint(pf)
        #files[include_file] = pf
        files = files + _data
        _dependsOn[include_file] = _deps
        _provides[include_file]  = _prov
        _missing[include_file]   = _miss

    _dict = { "includes": files,
              "dependsOn" : _dependsOn,
              "provides" : _provides,
              "missing"  : _missing
            }

    import pickle
    _files_name = os.path.join(_delete_folder, 'files.pickle')
    fp = open(_files_name, 'wb')
    pickle.dump(_dict, fp)
    fp.close()

    # print( _dict )
    # import json
    # _files_name = os.path.join(_delete_folder, 'files.json')
    # fp = open(_files_name, 'w')
    # json.dump(_dict, fp)
    # fp.close()

#----------------------------------------------------------------
#unbuffer stdio
class Unbuffered(object):
   def __init__(self, stream):
       self.stream = stream
   def write(self, data):
       self.stream.write(data)
       self.stream.flush()
   def writelines(self, datas):
       self.stream.writelines(datas)
       self.stream.flush()
   def __getattr__(self, attr):
       return getattr(self.stream, attr)
       
sys.stdout = Unbuffered(sys.stdout)

if __name__ == '__main__':
    # Read the command line: it takes a glob and a destination
    _folder = sys.argv[1]
    _dest = sys.argv[2]
    _root = get_root(_folder)    

    do_parse( _root, [_folder], _dest )
    