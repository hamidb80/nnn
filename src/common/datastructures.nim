import std/[tables, sets, strutils]
import prettyvec
import ./types

type
  SeqTable[K, V] = Table[K, seq[V]]
  Graph*[T] = Table[T, HashSet[T]]


func add*[K, V](st: var SeqTable[K, V], key: K, val: V) =
  if key in st:
    st[key].add val
  else:
    st[key] = @[val]

func add[T](g: var Graph[T], a, b: T) =
  if a notin g:
    g[a] = initHashSet[T]()

  g[a].incl b

func remove[T](g: var Graph[T], a, b: T) =
  if a in g:
    g[a].decl b

func addConn*[T](g: var Graph[T], conn: Slice[T]) =
  g.add conn.a, conn.b
  g.add conn.b, conn.a

func removeConn*[T](g: var Graph[T], conn: Slice[T]) =
  g.remove conn.a, conn.b
  g.remove conn.b, conn.a


type
  TreeNodeRec*[D] = ref object ## used in frontend
    father*: TreeNodeRec[D]
    children*: seq[TreeNodeRec[D]]
    data*: D

  TreeNodeRaw*[D] = ref object ## used in frontend
    name*: Str
    children*: seq[TreeNodeRaw[D]]
    data*: D

  TreePath* = seq[int]

func isLeaf*(tn: TreeNodeRec or TreeNodeRaw): bool =
  tn.children.len == 0

func isRoot*(tn: TreeNodeRec): bool =
  tn.father == nil


type
  FontConfig* = object
    family*: Str
    size*: int
    style*: FontStyle
    # lineHeight: Float

  ColorTheme* = object
    bg*, fg*, st*: HexColor

  VirtualNodeDataKind* = enum
    vndkText
    vndkImage

  VisualNodeConfig* = object
    id*: Str
    theme*: ColorTheme
    data*: VisualNodeData
    font*: FontConfig # TODO move this to `VisualNodeData`
    position*: Vec2Obj # top left
    messageIdList*: seq[Id]

  VisualNodeData* = object
    case kind*: VirtualNodeDataKind
    of vndkText:
      text*: Str
    of vndkImage:
      url*: Str
      width*, height*: float

  EdgeConfig* = object
    theme*: ColorTheme
    width*: Tenth
    centerShape*: ConnectionCenterShapeKind

  ConnectionPointKind* = enum
    cpkHead, cpkTail

  EdgeData* = object
    points*: array[ConnectionPointKind, Str]
    config*: EdgeConfig

  BoardData* = object
    objects*: CTable[Str, VisualNodeConfig]
    edges*: seq[EdgeData]



func c*(bg, fg, st: int): ColorTheme =
  ColorTheme(
    bg: bg.HexColor,
    fg: fg.HexColor,
    st: st.HexColor)
