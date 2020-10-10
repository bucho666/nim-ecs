import unittest, typetraits, tables, sets

type
  Ecs* = ref object
    nextEntityId: EntityId
    compornents: Table[string, AbstructCompornent]

  Entity = ref object
    id: EntityId
    ecs: Ecs

  EntityId = uint64

  AbstructCompornent = ref object of RootObj
    index: Table[EntityId, int]
    freeIndex: seq[int]

  Compornent[T] = ref object of AbstructCompornent
    compornents: seq[T]

let InvalidEntityId: EntityId = 0

proc assign*[T](self: Compornent[T], entity: Entity, compornent: T) =
  if self.index.hasKey(entity.id):
    self.compornents[self.index[entity.id]] = compornent
    return
  if self.freeIndex.len > 0:
    let index = self.freeIndex.pop
    self.index[entity.id] = index
    self.compornents[index] = compornent
    return
  self.index[entity.id] = self.compornents.len
  self.compornents.add(compornent)

proc has(self: AbstructCompornent, entity: Entity): bool =
  self.index.hasKey(entity.id)

proc remove(self: AbstructCompornent, entity: Entity) =
  self.freeIndex.add(self.index[entity.id])
  self.index.del(entity.id)

proc get*[T](self: Compornent[T], entity: Entity): T =
  return self.compornents[self.index[entity.id]]

iterator items*[T](self: Compornent[T]): T =
  for i in self.index.values:
    yield self.compornents[i]

proc newEntity*(self: Ecs): Entity =
  self.nextEntityId += 1
  Entity(id: self.nextEntityId, ecs: self)

proc has*(self: Ecs, T: typedesc): bool {. inline .} =
  self.compornents.hasKey(T.type.name)

proc assign*[T](self: Ecs, entity: Entity, compornent: T) =
  if self.has(T) == false: self.newCompornent(T)
  self.compornentsOf(T).assign(entity, compornent)

proc compornentsOf(self: Ecs, T: typedesc): Compornent[T] {. inline .} =
  cast[Compornent[T]](self.compornents[T.type.name])

proc newCompornent(self: Ecs, T: typedesc) =
  self.compornents[T.type.name] = Compornent[T](
    index: initTable[EntityId, int](),
    freeIndex: @[],
    compornents: newSeq[T]())

proc get*(self: Ecs, entity: Entity, T: typedesc): T {. inline .} =
  self.compornentsOf(T).get(entity)

proc deleteEntity(self: Ecs, entity: Entity) =
  for c in self.compornents.values:
    c.remove(entity)

proc assign*[T](self: Entity, compornent: T) {. inline .} =
  self.ecs.assign(self, compornent)

proc get*(self: Entity, T: typedesc): T {. inline .} =
  self.ecs.get(self, T)

proc isValid*(self: Entity): bool {. inline .} =
  self.id != InvalidEntityId

proc has*(self: Entity, T: typedesc): bool =
  self.ecs.has(T) and self.ecs.compornentsOf(T).has(self)

proc delete*(self: Entity) =
  self.ecs.deleteEntity(self)
  self.id = InvalidEntityId

suite "ECS test":
  setup:
    let ecs = Ecs()

  test "new entity":
    check(ecs.newEntity.id == 1)
    check(ecs.newEntity.id == 2)
    check(ecs.newEntity.id == 3)

  test "assign":
    type Coord = ref object
      x: int
      y: int
    let e = ecs.newEntity
    check(e.has(Coord) == false)
    check(e.has(int) == false)
    e.assign(Coord(x: 23, y: 9))
    e.assign(255)
    check(e.has(Coord))
    check(e.has(int))
    let c = e.get(Coord)
    check(c.x == 23)
    check(c.y == 9)
    check(e.get(int) == 255)

  test "delete":
    type Foo = ref object
    check(ecs.newEntity.id == 1)
    check(ecs.newEntity.id == 2)
    let
      e1 = ecs.newEntity
      e2 = ecs.newEntity
    check(ecs.newEntity.id == 5)
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
    let e3 = ecs.newEntity
    check(e3.id == 6)
    e3.assign(Foo())
    e3.assign(44)
    check(e3.has(Foo))
    check(e3.has(int))
    check(e3.get(int) == 44)

  test "for each":
    for n in 1..10:
      let e = ecs.newEntity
      e.assign(n * 2)
      if e.id == 5:
        e.delete()
    var result = newSeq[int]()
    for v in ecs.compornentsOf(int):
      result.add(v)
    check(result == [2, 4, 6, 8, 12, 14, 16, 18, 20])
