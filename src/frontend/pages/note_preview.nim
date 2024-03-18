import std/[tables]
import std/[dom, jsconsole, jsffi, asyncjs]

import karax/[karax, karaxdsl, vdom, vstyles]

import ../components/[snackbar, ui]
import ../utils/[browser, js, api]
import ../../common/[types, datastructures, conventions]
import ../../backend/database/[models]
import ./editor/[core, components]


type
  RelTagPath = tuple[tagid: Id, index: int]

var
  compTable = defaultComponents()
  tags: Table[Str, Tag]
  note: NoteItemView
  html = c""

proc fetchNote(id: Id): Future[void] =
  newPromise proc(resolve, reject: proc()) =
    apiGetNote id, proc(n: NoteItemView) =
      deserizalize(compTable, n.data)
      .dthen proc(t: TwNode) =
        note = n
        html = t.dom.innerHtml
        redraw()

proc fetchTags(): Future[void] =
  newPromise proc(resolve, reject: proc()) =
    apiGetTagsList proc(tagsList: seq[Tag]) =
      for t in tagsList:
        tags[t.label] = t
      resolve()

# ----- UI

proc notePreviewC(n: NoteItemView): VNode =
  buildHtml:
    tdiv(class = "card my-3 masonry-item border rounded bg-white"):
      tdiv(class = "card-body"):
        tdiv(class = "tw-content"):
          if html != "":
            verbatim html
          else:
            text "loading..."

      tdiv(class = "m-2"):
        for r in n.rels:
          tagViewC tags[r.label], r.value, noop

proc createDom: Vnode =
  echo "just redrawn"

  result = buildHtml tdiv:
    snackbar()

    nav(class = "navbar navbar-expand-lg bg-white"):
      tdiv(class = "container-fluid"):
        a(class = "navbar-brand", href = "#"):
          icon "fa-search fa-xl me-3 ms-1"
          text "Explore"

    tdiv(class = "note-preview d-flex justify-content-center"):
      notePreviewC note


when isMainModule:
  setRenderer createDom
  let id = parseInt getWindowQueryParam "id"
  waitAll [fetchTags(), fetchNote id], proc =
    redraw()
