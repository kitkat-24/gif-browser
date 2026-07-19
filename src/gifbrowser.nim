import raylib
import util
import std/[strformat]

proc main() =
  # Plain window with no native UI titlebar
  setConfigFlags(flags(WindowUndecorated))
  
  initWindow(800, 600, "GIF Canvas View")
  defer: closeWindow()
  setTargetFPS(60)

  let testFile = readFile("path.txt")
  let gifFiles = findGifs(testFile)
  
  var gifs = newSeq[GifAnimation]()
  for file in gifFiles:
    gifs.add(loadGifAnimation(file))
  
  # Main application execution loop
  while not windowShouldClose():
    # For now, close with 'Q'
    if isKeyPressed(Q):
      break

    # Frame drawing pipeline
    # --------------------------------------------------------------------------
    beginDrawing()
    clearBackground(Black)
    
    let dt = getFrameTime()
    
    var 
      row = 0
      col = 0
    let 
      cols = 5
      pad = 10
      width = 100
      height = 100
      rotation = 0.float32

    for iGif, gif in gifs:
      # Layout in grid
      let pos = Vector2(x: (col*width + (col+1)*pad).toFloat, y: (row*height + (row+1)*pad).toFloat)
      # echo pos
      let scale = min(width / gif.width, height / gif.height)
      # echo fmt"w scale = {width/gif.width} h scale = {height / gif.height}, scale = {scale}"
      if pos.y > getScreenHeight().float32:
        break

      updateFrameData(gif, dt)
      drawTexture(gif.textures[gif.curFrame], pos, rotation, scale, White)
      
      # Index incrementing
      col = (col + 1).mod(cols)
      if col == 0:
        row += 1

    endDrawing()
    # --------------------------------------------------------------------------

if isMainModule:
  main()