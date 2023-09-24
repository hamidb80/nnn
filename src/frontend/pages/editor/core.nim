import std/[sets, tables, strutils, sequtils, options, sugar, enumerate]
import std/[jsffi, dom, asyncjs, jsconsole]

import karax/[vdom], questionable

import ../../../common/[datastructures]
import ../../utils/[browser, js]


type
  TwNode* = TreeNodeRec[TwNodeData]
  Index* = int

  TwNodeData* = object
    visibleChildren*: bool ## to show in tree view
    component*: Component  ## the component that is instanciated from
    hooks*: Hooks          ## all the life cycle hooks and data retrival implemented lazy

  CallBack* = proc(data: JsObject)

  MountedBy* = enum
    mbUser         ## via interaction
    mbDeserializer ## via deserializer when restoring information

  TwNodeMode* = enum
    tmInteractive      ## for interaction
    tmOutputGeneration ## for serialization
    # tmDebug            ## for debug

  TwNodeStatusCode* = enum
    tsNothing
    tsLoading
    tsInfo
    tsSuccess
    tsWarning
    tsError

  TwNodeStatus = tuple[code: TwNodeStatusCode, msg: string]

  Hooks* = ref object
    componentTable*: proc(): ComponentsTable ## component table that is built with at the beginning

    dom*: proc(): Element                ## corresponding DOM element
    self*: proc(): TwNode                ## the node cotaining this

    role*: proc(child: Index): string    ## name of the node made by himself
    mark*: proc(child: Index)

    status*: proc(): TwNodeStatus        ## internal status of the node e.g. error

    mounted*: proc(by: MountedBy, mode: TwNodeMode) ## after creating and attaching to the parent
    die*: proc()                         ## before unmounts from DOM

    focus*: proc()                       ## when selected
    blur*: proc()                        ## when unselected
    hover*: proc()                       ## when mouse is over it
    unhover*: proc()                     ## when mouse leaves

    attachNode*: proc(n: TwNode, at: Index)
    detachNode*: proc(at: Index)

    capture*: proc(): JsObject           ## returns internal states
    restore*: proc(input: JsObject)      ## restores internal states
    refresh*: proc()                     ## refreshes, can be used before render called
    render*: proc(): Option[Future[void]] ## renders forcefully, used after restore

    acceptsAsChild*: proc(): seq[cstring] ## accepts what tags as child? use '*' for any
    settings*: proc(): seq[SettingsPart] ## settings page
    # options: proc(): seq[string] ## can add additional nodes?
    # actions: proc(): seq[string] ## can add additional nodes?

  SettingsPart* = object
    field*, icon*: string
    editorData*: proc(): EditorInitData

  EditorInitData* = object
    name*: string    ## component name of editor
    input*: JsObject ## initial input of editor
    updateCallback*: CallBack

  EditorInit* = proc(input: JsObject, updateCallback: CallBack): VNode

  ComponentsTable* = TableRef[cstring, Component] ## components by name

  Component* = ref object
    name*, icon*: string ## name of the component
    tags*: seq[string]   ## inline/media/<special component name>
    init*: proc(): Hooks ## creates new instance

## ---- syntax sugar
proc dom*(t: TwNode): auto = t.data.hooks.dom()
proc componentTable*(t: TwNode): auto = t.data.hooks.componentTable()
proc mounted*(t: TwNode, by: MountedBy,
    mode: TwNodeMode): auto = t.data.hooks.mounted(by, mode)
