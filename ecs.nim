import unittest, typetraits, tables, hashes, macros, strformat

type
  EntityId = uint64

  Entity* = ref object
    id: EntityId
    world: World

  AbstructCompornent = ref object of RootObj
    index: Table[Entity, int]
    freeIndex: seq[int]

  Compornent*[T] = ref object of AbstructCompornent
    compornents: seq[T]

  World* = ref object
    lastEntityId: EntityId
    compornents: Table[string, AbstructCompornent]

let InvalidEntityId: EntityId = 0

proc hash*(self: Entity): Hash {.inline.} =
  self.id.hash

proc has(self: AbstructCompornent, entity: Entity): bool {.inline.} =
  self.index.hasKey(entity)

proc remove(self: AbstructCompornent, entity: Entity) =
  self.freeIndex.add(self.index[entity])
  self.index.del(entity)

proc assign*[T](self: Compornent[T], entity: Entity, compornent: T) =
  if self.index.hasKey(entity):
    self.compornents[self.index[entity]] = compornent
    return
  if self.freeIndex.len > 0:
    let index = self.freeIndex.pop
    self.index[entity] = index
    self.compornents[index] = compornent
    return
  self.index[entity] = self.compornents.len
  self.compornents.add(compornent)

proc get*[T](self: Compornent[T], entity: Entity): T {.inline.} =
  return self.compornents[self.index[entity]]

iterator items*[T](self: Compornent[T]): T =
  for i in self.index.values:
    yield self.compornents[i]

iterator pairs*[T](self: Compornent[T]): tuple[key: Entity, val: T] =
  for e, i in self.index.pairs:
    yield (e, self.compornents[i])

proc has*(self: World, T: typedesc): bool {.inline.} =
  self.compornents.hasKey(T.type.name)

proc newEntity*(self: World): Entity =
  self.lastEntityId += 1
  Entity(id: self.lastEntityId, world: self)

proc assign*[T](self: World, entity: Entity, compornent: T) =
  if self.has(T) == false:
    self.newCompornent(T)
  self.compornentsOf(T).assign(entity, compornent)

proc compornentsOf*(self: World, T: typedesc): Compornent[T] {.inline.} =
  cast[Compornent[T]](self.compornents[T.type.name])

proc newCompornent*(self: World, T: typedesc) {.inline.} =
  self.compornents[T.type.name] = Compornent[T]()

proc get*(self: World, entity: Entity, T: typedesc): T {.inline.} =
  self.compornentsOf(T).get(entity)

proc deleteEntity(self: World, entity: Entity) =
  for c in self.compornents.values:
    c.remove(entity)

proc with*[T](self: Entity, compornent: T): Entity {.inline, discardable.} =
  self.world.assign(self, compornent)
  self

proc get*(self: Entity, T: typedesc): T {.inline.} =
  self.world.get(self, T)

proc isValid*(self: Entity): bool {.inline.} =
  self.id != InvalidEntityId

proc has*(self: Entity, T: typedesc): bool {.inline.} =
  self.world.has(T) and self.world.compornentsOf(T).has(self)

macro hasAll*(self: Entity, types: varargs[typed]): untyped =
  var body = ""
  for t in types:
    if len(body) > 0:
      body.add(" and ")
    body.add(fmt"{repr(self)}.has({repr(t)})")
  parseStmt(body)

macro getAll*(self: Entity, types: varargs[typed]): untyped =
  var body = ""
  for t in types:
    if len(body) > 0:
      body.add(", ")
    body.add(fmt"{repr(self)}.get({repr(t)})")
  parseStmt(fmt"({body})")

macro getAllOrContinue*(self: Entity, types: varargs[typed]): untyped =
  var typesList= ""
  for t in types:
    if len(typesList) > 0:
      typesList.add(", ")
    typesList.add(repr(t))
  parseStmt(fmt"if {repr(self)}.hasAll({typesList}): {repr(self)}.getAll({typesList}) else: continue")

proc delete*(self: Entity) =
  self.world.deleteEntity(self)
  self.id = InvalidEntityId

suite "ECS test":
  setup:
    let world = World()

  test "new entity":
    check(world.newEntity.id == 1)
    check(world.newEntity.id == 2)
    check(world.newEntity.id == 3)

  test "assign":
    type Coord = ref object
      x: int
      y: int
    let e = world.newEntity
    check(e.has(Coord) == false)
    check(e.has(int) == false)
    check(e.has(string) == false)
    e.with(Coord(x: 23, y: 9)).with(255).with("string")
    check(e.has(Coord))
    check(e.has(int))
    check(e.has(string))
    let c = e.get(Coord)
    check(c.x == 23)
    check(c.y == 9)
    check(e.get(int) == 255)
    check(e.get(string) == "string")

  test "delete":
    type Foo = ref object
    check(world.newEntity.id == 1)
    check(world.newEntity.id == 2)
    let
      e1 = world.newEntity
      e2 = world.newEntity
    check(world.newEntity.id == 5)
    check(e1.id == 3)
    check(e1.isValid)
    e1.with(Foo()).with(42)
    e2.with(Foo()).with(43)
    e1.delete()
    check(e1.isValid == false)
    check(e2.isValid)
    check(e2.get(int) == 43)
    let e3 = world.newEntity
    check(e3.id == 6)
    e3.with(Foo()).with(44)
    check(e3.has(Foo))
    check(e3.has(int))
    check(e3.get(int) == 44)

  test "for each":
    for n in 1..10:
      let e = world.newEntity.with(n * 2)
      if e.id == 5:
        e.delete()
    var result = newSeq[int]()
    for v in world.compornentsOf(int):
      result.add(v)
    check(result == [2, 4, 6, 8, 12, 14, 16, 18, 20])

  test "hasAll":
    type Foo = ref object
    let
      a = world.newEntity.with(42).with("string")
      b = world.newEntity.with("string").with(Foo())
      c = world.newEntity.with(23).with("hogehoge").with(Foo())
    check(a.hasAll(int, string))
    check(a.hasAll(int, string, Foo) == false)
    check(b.hasAll(string, Foo))
    check(b.hasAll(int, string, Foo) == false)
    check(c.hasAll(int, string, Foo))

  test "getAll":
    let
      a = world.newEntity.with(42).with("string")
      b = world.newEntity.with("string").with(3.14)
      c = world.newEntity.with(23).with("hogehoge").with(3.17)
    check(a.hasAll(int, string))
    check(b.hasAll(string, float))
    check(c.hasAll(int, string, float))
    check(a.getAll(int, string) == (42, "string"))
    check(b.getAll(string, float) == ("string", 3.14))
    check(c.getAll(int, string, float) == (23, "hogehoge", 3.17))
