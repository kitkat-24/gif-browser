## Handling UI layout of textures and such
import raylib
import std/[assertions]

type GridLayout* = object
  pos*: Vector2
  width*: int
  height*: int
  cellWidth*: int
  cellHeight*: int
  pad*: int

func Vector2*(x, y: int): Vector2 = 
  ## Int to Raylib Vector2 wrapper
  Vector2(x: x.float32, y: y.float32)

proc `+`*(a, b: Vector2): Vector2 =
  ## Add Vector2s
  Vector2(x: a.x + b.x, y: a.y + b.y)

func getGridPos*(g: GridLayout, i: int): Vector2 =
  ## Return position in the grid, fills top->bottom, left->right
  let cols = g.width div (g.cellWidth + g.pad)
  assert(cols > 0, "Cannot have grid with 0 columns!")
  let
    row = i div cols
    col = i mod cols
  
  let rel = Vector2(col * (g.cellWidth+g.pad) + g.pad, row * (g.cellHeight+g.pad) + g.pad)
  result = rel + g.pos
  