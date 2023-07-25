import std/[dom, asyncjs]
import std/[sugar]


proc qi*(id: string): Element =
  document.getElementById id

template winEl*: untyped =
  window.document.body

proc valueAsNumber*[T](el: Element): T {.importjs: "#.valueAsNumber".}

let nonPassive* = AddEventListenerOptions(passive: false)

proc setTimeout*(delay: Natural, action: proc) =
  discard setTimeout(action, delay)


proc newPromise*[T, E](action: proc(
  resovle: proc(t: T),
  reject: proc(e: E)
)): Future[T] {.importjs: "new Promise(@)".}


proc downloadUrl*(name, dataurl: cstring) =
  let link = document.createElement("a")
  link.setAttr "href", dataurl
  link.setAttr "target", "_blank"
  link.setAttr "download", name
  link.click

proc imageDataUrl(file: dom.File): Future[cstring] =
  newPromise proc (resolve: proc(t: cstring), reject: proc(e: Event)) =
    var reader = newFileReader()
    reader.onload = (ev: Event) => resolve("ev.target.result") # resolve(ev.target.result)
    reader.onerror = reject
    reader.onabort = reject
    reader.readAsDataURL(file)
