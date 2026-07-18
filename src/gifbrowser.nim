import raylib

proc main() =
  # Plain window with no native UI titlebar
  setConfigFlags(flags(WindowUndecorated))
  
  initWindow(800, 600, "GIF Canvas View")
  setTargetFPS(60)

  # Main application execution loop
  while not windowShouldClose():
    # For now, close with 'Q'
    if isKeyPressed(Q):
      break

    # Frame drawing pipeline
    # --------------------------------------------------------------------------
    beginDrawing()
    clearBackground(Black)
    
    # Example shape
    drawRectangleRounded(Rectangle(x: 50,y: 50,width: 200,height: 200), 0.1, 4, DarkGray)
    
    endDrawing()
    # --------------------------------------------------------------------------

  closeWindow()

if isMainModule:
  main()