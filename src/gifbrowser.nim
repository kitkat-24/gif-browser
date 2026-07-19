import raylib
import gifbrowser/[layout, util]
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
    
  let 
    layout = ColFlowLayout(
      pos: Vector2(0, 0),
      cols: 5,
      cellWidth: 64,
      cellHeight: 64,
      pad: 15
    )
    rotation = 0.float32
  
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
    setupLayout(layout)

    for iGif, gif in gifs:
      let (pos, scale) = getGridPos(layout, iGif, gif.width, gif.height)
      if pos.y > getScreenHeight().float32:
        break

      updateFrameData(gif, dt)
      drawTexture(gif.textures[gif.curFrame], pos, rotation, scale, White)

    endDrawing()
    # --------------------------------------------------------------------------

if isMainModule:
  main()