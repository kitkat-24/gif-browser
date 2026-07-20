## Handling UI layout of textures and such
import raylib
import std/[assertions, math, strformat]

type ColFlowLayout* = ref object
  pos*: Vector2
  cols*: int
  nextY: seq[int]
  cellWidth*: int
  cellHeight*: int
  pad*: int

func Vector2*(x, y: int): Vector2 = 
  ## Int to Raylib Vector2 wrapper
  Vector2(x: x.float32, y: y.float32)

proc `+`*(a, b: Vector2): Vector2 =
  ## Add Vector2s
  Vector2(x: a.x + b.x, y: a.y + b.y)

proc setupLayout*(c: ColFlowLayout) =
  ## Initialize the flow layout for this frame
  c.nextY = newSeq[int](c.cols)
  for i in 0..<c.cols:
    c.nextY[i] = c.pad

proc getGridPos*(g: ColFlowLayout, i, width, height: int): (Vector2, float32) =
  ## Return position in the grid and scale, fills top->bottom, left->right
  let
    col = i mod g.cols

  let scale = g.cellWidth / width
  let finalHeight = round(height.float32 * scale).int
  # echo fmt"{i} ({width} x {height}): scale={scale:.3}, height={finalHeight}"

  
  let rel = Vector2(col * (g.cellWidth+g.pad) + g.pad, g.nextY[col])
  g.nextY[col] += finalHeight + g.pad          
  result = (rel + g.pos, scale)
  