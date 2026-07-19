import raylib
import util

proc main() =
  # Plain window with no native UI titlebar
  setConfigFlags(flags(WindowUndecorated))
  
  initWindow(800, 600, "GIF Canvas View")
  defer: closeWindow()
  setTargetFPS(60)

  let testFile = readFile("path.txt")
  let gif = loadGifAnimation(testFile)

  # Main application execution loop
  var i = 0
  while not windowShouldClose():
    # For now, close with 'Q'
    if isKeyPressed(Q):
      break

    # Frame drawing pipeline
    # --------------------------------------------------------------------------
    beginDrawing()
    clearBackground(White)
    
    drawTexture(gif.textures[i], getScreenWidth() div 2, getScreenHeight() div 2, White)
    
    endDrawing()
    # --------------------------------------------------------------------------

    i += 1
    i = i.mod(gif.textures.len)


if isMainModule:
  main()