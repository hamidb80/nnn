## https://stackoverflow.com/questions/3498844/sqlite-string-contains-other-string-query

import std/[times, json, options, strutils, strformat, sequtils, tables, sha1]

import ponairi
include jsony_fix

import ./models
import ../../common/[types, datastructures]


template R: untyped {.dirty.} =
  typeof result


func initEmptyNote*: Note =
  Note(data: newNoteData())

func sqlize[T](items: seq[T]): string =
  '(' & join(items, ", ") & ')'

func tagIds(data: RelValuesByTagId): seq[Id] =
  data.keys.toseq.mapIt(Id parseInt it)

# ------------------------------------


func setRelValue(rel: var Relation, value_type: TagValueType, value: string) =
  case value_type
  of tvtNone: discard
  of tvtStr, tvtJson:
    rel.sval = some value
  of tvtFloat:
    rel.fval = some parseFloat value
  of tvtInt, tvtDate:
    rel.ival = some parseInt value

template updateRelTagsGeneric*(
  db: DbConn,
  field: untyped,
  fieldStr: string,
  entityId: Id,
  data: RelValuesByTagId
) =
  transaction db:
    # remove existing rels
    db.exec sql "DELETE FROM Relation WHERE " & fieldStr & " = ?", entityId
    # remove rel cache
    db.exec sql "DELETE FROM RelationsCache WHERE " & fieldStr & " = ?", entityId

    # insert new rel cache
    db.insert RelationsCache(
      field: some entityId,
      active_rels_values: data)

    # insert all rels again
    let tags = db.findTags tagIds data
    for key, values in data:
      let
        tagid = Id parseInt key
        t = tags[tagid]

      for v in values:
        var r = Relation(
          field: some entityId,
          tag: tagid,
          #TODO timestamp: now(),
        )

        setRelValue r, t.value_type, v
        db.insert r


proc getInvitation*(db: DbConn, secret: string, time: Unixtime,
    expiresAfterSec: Positive): options.Option[Invitation] =
  db.find R, sql"""
    SELECT *
    FROM Invitation i 
    WHERE 
      ? - i.timestamp <= ? AND
      secret = ?
    """, time, expiresAfterSec, secret


proc getAuthBale*(db: DbConn, baleUserId: Id): options.Option[Auth] =
  db.find R, sql"""
    SELECT *
    FROM Auth a
    WHERE bale = ?
    """, baleUserId

proc getAuthUser*(db: DbConn, user: Id): options.Option[Auth] =
  db.find R, sql"""
    SELECT *
    FROM Auth a
    WHERE user = ?
    """, user

proc newAuth*(db: DbConn, userId, baleUserId: Id): Id =
  db.insert Auth(
    user: userId,
    bale: some baleUserId)

proc newAuth*(db: DbConn, userId: Id, pass: SecureHash): Id =
  db.insert Auth(
    user: userId,
    hashed_pass: some pass)


proc getUser*(db: DbConn, userid: Id): options.Option[User] =
  db.find R, sql"""
    SELECT *
    FROM User u
    WHERE id = ?
    """, userid

proc getUser*(db: DbConn, username: string): options.Option[User] =
  db.find R, sql"""
    SELECT *
    FROM User u
    WHERE u.username = ?
    """, username

proc newUser*(db: DbConn, uname, nname: string): Id =
  db.insertID User(
    username: uname,
    nickname: nname,
    role: urUser)


# TODO add show_name tag
proc newTag*(db: DbConn, t: Tag): Id =
  db.insertID Tag(
    owner: 0,
    creator: tcUser,
    label: tlOrdinary,
    can_be_repeated: false,
    show_name: t.show_name,
    is_private: t.is_private,
    theme: t.theme,
    name: t.name,
    icon: t.icon,
    value_type: t.value_type)

