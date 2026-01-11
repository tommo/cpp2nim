# Auto-generated Nim bindings for upstream/micropather.h
# Generated: 2026-01-11T14:37:48+08:00

type
  ccstring* = cstring  ## const char*
  ConstPointer* = pointer  ## const void*

type
  StateCost* {.header: "micropather.h", importcpp: "micropather::StateCost".} = object
    state*: pointer
    cost*: cfloat
  NodeCost* {.header: "micropather.h", importcpp: "micropather::NodeCost".} = object
    node*: ptr PathNode
    cost*: cfloat
  Item* {.header: "micropather.h", importcpp: "micropather::PathCache::Item".} = object
    start*: pointer
    `end`*: pointer
    next*: pointer
    cost*: cfloat
  CacheData* {.header: "micropather.h", importcpp: "micropather::CacheData".} = object
    nBytesAllocated*: cint
    nBytesUsed*: cint
    memoryFraction*: cfloat
    hit*: cint
    miss*: cint
    hitFraction*: cfloat
  MPVector*[T] {.header: "micropather.h", importcpp: "micropather::MPVector", byref.} = object
  Graph* {.header: "micropather.h", importcpp: "micropather::Graph", byref.} = object
  PathNode* {.header: "micropather.h", importcpp: "micropather::PathNode", byref.} = object
    state*: pointer
    costFromStart*: cfloat
    estToGoal*: cfloat
    totalCost*: cfloat
    parent*: ptr PathNode
    frame*: cuint
    numAdjacent*: cint
    cacheIndex*: cint
    child*: array[2,ptr PathNode]
    next*: ptr PathNode
    prev*: ptr PathNode
    inOpen*: bool
    inClosed*: bool
  PathNodePool* {.header: "micropather.h", importcpp: "micropather::PathNodePool", byref.} = object
  PathCache* {.header: "micropather.h", importcpp: "micropather::PathCache", byref.} = object
    hit*: cint
    miss*: cint
  MicroPather* {.header: "micropather.h", importcpp: "micropather::MicroPather", byref.} = object
  MP_UPTR* {.header: "micropather.h", importcpp: "MP_UPTR".} = uint

proc clear*[M](self: ptr MPVector) {.importcpp: "clear".}
proc resize*[M](self: ptr MPVector, s: cuint) {.importcpp: "resize".}
proc `[]`*[M, T](self: ptr MPVector, i: cuint): var T {.importcpp: "#[#]".}
proc push_back*[M, T](self: ptr MPVector, t: T) {.importcpp: "push_back".}
proc size*[M](self: ptr MPVector): cuint {.importcpp: "size".}
proc leastCostEstimate*(self: ptr Graph, stateStart: pointer, stateEnd: pointer): cfloat {.importcpp: "LeastCostEstimate".}
proc adjacentCost*[M, S](self: ptr Graph, state: pointer, adjacent: MPVector[StateCost]) {.importcpp: "AdjacentCost".}
proc printStateInfo*(self: ptr Graph, state: pointer) {.importcpp: "PrintStateInfo".}
proc init*(self: ptr PathNode, v_frame: cuint, v_state: pointer, v_costFromStart: cfloat, v_estToGoal: cfloat, v_parent: ptr PathNode) {.importcpp: "Init".}
proc clear*(self: ptr PathNode) {.importcpp: "Clear".}
proc initSentinel*(self: ptr PathNode) {.importcpp: "InitSentinel".}
proc unlink*(self: ptr PathNode) {.importcpp: "Unlink".}
proc addBefore*(self: ptr PathNode, addThis: ptr PathNode) {.importcpp: "AddBefore".}
proc calcTotalCost*(self: ptr PathNode) {.importcpp: "CalcTotalCost".}
proc clear*(self: ptr PathNodePool) {.importcpp: "Clear".}
proc getPathNode*(self: ptr PathNodePool, frame: cuint, v_state: pointer, v_costFromStart: cfloat, v_estToGoal: cfloat, v_parent: ptr PathNode): ptr PathNode {.importcpp: "GetPathNode".}
proc fetchPathNode*(self: ptr PathNodePool, state: pointer): ptr PathNode {.importcpp: "FetchPathNode".}
proc pushCache*[N](self: ptr PathNodePool, nodes: ptr NodeCost, nNodes: cint, start: ptr cint): bool {.importcpp: "PushCache".}
proc getCache*[N](self: ptr PathNodePool, start: cint, nNodes: cint, nodes: ptr NodeCost) {.importcpp: "GetCache".}
proc allStates*[M](self: ptr PathNodePool, frame: cuint, stateVec: MPVector[pointer]) {.importcpp: "AllStates".}
proc keyEqual*(self: ptr Item, item: Item): bool {.importcpp: "KeyEqual".}
proc empty*(self: ptr Item): bool {.importcpp: "Empty".}
proc hash*(self: ptr Item): cuint {.importcpp: "Hash".}
proc reset*(self: ptr PathCache) {.importcpp: "Reset".}
proc add*[M](self: ptr PathCache, path: MPVector[pointer], cost: MPVector[cfloat]) {.importcpp: "Add".}
proc addNoSolution*(self: ptr PathCache, `end`: pointer, states: ptr pointer, count: cint) {.importcpp: "AddNoSolution".}
proc solve*[M](self: ptr PathCache, startState: pointer, endState: pointer, path: MPVector[pointer], totalCost: ptr cfloat): cint {.importcpp: "Solve".}
proc allocatedBytes*(self: ptr PathCache): cint {.importcpp: "AllocatedBytes".}
proc usedBytes*(self: ptr PathCache): cint {.importcpp: "UsedBytes".}
proc solve*[M](self: ptr MicroPather, startState: pointer, endState: pointer, path: MPVector[pointer], totalCost: ptr cfloat): cint {.importcpp: "Solve".}
proc solveForNearStates*[M, S](self: ptr MicroPather, startState: pointer, near: MPVector[StateCost], maxCost: cfloat): cint {.importcpp: "SolveForNearStates".}
proc reset*[M](self: ptr MicroPather) {.importcpp: "Reset".}
proc statesInPool*[M](self: ptr MicroPather, stateVec: MPVector[pointer]) {.importcpp: "StatesInPool".}
proc getCacheData*[C, M](self: ptr MicroPather, data: ptr CacheData) {.importcpp: "GetCacheData".}
proc newMPVector*[T](): MPVector {.constructor,importcpp: "micropather::MPVector".}
proc newPathNodePool*(allocate: cuint, typicalAdjacent: cuint): PathNodePool {.constructor,importcpp: "micropather::PathNodePool(@)".}
proc newPathCache*(itemsToAllocate: cint): PathCache {.constructor,importcpp: "micropather::PathCache(@)".}
proc newCacheData*(): CacheData {.constructor,importcpp: "micropather::CacheData".}
proc newMicroPather*(graph: ptr Graph, allocate: cuint, typicalAdjacent: cuint, cache: bool): MicroPather {.constructor,importcpp: "micropather::MicroPather(@)".}
proc newMicroPather*(a00: MicroPather): MicroPather {.constructor,importcpp: "micropather::MicroPather(@)".}
const
  SOLVED* = 0
  NO_SOLUTION* = 1
  START_END_SAME* = 2
  NOT_CACHED* = 3
