#!/usr/bin/env python

import sys
import os
import os.path
from pprint import pprint
from .export import *

rootNameSpace = None

def flatten_namespace(name):
    """Convert NS1::NS2::xx to NS2_xx"""
    if not name or '::' not in name:
        return name
    
    parts = name.split('::')
    # Take last two parts if available, otherwise just last part
    if len(parts) >= 2:
        return f"{parts[-2]}_{parts[-1]}"
    return parts[-1]

def _relationships(data, provides, missing):
    """For each file it gives the files providing some dependencies"""
    _new = {}
    _filenames = set([_tmp[0] for _tmp in data])

    for file in _filenames:
        _missing = missing[file]
        _data = {}
        for f in _filenames:
            if f != file:
                # The normal case
                _provides = provides[f] 
                _found = _missing.intersection(_provides)
                
                # The enum case
                _tmp = [k[0] for k in _provides if type(k) is tuple]
                _found2 = _missing.intersection(_tmp)
                
                _enumFound = []
                if len(_found2) > 0:
                    for item in _found2:
                        for k in _provides:
                            if type(k) is tuple and item == k[0]:
                                _enumFound.append(k[1])
                _enumFound = list(set(_enumFound))
                
                if len(_found) > 0 or len(_enumFound) > 0:
                    _data[f] = set(list(_found) + _enumFound)

        _new[file] = _data
    return _new

def find_dependencies(obj, data, refobj=None, rec=None):    
    if rec is None:
        rec = set()

    if obj in rec: 
        return set()
        
    rec.add(obj)
    _deps = set()
    
    _idxClass = [j for j in range(len(data)) if data[j][2] in ["class", "typedef", "struct"]]
    _classesFully = [data[j][4]["fully_qualified"] for j in _idxClass]
    _classes = [data[j][3] for j in _idxClass]

    _idxEnum = [j for j in range(len(data)) if data[j][2] in ["enum"]]
    _enumsFully = [data[j][3] for j in _idxEnum]
    _enums = ["enum " + data[j][4]["name"] for j in _idxEnum]

    for i in range(len(data)):
        if data[i][2] in ["typedef", "class", "struct"]:
            _values = data[i][4]
            
            if _values["fully_qualified"] == obj:
                # If the type depend on other types, they need to be moved too.
                if "underlying_deps" in _values:
                    for _i in _values["underlying_deps"]:
                        found = False
                        if _i in _enumsFully:
                            _deps.add(_i)
                            found = True
                        elif _i in _enums:
                            _k = _enums.index(_i)
                            _k = _idxEnum[_k]
                            _fullname = data[_k][3]
                            _deps.add(_fullname)
                            found = True
                        elif _i in _classesFully:
                            if not _i in _deps:
                                _newdeps = find_dependencies(_i, data, obj, rec)                                
                                _deps.add(_i)
                                _deps = _deps.union(_newdeps)
                                found = True
                        elif _i in _classes:                          
                            _k = _classes.index(_i)
                            _k = _idxClass[_k]
                            _fullname = data[_k][4]["fully_qualified"]                          
                            if not _fullname in _deps:
                                _newdeps = find_dependencies(_fullname, data, obj, rec)
                                _deps.add(_fullname)
                                _deps = _deps.union(_newdeps)
                            found = True

                # Check template params
                if "template_params" in _values and len(_values["template_params"]) > 0:
                    for template_param in _values["template_params"]:
                        if type(template_param) == tuple:
                            for k in range(len(_enumsFully)):
                                _enumType = _enumsFully[k]
                                if _enumType.endswith(template_param[1]) and "::" in template_param[1]:
                                    if not _enumType in _deps:
                                        _newdeps = find_dependencies(_enumType, data, obj, rec)                                               
                                        _deps.add(_enumType)                                        
                                        _deps = _deps.union(_newdeps)                                              
    return _deps

