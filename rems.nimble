# Package

version       = "0.0.1"
author        = "hamidb80"
description   = "Remebering Management System"
license       = "MIT"
srcDir        = "src"
bin           = @["rems"]


# Dependencies

requires "nim >= 2.0.0"
requires "checksums" # for Nim 2
requires "db_connector >= 0.1.0" # for Nim 2

requires "macroplus >= 0.2.5"
requires "caster"
requires "uuid4"
requires "questionable"
requires "prettyvec"

requires "mummy" # 0.3.2
requires "jsony" # 1.1.5
requires "ponairi" # 0.3.2
requires "waterpark >= 0.1.5"
requires "quickjwt" # 0.2.1
requires "cookiejar" # 0.3.0
requires "bale" # 1.0.0

requires "karax == 1.3.0"


# Tasks
import std/[os, strutils, strformat]

task make, "make all":
  exec "nimble html"
  exec "nimble genb"
  exec "nimble gened"
  exec "nimble gentg"
  exec "nimble gennp"
  exec "nimble genex"
  exec "nimble genlg"
  exec "nimble genps"

task genps, "":
  exec fmt"nim -d:nimExperimentalAsyncjsThen js -o:./dist/palette-studio.js src/frontend/pages/palette"

task genlg, "":
  exec fmt"nim -d:nimExperimentalAsyncjsThen js -o:./dist/script-login.js src/frontend/pages/login"

task gennp, "":
  exec fmt"nim -d:nimExperimentalAsyncjsThen js -o:./dist/note-preview.js src/frontend/pages/note_preview"

task genex, "":
  exec fmt"nim -d:nimExperimentalAsyncjsThen js -o:./dist/script-explore.js src/frontend/pages/explore"

task genb, "":
  exec fmt"nim -d:nimExperimentalAsyncjsThen js -o:./dist/script-board.js src/frontend/pages/board"

task gentg, "":
  exec fmt"nim -d:nimExperimentalAsyncjsThen js -o:./dist/script-tags.js src/frontend/pages/tags"

task gened, "":
  exec fmt"nim -d:nimExperimentalAsyncjsThen js -o:./dist/script-editor.js src/frontend/pages/editor/app"

task html, "generate index.html ./dist":
  cpfile "./src/frontend/custom.css", "./dist/custom.css"
  cpDir "./assets/", "./dist/"
  exec fmt"nim -d:frontend r src/frontend/pages/html.nim"


task prepare, "define envorment vars only for test":
  mkdir "./dist"
  mkdir getEnv("APP_DIR") / "resources"
  mkdir "./bin"

task db, "init db":
  exec "nim r src/backend/utils/db_init.nim"

task bot, "bale bot":
  exec "nim -d:bale_debug -d:ssl r src/backend/bot"

task go, "runs server + bot":
  exec """nim -d:ssl --passL:"-lcrypto" r ./src/backend/main.nim"""

task done, "runs server + bot":
  exec """nim -d:ssl --passL:"-lcrypto" -o:./bin/main.exe c ./src/backend/main.nim"""

