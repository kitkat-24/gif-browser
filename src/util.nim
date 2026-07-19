import pixie, pixie/fileformats/gif
import raylib

type GifAnimation* = object
  textures*: seq[Texture2D]
  delays*: seq[float32] # Storing variable frame timings securely

proc loadGifAnimation*(path: string): GifAnimation =
  let rawGif = decodeGif(readFile(path))
  
  for i, frame in rawGif.frames:
    result.delays.add(rawGif.intervals[i])
    
    # 1. Allocate a fresh, native image container inside Raylib's memory pool.
    # Passing 'nil' for the data field forces Raylib to cleanly allocate its own 
    # internal uninitialized heap space matching the dimensions.
    var raylibOwnedImg = genImageColor(
      frame.width.int32, 
      frame.height.int32, 
      Blank
    )
    
    # 2. Access the memory destination and source pointers safely
    let destData = cast[ptr UncheckedArray[ColorRGBA]](raylibOwnedImg.data)
    let srcData = cast[ptr UncheckedArray[ColorRGBX]](addr frame.data[0])
    
    let totalPixels = frame.width * frame.height
    
    # 3. Step through the buffer pixel by pixel and convert the alpha layout
    for i in 0 ..< totalPixels:
      # autoStraightAlpha handles the conversion from Pixie's RGBX to Raylib's RGBA
      destData[i] = autoStraightAlpha(srcData[i])

    result.textures.add(loadTextureFromImage(raylibOwnedImg))
