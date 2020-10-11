import ecs

type Coord = ref object
  x: int
  y: int

proc `$`(self: Coord): string =
  "x=" & $self.x & ",y=" & $self.y

let
  world = World()
  a = world.newEntity
  b = world.newEntity
a.assign(42)
a.assign("hello")
a.assign(Coord(x: 1, y:2))
b.assign(Coord(x: 3, y: 4))
echo a.has(int)
echo a.has(string)
echo a.has(Coord)
echo a.get(int)
echo a.get(string)
echo a.get(Coord)
echo b.get(Coord)
for c in world.compornentsOf(Coord):
  c.x.inc
  c.y.inc
echo a.get(Coord)
echo b.get(Coord)
for e, c in world.compornentsOf(Coord):
  c.x.inc
  c.y.inc
  e.assign("world")
echo a.get(Coord)
echo b.get(Coord)
echo a.get(string)
echo b.get(string)