proc die*(t: TwNode) = t.data.hooks.die()
proc status*(t: TwNode): auto = t.data.hooks.status()
proc role*(t: TwNode, child: Index): auto = t.data.hooks.role(child)
proc mark*(t: TwNode, child: Index): auto = t.data.hooks.mark(child)
proc focus*(t: TwNode) = t.data.hooks.focus()
proc blur*(t: TwNode) = t.data.hooks.blur()
proc hover*(t: TwNode) = t.data.hooks.hover()
proc unhover*(t: TwNode) = t.data.hooks.unhover()
proc attachNode*(t, n: TwNode, i: Index) = t.data.hooks.attachNode(n, i)
proc detachNode*(t: TwNode, i: Index) = t.data.hooks.detachNode(i)
proc capture*(t: TwNode): auto = t.data.hooks.capture()
proc restore*(t: TwNode, input: JsObject) = t.data.hooks.restore(input)
proc refresh*(t: TwNode) = t.data.hooks.refresh()
proc render*(t: TwNode): auto = t.data.hooks.render()
proc acceptsAsChild*(t: TwNode): auto = t.data.hooks.acceptsAsChild()
proc settings*(t: TwNode): auto = t.data.hooks.settings()

proc firstChild*(t: TwNode, cname: string): TwNode =
  for ch in t.children:
    if ch.data.component.name == cname:
      return ch
  nil

proc serialize*(t: TwNode): TreeNodeRaw[JsObject] =
  TreeNodeRaw[JsObject](
    name: t.data.component.name.cstring,
    data: t.capture,
    children: t.children.map(serialize))

proc instantiate*(c: Component, ct: ComponentsTable): TwNode =
  let node = TwNode(data: TwNodeData(
    visibleChildren: true,
    component: c,
    hooks: c.init()))

  node.data.hooks.self = () => node
  node.data.hooks.componentTable = () => ct
  node

proc attach*(father, child: TwNode, at: int) =
  child.father = father
  father.attachNode child, at

# ---------------------

type
  AppState* = enum
    asTreeView
    asSelectComponent
    asSetting

  InsertionMode* = enum
    imBefore
    imAfter
    imAppend

  App* = object
    version*: string
    state*: AppState

    editors*: Table[cstring, EditorInit]
    components*: ComponentsTable
    componentsByTags*: Table[cstring, seq[cstring]]

    tree*: TwNode                ## tree of nodes from root
    selected*: HashSet[TreePath] ## selected nodes
    focusedPath*: TreePath
    focusedNode*: TwNode

    availableComponents*, filteredComponents*: seq[Component]
    filterString*: cstring
    listIndex*: int              ## used for keep tracking of selected component
    insertionMode*: InsertionMode


func register*(a: var App, name: string, e: EditorInit) =
  a.editors[name] = e

func register*(a: var App, c: Component) =
  let cname = c.name.toLowerAscii
  a.componentsByTags.add cname, cname
  for t in c.tags:
    a.componentsByTags.add t, cname

func regiterComponents*(a: var App) =
  for c in a.components.values:
    a.register c

func add*(ct: var ComponentsTable, cs: openArray[Component]) =
  for n in cs:
    ct[n.name] = n


proc serialize*(app: App): TreeNodeRaw[JsObject] =
  app.tree.serialize

proc deserizalizeImpl(
  ct: ComponentsTable,
  root: Element,
  j: TreeNodeRaw[JsObject],
  allFutures: var seq[Future[void]],
  wrap: bool,
): TwNode =
  let cname = $j.name
  result = instantiate(ct[cname], ct)

  if wrap: # and cname == "root":
    result.data.hooks.dom = () => root

  for i, ch in enumerate j.children:
    result.attach deserizalizeImpl(ct, root, ch, allFutures, false), i

  result.data.hooks.componentTable = () => ct
  result.restore j.data
  result.mounted mbDeserializer, tmInteractive

  if fut =? result.render:
    add allFutures, fut

proc deserizalize*(
  ct: ComponentsTable,
  j: TreeNodeRaw[JsObject],
  elem: Option[Element] = none Element,
  wait = true,
  wrap = true,
): Future[TwNode] =
  var
    allFutures: seq[Future[void]]
    el =
      if t =? elem: t
      else: createElement("div", {"class": "tw-content"})
    data =
      if wrap and j.name != "root":
        TreeNodeRaw[JsObject](
          name: "root",
          children: @[j])
      else: j

    payload = deserizalizeImpl(ct, el, data, allFutures, wrap)

  newPromise proc(resolve: proc(t: TwNode)) =
    if wait:
      allFutures.waitAll proc =
        resolve payload
    else:
      resolve payload
