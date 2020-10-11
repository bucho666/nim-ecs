import unittest, typetraits, tables, hashes

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

proc assign*[T](self: Entity, compornent: T) {.inline.} =
  self.world.assign(self, compornent)

proc get*(self: Entity, T: typedesc): T {.inline.} =
  self.world.get(self, T)

proc isValid*(self: Entity): bool {.inline.} =
  self.id != InvalidEntityId

proc has*(self: Entity, T: typedesc): bool {.inline.} =
  self.world.has(T) and self.world.compornentsOf(T).has(self)

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
    e.assign(Coord(x: 23, y: 9))
    e.assign(255)
    e.assign("string")
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
    e1.assign(Foo())
    e1.assign(42)
    e2.assign(Foo())
    e2.assign(43)
    e1.delete()
    check(e1.isValid == false)
    check(e2.isValid)
    check(e2.get(int) == 43)
    let e3 = world.newEntity
    check(e3.id == 6)
    e3.assign(Foo())
    e3.assign(44)
    check(e3.has(Foo))
    check(e3.has(int))
    check(e3.get(int) == 44)

  test "for each":
    for n in 1..10:
      let e = world.newEntity
      e.assign(n * 2)
      if e.id == 5:
        e.delete()
    var result = newSeq[int]()
    for v in world.compornentsOf(int):
      result.add(v)
    check(result == [2, 4, 6, 8, 12, 14, 16, 18, 20])
