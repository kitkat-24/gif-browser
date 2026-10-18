import raylib
import raygui
import gifbrowser/[layout, naylibWrapper, gif, helpers]
import std/[strformat]
import malebolgia

proc main() =
  # Plain window with no native UI titlebar
  setTraceLogLevel(TraceLogLevel.Error)
  setConfigFlags(flags(WindowUndecorated))
  
  initWindow(790, 690, "GIF Canvas View")
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
    rotation = 0.float32
    scrollSpeed = 100'f32
    sizeStep = 10
  var 
    layout = ColFlowLayout(
      pos: Vector2(0, 0),
      cols: 5,
      cellWidth: 120,
      cellHeight: 120,
      pad: 15
    )
    curHeight = 0
  let left = layout.width().float32
  layout.maxWidth = layout.width()
  
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
      # We draw top->bottom, so once one is off the screen, we don't need to render it,
      # however want to finish the layout pass to know where to stop scrolling
      if pos.y.int <= getScreenHeight():
        updateFrameData(gif, dt)
        drawTexture(gif.textures[gif.curFrame], pos, rotation, scale, White)
    layout.currHeight = layout.height()
      
      
    guiSetStyle(GuiControl.Default, TextSize, 28) # TEXT_SIZE is a global in RayGui
    # maxWidth >= (x+1) * pad + x * width
    # maxWidth >= x * (pad + width) + pad
    # x        <= (maxWidth - pad) / (pad + width)
    if (button(Rectangle(x: left, y: layout.pad.float32, width: 85, height: 40), "+ size")):
      layout.cellWidth  += sizeStep
      layout.cellHeight += sizeStep
      layout.cols = (layout.maxWidth - layout.pad) div (layout.pad + layout.cellWidth)
      
    if (button(Rectangle(x: left, y: 2*layout.pad.float32 + 40, width: 85, height: 40), "- size")):
      if not (layout.cellWidth <= sizeStep or layout.cellHeight <= sizeStep): # Don't let 0/negative width happen...
        layout.cellWidth  -= sizeStep
        layout.cellHeight -= sizeStep
        layout.cols = (layout.maxWidth - layout.pad) div (layout.pad + layout.cellWidth)

    endDrawing()
    # --------------------------------------------------------------------------

if isMainModule:
  main()