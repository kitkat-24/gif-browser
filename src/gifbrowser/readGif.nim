# import pixie/[fileformats/gif, images, common]
import pixie
import pixie/fileformats/gif
import chroma
import std/[assertions, os, strformat, strutils]
  

type ImBuffer* = ref object
  # Holds image frame data for whole gif on the CPU
  data*: seq[colortypes.ColorRGBA]
  width*: int32
  height*: int32
  frameDelays*: seq[float32]

  
proc readGif*(path: string, x, y: int): ImBuffer {.gcsafe.} =
  # Return scaled image buffer for Raylib to send to GPU
  # (x,y) is desired output size (will rescale gif)
  # Have to mark .gcssafe. for malebolgia

  # Have to read GIF with Pixie just to get frame delays bc raylib discard them :/
  let rawGif = decodeGif(readFile(path))
  
  var buf = ImBuffer()
  buf.data = newSeq[ColorRGBA](x * y * rawGif.frames.len)
  buf.width = x.int32
  buf.height = y.int32
  buf.frameDelays = newSeq[float32](rawGif.frames.len)
  
  var c = 0
  for i in 0 ..< buf.frameDelays.len:
    let scaledFrame = rawGif.frames[i].resize(x, y)
    buf.frameDelays[i] = rawGif.intervals[i]
    
    # Have to convert to rgba for raylib
    for pixel in scaledFrame.data:
      buf.data[c] = pixel.rgba
      c += 1
      
  assert(c == buf.data.len, "Didn't fill buffer!")
  return buf
    
proc findGifs*(dirPath: string): seq[string] =
  # Make sure the directory actually exists first
  assert(dirExists(dirPath), fmt"Error: Directory does not exist: {dirPath}")
  
  # walkDir returns a tuple: (kind, path)
  for kind, path in walkDir(dirPath):
    # pcFile ensures we only look at files, ignoring subfolders
    if kind == pcFile and path.toLowerAscii.endsWith(".gif"):
      result.add(path)
      