proc updateTag*(db: DbConn, id: Id, t: Tag) =
  # TODO write a macro called sqlFmt to use {} with sql
  db.exec sql"""UPDATE Tag SET 
      name = ?, 
      value_type = ?, 
      show_name = ?, 
      icon = ?, 
      theme = ?,
      is_private = ?
    WHERE id = ?""",
    t.name,
    t.value_type,
    t.show_name,
    t.icon,
    t.theme,
    t.is_private,
    id

proc deleteTag*(db: DbConn, id: Id) =
  db.exec sql"DELETE FROM Tag WHERE id = ?", id

proc listTags*(db: DbConn): seq[Tag] =
  db.find R, sql"SELECT * FROM Tag"

proc findTags*(db: DbConn, ids: seq[Id]): Table[Id, Tag] =
  for t in db.find(seq[Tag], sql "SELECT * FROM Tag WHERE id IN " & sqlize ids):
    result[t.id] = t


proc addAsset*(db: DbConn, n: string, m: string, p: Path, s: Bytes): int64 =
  db.insertID Asset(
      name: n,
      path: p,
      mime: m,
      size: s)

proc findAsset*(db: DbConn, id: Id): Asset =
  db.find R, sql"SELECT * FROM Asset WHERE id=?", id

proc getAsset*(db: DbConn, id: Id): AssetItemView =
  db.find R, sql"""
    SELECT a.id, a.name, a.mime, a.size, rc.active_rels_values
    FROM Asset a
    JOIN RelationsCache rc
    ON rc.asset = a.id
    WHERE a.id = ?
  """, id

proc updateAssetName*(db: DbConn, id: Id, name: string) =
  db.exec sql"""
    UPDATE Asset
    SET name = ?
    WHERE id = ?
  """, name, id

proc updateAssetRelTags*(db: DbConn, id: Id, data: RelValuesByTagId) =
  updateRelTagsGeneric db, asset, "asset", id, data

proc deleteAsset*(db: DbConn, id: Id) =
  db.exec sql"DELETE FROM Asset WHERE id = ?", id


proc getNote*(db: DbConn, id: Id): NoteItemView =
  db.find R, sql"""
    SELECT n.id, n.data, rc.active_rels_values 
    FROM Note n
    JOIN RelationsCache rc
    ON rc.note = n.id
    WHERE n.id = ?
    """, id

proc newNote*(db: DbConn): Id =
  result = db.insertID initEmptyNote()
  db.insert RelationsCache(note: some result)

proc updateNoteContent*(db: DbConn, id: Id, data: TreeNodeRaw[JsonNode]) =
  db.exec sql"UPDATE Note SET data = ? WHERE id = ?", data, id

proc updateNoteRelTags*(db: DbConn, noteid: Id, data: RelValuesByTagId) =
  updateRelTagsGeneric db, note, "note", noteid, data

proc deleteNote*(db: DbConn, id: Id) =
  transaction db:
    db.exec sql"DELETE FROM Note WHERE id = ?", id
    db.exec sql"DELETE FROM RelationsCache WHERE note = ?", id
    db.exec sql"DELETE FROM Relation WHERE note = ?", id


proc newBoard*(db: DbConn): Id =
  result = db.insertID Board(
    title: "no title",
    data: BoardData())

  db.insert RelationsCache(
    board: some result,
    active_rels_values: RelValuesByTagId())

proc updateBoardContent*(db: DbConn, id: Id, data: BoardData) =
  db.exec sql"UPDATE Board SET data = ? WHERE id = ?", data, id

proc updateBoardTitle*(db: DbConn, id: Id, title: string) =
  db.exec sql"UPDATE Board SET title = ? WHERE id = ?", title, id

proc setBoardScreenShot*(db: DbConn, boardId, assetId: Id) =
  db.exec sql"UPDATE Board SET screenshot = ? WHERE id = ?", assetId, boardId

proc updateBoardRelTags*(db: DbConn, id: Id, data: RelValuesByTagId) =
  updateRelTagsGeneric db, board, "board", id, data

