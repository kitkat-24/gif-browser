# This file is a modified version of pixie/fileformats/gif.nim
# From the Pixie library https://github.com/treeform/pixie
#
# Pixie is provided under the following MIT license:
#
# The MIT License (MIT)
# 
# Copyright (c) 2020 Andre von Houck and Ryan Oldenburg
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy of this 
# software and associated documentation files (the "Software"), to deal in the Software 
# without restriction, including without limitation the rights to use, copy, modify, 
# merge, publish, distribute, sublicense, and/or sell copies of the Software, and to 
# permit persons to whom the Software is furnished to do so, subject to the following 
# conditions:
# 
# The above copyright notice and this permission notice shall be included in all copies 
# or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, 
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A 
# PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT 
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF 
# CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE 
# OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
######################################################################################
#
# Modifications:
#   - Fixing support for all disposal methods
#       - This means returned GIF should have fully formed frames, no partial images
#   - Returns RGBA (not RGBX "premultiplied alpha") frame buffers
#   - Some logical reorganization to make it read better


import chroma, flatty/binny, pixie/common, std/math, vmath, zippy/bitstreams, std/strutils, std/strformat

# See: https://www.w3.org/Graphics/GIF/spec-gif89a.txt

const gifSignatures* = @["GIF87a", "GIF89a"]

type
  ImageRGBA* = ref object
    ## Image object that holds bitmap data in normal RGBA format.
    width*, height*: int
    data*: seq[ColorRGBA]

  Gif* = ref object
    frames*: seq[ImageRGBA]
    intervals*: seq[float32] # Floating point seconds
    duration*: float32

  ControlExtension = object
    fields: uint8
    delayTime: uint16
    transparentColorIndex: uint8
    
proc newImRGBA(x, y: int): ImageRGBA =
  result = ImageRGBA()
  result.width = x
  result.height = y
  result.data = newSeq[ColorRGBA](x * y)
  
proc copy(im: ImageRGBA): ImageRGBA =
  result = newImRGBA(im.width, im.height)
  for i in 0 ..< im.data.len:
    result.data[i] = im.data[i]
    
template dataIndex(image: ImageRGBA, x, y: int): int =
  image.width * y + x

template failInvalid() =
  raise newException(PixieError, "Invalid GIF buffer, unable to load")

when defined(release):
  {.push checks: off.}
  
proc decompressLZW(lzwData: string, minCodeSize: int): seq[int] =
  # Decompress LZW color indices
  let
    clearCode = 1 shl minCodeSize
    endCode = clearCode + 1

  var
    b = BitStreamReader(
      src: cast[ptr UncheckedArray[uint8]](lzwData.cstring),
      len: lzwData.len
    )
    codeSize = minCodeSize + 1
    colorIndexes: seq[int]
    table = newSeq[(int, int)](endCode + 1)
    prev: tuple[offset, len: int]

  while true:
    let code = b.readBits(codeSize).int
    if b.bitsBuffered < 0:
      failInvalid()
    if code == endCode:
      break

    if code == clearCode:
      codeSize = minCodeSize + 1
      table.setLen(endCode + 1)
      prev = (0, 0)
      continue

    # Increase the code size if needed
    if table.len == (1 shl codeSize) - 1 and codeSize < 12:
      inc codeSize

    let start = colorIndexes.len
    if code < table.len: # If we have seen the code before
      if code < clearCode:
        colorIndexes.add(code)
        if prev.len > 0:
          table.add((prev.offset, prev.len + 1))
        prev = (start, 1)
      else:
        let (offset, len) = table[code]
        for i in 0 ..< len:
          colorIndexes.add(colorIndexes[offset + i])
        table.add((prev.offset, prev.len + 1))
        prev = (start, len)
    else:
      if prev[1] == 0:
        failInvalid()
      for i in 0 ..< prev[1]:
        colorIndexes.add(colorIndexes[prev[0] + i])
      colorIndexes.add(colorIndexes[prev[0]])
      table.add((start, prev.len + 1))
      prev = (start, prev.len + 1)
  return colorIndexes

