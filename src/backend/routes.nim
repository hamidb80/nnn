import std/[strformat]
import ./utils/web
import ../common/types

when not (defined(js) or defined(frontend)):
  import mummy/routers
  var router*: Router

dispatch router, ../views:
  config "[not found]", notFoundHandler {.depends.}
  config "[method not allowed]", notFoundHandler {.depends.}
  config "[error]", errorHandler {.depends.}

  get "/", indexPage {.html.}
  get "/dist/"?(file: string), staticFileHandler {.file.}

  # get "/users/", assetsPage {.html.}
  # get "/api/user/search/"?(name: string), assetsPage {.html.}
  # get "/user/id/"?(id: int), assetsPage {.html.}
  # get "/me/", assetsPage {.html.}
  # get "/api/me/", assetsPage {.json.}
  # post "/api/me/update/", assetsPage {.json.}
  # get "/api/gen-invite-code/"?(user_id: int), assetsPage {.string.}

  get "/assets/", assetsPage {.html.}
  # get "/asset/"?(id: int), assetPreview {.html.}
  post "/assets/upload/", assetsUpload {.form: File, Id.}
  get "/assets/download/"?(id: Id), assetsDownload {.file.}
  get "/a", assetShorthand {.redirect.}
  get "/api/assets/list/", listAssets {.json.}
  delete "/api/asset/"?(id: Id), deleteAsset {.json.}
  
  get "/notes/", notesListPage {.html.}
  get "/note/editor/"?(id: Id), editorPage {.html.}
  get "/api/notes/list/", notesList {.json: seq[NotePreview].}
  get "/api/note/"?(id: Id), getNote {.json: NoteFull.}
  post "/api/notes/new/", newNote {.Id.}
  put "/api/notes/update/"?(id: Id), updateNote {.form: JsonNode, ok.}
  delete "/api/note/"?(id: Id), deleteNote {.ok.}

  get "/boards/", boardPage {.html.}
  # get "/board/"?(id: Id), boardPage {.html.}
  # post "/api/board/new/", newBoard {.Id.}
  # put "/api/board/update/"?(id: Id), updateBoard {.ok.}
  # get "/api/boards/list/", listBoards {.json: seq[].}
  # get "/api/board/"?(id: Id), getBoard {.json.}
  # delete "/api/board/"?(id: Id), deleteBoard {.ok.}

  get "/tags/", tagsPage {.html.}
  # post "/api/tag/new/", newTag {.Id.}
  # put "/api/tag/update/"?(id: Id), updateTag {.ok.}
  # get "/api/tags/list/", listTags {.json: seq[].}
  # delete "/api/tag/"?(id: Id), deleteTag {.ok.}
  

func get_asset_short_hand_url*(asset_id: Id): string =
  "/a?" & $asset_id
