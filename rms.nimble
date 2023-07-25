# Package

version       = "0.0.1"
author        = "hamidb80"
description   = "Remebering Management System"
license       = "MIT"
srcDir        = "src"
bin           = @["rms"]


# Dependencies

requires "nim >= 1.6.12"
requires "macroplus >= 0.2.5"
requires "karax == 1.3.0"
requires "urlon"
requires "caster"

# Tasks

task genscript, "generate script.js file in ./dist":
  exec "nim -d:nimExperimentalAsyncjsThen js -o:./dist/script.js src/main"

task genas, "generate script.js file in ./dist":
  exec "nim -d:nimExperimentalAsyncjsThen js -o:./dist/script-assets.js src/assets"

task html, "generate index.html ./dist":
  exec "nim r src/page.nim"
