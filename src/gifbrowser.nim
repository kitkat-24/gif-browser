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
    
    let 
      layout = GridLayout(
        pos: Vector2(0, 0),
        width: 800, 
        height: 600, 
        cellWidth: 120,
        cellHeight: 120,
        pad: 15
      )
      rotation = 0.float32

    for iGif, gif in gifs:
      let pos = getGridPos(layout, iGif)
      let scale = min(layout.cellWidth / gif.width, layout.cellHeight / gif.height)
      if pos.y > getScreenHeight().float32:
        break

      updateFrameData(gif, dt)
      drawTexture(gif.textures[gif.curFrame], pos, rotation, scale, White)

    endDrawing()
    # --------------------------------------------------------------------------

if isMainModule:
  main()