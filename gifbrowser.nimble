# Package

version       = "0.1.0"
author        = "Kat"
description   = "A visual gif browser for local files"
license       = "MIT"
srcDir        = "src"
bin           = @["gifbrowser"]


# Dependencies

requires "nim >= 2.2.6"
requires "naylib >= 26.08.0"
requires "pixie >= 6.1.0"

requires "malebolgia >= 0.1.0"