def move_to_shared_types(newfilename, data, root, relations={}, force_shared=[]):
    # Objects that need to be moved
    _objects = set()
    for _, _dict in relations.items():
        for _, sets in _dict.items():
            _objects = _objects.union(sets)  

    # Add dependencies to the list
    _all = set(_objects)
    
    for obj in _objects:
        _tmp = find_dependencies(obj, data, newfilename)
        _all = _all.union(_tmp)

    _all.update(force_shared)
        
    # Move items to the new file
    _newImports = set()
    for obj in _all:
        for i in range(len(data)):
            _tmp = data[i]        
            _file = _tmp[1]
            _type = _tmp[2]

            # Check the consts
            if _type == "const":
                _values = _tmp[3]
                for item in _values["items"]:
                    if item["name"] == obj:
                        _newImports.add(data[i][0])
                        data[i] = tuple([newfilename] + list(data[i][1:]))

            # Check the enums
            elif _type == "enum":
                _name = _tmp[3]
                if _name == obj:
                    _newImports.add(data[i][0])
                    data[i] = tuple([newfilename] + list(data[i][1:]))

            # Check the other types
            elif _type in ["typedef", "class", "struct"]:
                _values = _tmp[4]                
                if _values["fully_qualified"] == obj:      
                    _newImports.add(data[i][0])                    
                    data[i] = tuple([newfilename] + list(data[i][1:]))

    # Add the new imports
    _new = []
    for i in _newImports:
        _new.append((i, None, "import", [newfilename]))
    return _new + data

def _get_objects_provided_per_file(data, _relations):
    """Creates a dictionary with all the objects provided by each file and
    that are needed by some other file."""
    _filter = {}
    for _, _dict in _relations.items():
        for k, sets in _dict.items():
            # Accumulate all the sets associated to a specific file
            _set = _filter.get(k, set())
            _set = _set.union(sets)

            # Relates the enum's items with the corresponding identifier
            _pfEnums = {}
            _enums = [_tmp for _tmp in data if _tmp[0] == k and _tmp[1] == "enum"]
            for _, _, enumType, _values in _enums:
                for enum in _values["items"]:
                    _pfEnums[enum["name"]] = enumType
            
            _td = [_tmp for _tmp in data if _tmp[0] == k and _tmp[1] == "typedef"]
            _classes = [(_tmp[2], _tmp[3]["fully_qualified"]) for _tmp in data if _tmp[0] == k and _tmp[1] == "class"]
            _classes = dict(_classes)
            
            for _, _, _, value in _td:
                if "underlying_deps" in value:
                    for _i in value["underlying_deps"]:
                        if _i in _classes:      
                            _set.add(_classes[_i])
                        for _j, key2 in _pfEnums.items():
                            if _j.endswith(_i):
                                _set.add(key2)

            _filter[k] = _set
    return _filter   

def _get_repeated_identifiers(_filter):
    """Find identifiers that appear in multiple files"""
    _identifiers = [_item.split("::")[-1] for _file, _set in _filter.items() for _item in _set]
    _repeatedNames = set([x for x in _identifiers if _identifiers.count(x) > 1])
    _repeated = {}
    
    for i in _repeatedNames:
        _list = _repeated.get(i, [])
        for k, v in _filter.items():
            for item in v:
                if item.split("::")[-1] == i:
                    _list.append((k, item))
        _repeated[i] = _list
    return _repeated

def _get_renames_identifiers(newfilename, data):
    """Generate new names for identifiers that would otherwise conflict"""
    idx = [i for i in range(len(data)) if data[i][0] == newfilename]

    enums = [(i, data[i][3], data[i][3].split("::")[-1]) for i in idx if data[i][2] == "enum"]

    objects = [(i, data[i][4]["fully_qualified"], data[i][4]["fully_qualified"].split("::")[-1]) 
               for i in idx if data[i][2] in ["class", "struct", "typedef"]]

    _list = objects + objects
    names = [name for _, _, name in _list]
    repeated_names = set([name for name in names if names.count(name) > 1])

    _renamer = {}

    for i, _fully, _name in _list:
        if _name in repeated_names:
            _newname = get_new_name(_fully, list(_renamer.values()))
            _renamer.update({_fully: _newname})

    return _renamer

def get_root(data):
    n = float('inf')
    filenames = set([i[0] for i in data])
    for file in filenames:
        _tmp = os.path.split(file)[0]
        n = min(n, len(_tmp))
    return file[0:n]

def get_new_name(_full, names):
    _tmp = _full.split("::")
    if rootNameSpace and _tmp[0] == rootNameSpace:
        return '_'.join(_tmp[1:])
    else:
        return flatten_namespace(_full)  # Modified this line
        # return _full.replace("::", "_")

def export_nim_option(option):
    global rootNameSpace
    rootNameSpace = option.get('root_namespace', None)
    export_txt_option(option)

