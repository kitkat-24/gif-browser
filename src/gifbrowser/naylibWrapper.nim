import raylib
import gif


type GifAnimation* = ref object
  textures*: seq[Texture2D]
  delays*: seq[float32] # Storing variable frame timings securely
  width*: int32
  height*: int32
  frameTimer*: float32
  curFrame*: int
  frames*: int


proc loadGifAnimation*(rawGif: Gif): GifAnimation =
  # Have to do a bit of wizardry to work with the C pointer arithmetic in Nim
  result = GifAnimation()
  result.width  = rawGif.frames[0].width.int32
  result.height = rawGif.frames[0].height.int32
  result.frames = rawGif.frames.len
  result.delays = rawGif.intervals

  let size = result.width * result.height * 4
  
  for i in 0 ..< result.frames:
    # Note 1: Nim only lets you use toOpenArray as a function param or return value (can't initialize a variable with it)
    # Note 2: We have to use a WeakImage so that raylib doesn't try to free it (Nim Image object destructor will invoke 
    # raylib heap free)
    let rawData = cast[ptr UncheckedArray[byte]](addr rawGif.frames[i].data[0])
    let rayFrame = toWeakImage(toOpenArray(rawData, 0, size - 1), 
                               result.width, result.height, UncompressedR8g8b8a8)
    result.textures.add(loadTextureFromImage(rayFrame.Image))

proc updateFrameData*(anim: GifAnimation, dt: float32) =
  # 1. Accumulate the time passed since the last game tick
  anim.frameTimer += dt

  # 2. Get the required delay for the CURRENT frame
  let currentDelay = anim.delays[anim.curFrame]

  # 3. Check if enough time has passed to advance
  if anim.frameTimer >= currentDelay:
    # Deduct the delay time (preserves overflow time for precision)
    anim.frameTimer -= currentDelay
    
    # Move to next frame and wrap around safely using mod
    anim.curFrame = (anim.curFrame + 1) mod anim.frames