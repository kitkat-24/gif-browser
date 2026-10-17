import raylib
import gifbrowser/[layout, naylibWrapper, gif, helpers]
import std/[strformat]
import malebolgia

proc main() =
  # Plain window with no native UI titlebar
  setTraceLogLevel(TraceLogLevel.Error)
  setConfigFlags(flags(WindowUndecorated))
  
  initWindow(690, 690, "GIF Canvas View")
  defer: closeWindow()
  setTargetFPS(60)

  let testFile = readFile("path.txt")
  let gifFiles = findGifs(testFile)
  
  let 
    tileWidth = 120
    tileHeight = 120
  
  # Read and resize all gifs in parallel
  var m = createMaster() # Malebolgia master thread
  var buffers = newSeq[Gif](gifFiles.len)
  m.awaitAll:
    for i, file in gifFiles:
      m.spawn decodeGif(readFile(file)) -> buffers[i]
  # for i, file in gifFiles:
  #   buffers[i] = readGif(file)

  # Now send GIF frame data to GPU and collect Raylib handles
  var gifs = newSeq[GifAnimation](gifFiles.len)
  for i, gif in buffers:
    gifs[i] = loadGifAnimation(gif)
    
  let 
    layout = ColFlowLayout(
      pos: Vector2(0, 0),
      cols: 5,
      cellWidth: 120,
      cellHeight: 120,
      pad: 15
    )
    rotation = 0.float32
    scrollSpeed = 100'f32
  var 
    curHeight = 0
  
  # Main application execution loop
  while not windowShouldClose():
    # For now, close with 'Q'
    if isKeyPressed(Q):
      takeScreenshot("foo.png")
      break
    
    # Handle scroll
    let mov = getMouseWheelMoveV()
    curHeight += (mov.y * scrollSpeed).int
    curHeight = min(max(curHeight, 0), getScreenHeight())

    # Frame drawing pipeline
    # --------------------------------------------------------------------------
    beginDrawing()
    clearBackground(Black)
    
    let dt = getFrameTime()
    setupLayout(layout)

    for gif in gifs:
      var (pos, scale) = getGridPos(layout, gif.width, gif.height)
      pos.y -= curHeight.float32
      if pos.y.int + layout.cellHeight < 0:
        continue
      # We draw top->bottom, so once one is off the screen, we're done
      if pos.y.int > getScreenHeight():
        break

      updateFrameData(gif, dt)
      drawTexture(gif.textures[gif.curFrame], pos, rotation, scale, White)

    endDrawing()
    # --------------------------------------------------------------------------

if isMainModule:
  main()