proc decodeGif*(data: string): Gif {.raises: [PixieError].} =
  ## Decodes GIF data.
  if data.len < 13:
    failInvalid()

  if data[0 .. 5] notin gifSignatures:
    raise newException(PixieError, "Invalid GIF file signature")

  result = Gif()

  let
    screenWidth = data.readInt16(6).int
    screenHeight = data.readInt16(8).int
    globalFlags = data.readUint8(10).int
    hasGlobalColorTable = (globalFlags and 0b10000000) != 0
    globalColorTableSize = 2 ^ ((globalFlags and 0b00000111) + 1)
    bgColorIndex = data.readUint8(11).int

  if hasGlobalColorTable and bgColorIndex >= globalColorTableSize:
    failInvalid()

  var pos = 13

  if hasGlobalColorTable and pos + globalColorTableSize * 3 > data.len:
    failInvalid()

  var
    globalColorTable: seq[ColorRGBA]
    bgColor: ColorRGBA
  if hasGlobalColorTable:
    globalColorTable.setLen(globalColorTableSize)
    for i in 0 ..< globalColorTable.len:
      globalColorTable[i] = rgba(
        data.readUint8(pos + 0),
        data.readUint8(pos + 1),
        data.readUint8(pos + 2),
        255
      )
      pos += 3
    bgColor = globalColorTable[bgColorIndex]

  proc skipSubBlocks() =
    while true: # Skip data sub-blocks
      if pos + 1 > data.len:
        failInvalid()

      let subBlockSize = data.readUint8(pos).int
      inc pos

      if subBlockSize == 0:
        break

      pos += subBlockSize
      if pos > data.len:
        failInvalid()

  var 
    controlExtension: ControlExtension
    canvas: ImageRGBA = newImRGBA(screenWidth, screenHeight)

  while true:
    if pos + 1 > data.len:
      failInvalid()

    let blockType = data.readUint8(pos)
    inc pos

    case blockType:
    of 0x2c: # Image
      if pos + 9 > data.len:
        failInvalid()

      let
        imageLeftPos = data.readUint16(pos + 0).int
        imageTopPos = data.readUint16(pos + 2).int
        imageWidth = data.readUint16(pos + 4).int
        imageHeight = data.readUint16(pos + 6).int
        imageFlags = data.readUint8(pos + 8)
        hasLocalColorTable = (imageFlags and 0b10000000) != 0
        interlaced = (imageFlags and 0b01000000) != 0
        localColorTableSize = 2 ^ ((imageFlags and 0b00000111) + 1)

      pos += 9

      if imageWidth > screenWidth or imageHeight > screenHeight:
        raise newException(PixieError, "Invalid GIF frame dimensions")

      if hasLocalColorTable and pos + localColorTableSize * 3 > data.len:
        failInvalid()

      var localColorTable: seq[ColorRGBA]
      if hasLocalColorTable:
        localColorTable.setLen(localColorTableSize)
        for i in 0 ..< localColorTable.len:
          localColorTable[i] = rgba(
            data.readUint8(pos + 0),
            data.readUint8(pos + 1),
            data.readUint8(pos + 2),
            255
          )
          pos += 3

      if pos + 1 > data.len:
        failInvalid()

      let minCodeSize = data.readUint8(pos).int
      inc pos

      if minCodeSize < 2 or minCodeSize > 8:
        failInvalid()

      # The image data is contained in a sequence of sub-blocks
      var lzwDataBlocks: seq[(int, int)] # (offset, len)
      while true:
        if pos + 1 > data.len:
          failInvalid()

        let subBlockSize = data.readUint8(pos).int
        inc pos

        if subBlockSize == 0:
          break

        if pos + subBlockSize > data.len:
          failInvalid()

        lzwDataBlocks.add((pos, subBlockSize))

        pos += subBlockSize

      var lzwDataLen: int
      for (_, len) in lzwDataBlocks:
        lzwDataLen += len

      var
        lzwData = newString(lzwDataLen)
        i: int
      for (offset, len) in lzwDataBlocks:
        copyMem(lzwData[i].addr, data[offset].unsafeAddr, len)
        i += len
        
      let colorIndexes = decompressLZW(lzwData, minCodeSize)
      if colorIndexes.len != imageWidth * imageHeight:
        echo(fmt"Color index len = {colorIndexes.len}, w x h = {imageWidth * imageHeight}")
        failInvalid()
        
      let 
        transparencyEnabled = (controlExtension.fields and 1) != 0
        transparentColorIndex = if transparencyEnabled: controlExtension.transparentColorIndex.int else: -1


      # Write frame data into temp buffer
      # Note that in the case the encoded frame is smaller than the "logical
      # screen", we are going to double copy just to make life easier than 
      # tracking the in-place write. This could be improved
      let image = newImRGBA(imageWidth, imageHeight)
      if hasLocalColorTable:
        for i, colorIndex in colorIndexes:
          if colorIndex >= localColorTable.len:
            # failInvalid()
            continue
          if colorIndex != transparentColorIndex:
            image.data[i] = localColorTable[colorIndex]
      else:
        for i, colorIndex in colorIndexes:
          if colorIndex >= globalColorTable.len:
            # failInvalid()
            continue
          if colorIndex != transparentColorIndex:
            image.data[i] = globalColorTable[colorIndex]

      # Just copyMem the rows into the right place. I've only ever seen
      # interlaced for the first frame so this is unlikely to be a hot path.
      if interlaced:
        echo("De-interlacing gif")
        let deinterlaced = newImRGBA(image.width, image.height)
        var
          y: int
          i: int
        while i < image.height:
          copyMem(
            deinterlaced.data[deinterlaced.dataIndex(0, i)].addr,
            image.data[image.dataIndex(0, y)].addr,
            image.width * 4
          )
          i += 8
          inc y
        i = 4
        while i < image.height:
          copyMem(
            deinterlaced.data[deinterlaced.dataIndex(0, i)].addr,
            image.data[image.dataIndex(0, y)].addr,
            image.width * 4
          )
          i += 8
          inc y
        i = 2
        while i < image.height:
          copyMem(
            deinterlaced.data[deinterlaced.dataIndex(0, i)].addr,
            image.data[image.dataIndex(0, y)].addr,
            image.width * 4
          )
          i += 4
          inc y
        i = 1
        while i < image.height:
          copyMem(
            deinterlaced.data[deinterlaced.dataIndex(0, i)].addr,
            image.data[image.dataIndex(0, y)].addr,
            image.width * 4
          )
          i += 2
          inc y

        image.data = move deinterlaced.data

      # Write image to canvas
      for y in 0 ..< image.height:
        for x in 0 ..< image.width:
          let 
            yOut = y + imageTopPos
            xOut = x + imageLeftPos
            pix = image.data[y * image.width + x]
          if pix.a > 0:
            canvas.data[yOut * canvas.width + xOut] = pix
      result.frames.add(canvas.copy())
      result.intervals.add(controlExtension.delayTime.float32 / 100)

      # Note: Disposal methods only apply to the area of the canvas covered by the last image (don't wipe whole image necessarily)
      let disposalMethod = (controlExtension.fields and 0b00011100) shr 2
      if (disposalMethod == 0 or disposalMethod == 1): # do not dispose
        discard
      elif disposalMethod == 2: # restore to background
        let disposalColor = if transparencyEnabled: rgba(0,0,0,0) else: bgColor
        for y in 0 ..< image.height:
          for x in 0 ..< image.width:
            let 
              yOut = y + imageTopPos
              xOut = x + imageLeftPos
            canvas.data[yOut * canvas.width + xOut] = disposalColor
      else: # 3 => restore to previous
        if result.frames.len == 1: # First frame 
          continue
          # failInvalid()
        for y in 0 ..< image.height:
          for x in 0 ..< image.width:
            let 
              yOut = y + imageTopPos
              xOut = x + imageLeftPos
            canvas.data[yOut * canvas.width + xOut] = result.frames[^2].data[yOut * canvas.width + xOut]

      # Reset the control extension since it only applies to one image
      controlExtension = ControlExtension()

    of 0x21: # Extension
      if pos + 1 > data.len:
        failInvalid()

      let extensionType = data.readUint8(pos + 0)
      inc pos

      case extensionType:
      of 0xf9:
        # Graphic Control Extension
        if pos + 1 > data.len:
          failInvalid()

        let blockSize = data.readUint8(pos).int
        inc pos

        if blockSize != 4:
          failInvalid()

        if pos + blockSize > data.len:
          failInvalid()

        controlExtension.fields = data.readUint8(pos + 0)
        controlExtension.delayTime = data.readUint16(pos + 1)
        controlExtension.transparentColorIndex = data.readUint8(pos + 3)

        pos += blockSize
        inc pos # Block terminator

      of 0xfe:
        # Comment
        skipSubBlocks()

      # of 0x01:
      #   # Plain Text

      of 0xff:
        # Application Specific
        if pos + 1 > data.len:
          failInvalid()

        let blockSize = data.readUint8(pos).int
        inc pos

        if blockSize != 11:
          failInvalid()

        if pos + blockSize > data.len:
          failInvalid()

        pos += blockSize

        skipSubBlocks()

      else:
        raise newException(
          PixieError,
          "Unexpected GIF extension type " & toHex(extensionType)
        )

    of 0x3b: # Trailer
      break

    else:
      raise newException(
        PixieError,
        "Unexpected GIF block type " & toHex(blockType)
      )

  for interval in result.intervals:
    result.duration += interval


when defined(release):
  {.pop.}
