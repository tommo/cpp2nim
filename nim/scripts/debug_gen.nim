import std/[os, sets, tables]
import ../src/cpp2nim/[parser, models, config, generator]

let cfg = defaultConfig()
let p = initCppHeaderParser(cfg)
let gen = initNimCodeGenerator(cfg)

let filename = paramStr(1)
let header = p.parseFile(filename)
let incl = extractFilename(filename)

# Collect types
var typeCode = ""
for e in header.enums:
  typeCode.add(gen.generateEnum(e, incl))
for s in header.structs:
  typeCode.add(gen.generateStruct(s, incl))
for c in header.classes:
  typeCode.add(gen.generateClass(c, incl))
for t in header.typedefs:
  typeCode.add(gen.generateTypedef(t, incl))

echo "# Auto-generated test\n"
echo "type"
echo "  ccstring* = cstring  ## const char*"
echo "  ConstPointer* = pointer  ## const void*"
echo ""

if typeCode.len > 0:
  echo "type"
  echo typeCode
  echo ""

# Collect procs
var visited: HashSet[string]
for m in header.methods:
  let methodCode = gen.generateMethod(m, visited, @[])
  if methodCode.len > 0:
    echo methodCode

var dupTracker: Table[string, bool]
for c in header.constructors:
  echo gen.generateConstructor(c, dupTracker)
