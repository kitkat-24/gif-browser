import raylib
import gifbrowser/[layout, readGif, naylibWrapper]
import std/[strformat]
import malebolgia

proc main() =
  # Plain window with no native UI titlebar
  setConfigFlags(flags(WindowUndecorated))
  
  initWindow(800, 600, "GIF Canvas View")
  defer: closeWindow()
  setTargetFPS(60)
  setTraceLogLevel(TraceLogLevel.Error)

  let testFile = readFile("path.txt")
  let gifFiles = findGifs(testFile)
  
  let 
    tileWidth = 120
    tileHeight = 120
  
  # Read and resize all gifs in parallel
  var m = createMaster() # Malebolgia master thread
  var buffers = newSeq[ImBuffer](gifFiles.len)
  m.awaitAll:
    for i, file in gifFiles:
      m.spawn readGif(file, tileWidth, tileHeight) -> buffers[i]
      
  # Now send GIF frame data to GPU and collect Raylib handles
  var gifs = newSeq[GifAnimation](gifFiles.len)
  for i, buf in buffers:
    gifs[i] = loadGifAnimation(buf)
    
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