import std/[assertions, os, strformat, strutils]

    
proc findGifs*(dirPath: string): seq[string] =
  # Make sure the directory actually exists first
  assert(dirExists(dirPath), fmt"Error: Directory does not exist: {dirPath}")
  
  # walkDir returns a tuple: (kind, path)
  for kind, path in walkDir(dirPath):
    # pcFile ensures we only look at files, ignoring subfolders
    if kind == pcFile and path.toLowerAscii.endsWith(".gif"):
      result.add(path)
      