def export_nim(dest, parsed, output, root=None, ignore={}, ignorefields=[], inheritable={}, varargs=[], rename={}):
    import pickle
    
    # Read parsed data
    _files_folder = os.path.join(parsed, "__parsed")
    _files_name = os.path.join(_files_folder, 'files.pickle')
    
    with open(_files_name, 'rb') as fp:
        _tmp = pickle.load(fp)
        data = _tmp["includes"]
        dependsOn = _tmp["dependsOn"]
        provides = _tmp["provides"]
        missing = _tmp["missing"]

    _relations = _relationships(data, provides, missing)
    _filter = _get_objects_provided_per_file(data, _relations)
    _repeated = _get_repeated_identifiers(_filter)

    rootTypesFileName = f"{dest}_types.nim"

    # Create output directory
    os.makedirs(output, exist_ok=True)

    # Clean existing nim files
    for file in os.listdir(output):
        fullname = output + '/' + file
        if os.path.isfile(fullname) and file.endswith('.nim'):
            os.remove(fullname)

    # Add destination filename column
    if root is None:
        root = get_root(data)

    _new = []
    for i in data:
        _tmp = os.path.splitext(i[0])[0]
        _destFilename = os.path.basename(_tmp)
        _destFilename += ".nim"
        _tmp = tuple([_destFilename] + list(i))
        _new.append(_tmp)
    data = _new

    # Move shared types to root file
    _idxTypes = [j for j in range(len(data)) if data[j][2] in ["class", "typedef", "struct"]]
    _classesFully = [data[j][4]["fully_qualified"] for j in _idxTypes]
    
    _idxEnum = [j for j in range(len(data)) if data[j][2] in ["enum"]]
    _enumsFully = [data[j][3] for j in _idxEnum]

    _idxEnumDup = [j for j in range(len(data)) if data[j][2] in ["enum_dup"]]
    _enumsDup = [data[j][3] for j in _idxEnumDup]

    _allTypes = _classesFully + _enumsFully

    data = move_to_shared_types(rootTypesFileName, data, root, relations=_relations, force_shared=_allTypes)

    # Add imports for the shared types file
    _tmpNames = set()
    _tmpFully = set()
    for i in data:
        if i[0].endswith(rootTypesFileName):
            _name = i[3]
            _fully = None
            if len(i) > 4 and "fully_qualified" in i[4]:
                _fully = i[4]["fully_qualified"]
            if type(_name) != list:
                _tmpNames.add(_name)
            _tmpFully.add(_fully)
    
    _tmp = []
    _done = []
    for i in range(len(data)):
        if not data[i][0].endswith(rootTypesFileName) and data[i][0] not in _done:
            _done.append(data[i][0])
            _tmp.append((data[i][0], None, "import", [f"{dest}_types"]))
    data = _tmp + data

    # Avoid module importing itself
    _deleteme = []
    for i in range(len(data)):
        _file = os.path.basename(data[i][0])
        _type = data[i][2]
        if _type == "import" and _file in data[i][3]:
            _deleteme.append(i)
    for i in sorted(_deleteme, reverse=True):
        data.pop(i)

    # Avoid importing twice the same module
    _deleteme = [i for i in range(len(data)) if data[i][2] == "import"]
    _dict = {}
    for _tmp in data:
        if _tmp[2] == "import":
            _val = _dict.get(_tmp[0], set())
            _list = [os.path.splitext(i)[0] for i in _tmp[3]]
            _val = _val.union(set(_list))
            _dict[_tmp[0]] = _val
    
    for i in sorted(_deleteme, reverse=True):
        data.pop(i)
    
    _tmp = []
    for _file, _set in _dict.items():
        for i in _set:
            _tmp.append((_file, None, "import", [i]))
    data = _tmp + data    

    # ROOT FILE
    _destFiles = set([i[0] for i in data]) 

    _pragma = ''
    data = [(f"{dest}.nim", None, "pragma", None, _pragma)] + data
    
    for _file in _destFiles:
        _fname = os.path.splitext(_file)[0]
        if _fname != f"{dest}_types":
            _fname = _fname.replace("-", "_")
            data = [(f"{dest}.nim", None, "import", [_fname])] + data             

    # Renaming
    rename2 = rename
    rename = _get_renames_identifiers(rootTypesFileName, data)
    rename.update({
        k: flatten_namespace(v) if '::' in v else v 
        for k, v in rename2.items()
    })

    # EXPORTING TO FILES
    _destFiles = set([i[0] for i in data])
    print(data)
    for destFile in _destFiles:
        print("export:", destFile)
        _txt = export_txt(destFile, data, root=root, rename=rename, ignore=ignore, 
                         ignorefields=ignorefields, inheritable=inheritable, varargs=varargs)
        destFile = destFile.replace("-", "_")
        _fname = os.path.join(output, destFile)        
        with open(_fname, "w") as _fp:
            _fp.write(_txt)

if __name__ == '__main__':
    export_nim(sys.argv[1])