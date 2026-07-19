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
  gifs.add(loadGifAnimation(gifFiles[0]))
  # for file in gifFiles:
    # gifs.add(loadGifAnimation(file))
  var curFrame = newSeq[int](gifs.len)

  # Main application execution loop
  while not windowShouldClose():
    # For now, close with 'Q'
    if isKeyPressed(Q):
      break

    # Frame drawing pipeline
    # --------------------------------------------------------------------------
    beginDrawing()
    clearBackground(White)
    
    var 
      row = 0
      col = 0
    let 
      cols = 5
      pad = 10
      width = 100
      height = 100
      rotation = 0.float32

    # for iGif, gif in gifs:
    # Layout in grid
    let iGif = 0
    let gif = gifs[iGif]
    let pos = Vector2(x: (col*width + (col+1)*pad).toFloat, y: (row*height + (row+1)*pad).toFloat)
    echo pos
    let scale = min(width / gif.width, height / gif.height)
    echo gif
    echo fmt"w scale = {width/gif.width} h scale = {height / gif.height}, scale = {scale}"

    drawTexture(gif.textures[curFrame[iGif]], pos, rotation, scale, White)
    
    # Index incrementing
    curFrame[iGif] = (curFrame[iGif] + 1).mod(gif.textures.len)
    col = (col + 1).mod(cols)
    if col == 0:
      row += 1

    endDrawing()
    # --------------------------------------------------------------------------

if isMainModule:
  main()