proc getBoard*(db: DbConn, id: Id): Board =
  db.find R, sql"SELECT * FROM Board WHERE id = ?", id

proc deleteBoard*(db: DbConn, id: Id) =
  db.exec sql"DELETE FROM Board WHERE id = ?", id



func toSubQuery(c: TagCriteria, entityIdVar: string): string =
  let
    introCond =
      case c.operator
      of qoNotExists: "NOT EXISTS"
      else: "EXISTS"

    candidateCond =
      case c.label
      of tlOrdinary:
        fmt"rel.tag = {c.tagId}"
      else:
        fmt"rel.label = {c.label.ord}"

    # FIXME security issue when oeprator is qoLike: "LIKE"
    # FIXME not covering "" in string
    primaryCond =
      if isInfix c.operator:
        fmt"rel.{columnName c.valueType} {c.operator} {c.value}"
      else:
        "1"

  fmt""" 
  {introCond} (
    SELECT *
    FROM Relation rel
    WHERE 
        rel.note = {entityIdVar} AND
        {candidateCond} AND
        {primaryCond}
  )
  """

func exploreSqlConds(xqdata: ExploreQuery, ident: string): string =
  if xqdata.criterias.len == 0: "1"
  else:
    xqdata.criterias
    .mapIt(toSubQuery(it, ident))
    .join " AND "

func exploreGenericQuery*(entity: EntityClass, xqdata: ExploreQuery): SqlQuery =
  let repl = exploreSqlConds(xqdata, "thing.id")

  case entity
  of ecNote: sql fmt"""
      SELECT thing.id, thing.data, rc.active_rels_values
      FROM Note thing
      JOIN RelationsCache rc
      ON rc.note = thing.id
      WHERE {repl}
      ORDER BY thing.id DESC
    """

  of ecBoard: sql fmt"""
      SELECT thing.id, thing.title, thing.screenshot, rc.active_rels_values
      FROM Board thing
      JOIN RelationsCache rc
      ON rc.board = thing.id
      WHERE {repl}
      ORDER BY thing.id DESC
    """

  of ecAsset: sql """
      SELECT thing.id, thing.name, thing.mime, thing.size, "{}"
      FROM Asset thing
      ORDER BY thing.id DESC
    """

proc exploreNotes*(db: DbConn, xqdata: ExploreQuery): seq[NoteItemView] =
  db.find R, exploreGenericQuery(ecNote, xqdata)

proc exploreBoards*(db: DbConn, xqdata: ExploreQuery): seq[BoardItemView] =
  db.find R, exploreGenericQuery(ecBoard, xqdata)

proc exploreAssets*(db: DbConn, xqdata: ExploreQuery): seq[AssetItemView] =
  db.find R, exploreGenericQuery(ecAsset, xqdata)

proc exploreUser*(db: DbConn, str: string): seq[User] =
  db.find R, sql"""
    SELECT *
    FROM User u
    WHERE 
      instr(u.username, ?) > 0 OR
      instr(u.nickname, ?) > 0
  """, str, str


proc getPalette*(db: DbConn, name: string): Palette =
  db.find R, sql"SELECT * FROM Palette WHERE name = ?", name


proc loginNotif*(db: DbConn, usr: Id) =
  db.insert Relation(
    user: some usr,
    kind: some ord nkLoginBale,
    timestamp: toUnixtime now())

proc getActiveNotifs*(db: DbConn): seq[Notification] =
  db.find R, sql"""
    SELECT r.id, u.id, u.nickname, r.kind, a.bale
    FROM Relation r
    
    JOIN User u
    ON r.user = u.id

    JOIN Auth a
    ON a.user = r.user
    
    WHERE r.state = ?
    ORDER BY r.id ASC
  """, rsFresh

proc markNotifsAsStale*(db: DbConn, ids: seq[Id]) =
  db.exec sql fmt"""
    UPDATE Relation
    SET state = ?
    WHERE id in {sqlize ids}
  """, rsStale
