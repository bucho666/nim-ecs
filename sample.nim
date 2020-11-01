import ecs

type Coord = ref object
  x: int
  y: int

proc `$`(self: Coord): string =
  "x=" & $self.x & ",y=" & $self.y

let
  world = World()
  a = world.newEntity
    .with(42)
    .with("hello")
    .with(Coord(x: 1, y:2))
  b = world.newEntity
    .with(Coord(x: 3, y: 4))
echo a.has(int)
echo a.has(string)
echo a.has(Coord)
echo a.get(int)
echo a.get(string)
echo a.get(Coord)
echo b.get(Coord)
for c in world.componentsOf(Coord):
  c.x.inc
  c.y.inc
echo a.get(Coord)
echo b.get(Coord)
for e, c in world.componentsOf(Coord):
  c.x.inc
  c.y.inc
  e.with("world")
echo a.get(Coord)
echo b.get(Coord)
echo a.get(string)
echo b.get(string)
if a.hasAll(int, string, Coord):
  let (number, str, c) = a.getAll(int, string, Coord)
  echo number
  echo str
  echo c

for e, c in world.componentsOf(Coord):
  let (number, str) = e.getAllOrContinue(int, string)
  echo number
  echo str
  echo c
