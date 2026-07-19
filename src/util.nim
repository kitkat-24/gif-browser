import pixie/fileformats/gif
import raylib
import std/[assertions, os, strformat, strutils]

type GifAnimation* = ref object
  textures*: seq[Texture2D]
  delays*: seq[float32] # Storing variable frame timings securely
  width*: int32
  height*: int32
  frameTimer*: float32
  curFrame*: int
  frames*: int

proc loadGifAnimation*(path: string): GifAnimation =
  # Have to read GIF with Pixie just to get frame delays bc raylib discard them :/
  let rawGif = decodeGif(readFile(path))
  
  # Loads full give data into one image buffer (width/height is size of single frame)
  var frames: int32 = 0
  let rayGif = loadImageAnim(path, frames) # frames is out param set by func

  # Have to do a bit of wizardry to work with the C pointer arithmetic in Nim
  let size = rayGif.width * rayGif.height * 4
  let data = cast[ptr UncheckedArray[uint8]](rayGif.data) # 
  
  result = GifAnimation()
  result.width = rayGif.width
  result.height = rayGif.height
  result.frames = frames
  
  for i in 0..<frames:
    result.delays.add(rawGif.intervals[i])
    # Note 1: Nim only lets you use toOpenArray as a function param or return value (can't initialize a variable with it)
    # Note 2: We have to use a WeakImage so that raylib doesn't try to free it (Nim Image object destructor will invoke 
    # raylib heap free)
    # Note 3: I first tried using loadImageFromMemory(), but that seems to be a very niche function. Only use I could 
    # find of it was in raylib to copy an image from the clipboard (so it's like the raw file buffer in memory, I guess)
    let rayFrame = toWeakImage(data.toOpenArray(i*size, (i+1)*size - 1), rayGif.width, rayGif.height, UncompressedR8g8b8a8)
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
    
proc findGifs*(dirPath: string): seq[string] =
  # Make sure the directory actually exists first
  assert(dirExists(dirPath), fmt"Error: Directory does not exist: {dirPath}")
  
  # walkDir returns a tuple: (kind, path)
  for kind, path in walkDir(dirPath):
    # pcFile ensures we only look at files, ignoring subfolders
    if kind == pcFile and path.toLowerAscii.endsWith(".gif"):
      result.add(path)
      
    echo result
