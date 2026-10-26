import Foundation
import TodoCore

let help = """
Next One local interface · JSON on stdout, errors on stderr, nonzero exit on failure
Usage: next-one <command> [id] [--field value] [--json]
  archive preview
  archive completed --expected-token TOKEN [--request-key KEY]
  board list
  board place --key p:ID|t:ID --expected-revision N --expected-board-revision N --anchor p:ID|t:ID --placement before|after|end
  project create --name NAME
  project list
  project bind --path DIR [--name NAME] [--project ID --expected-revision N]
  project unbind ID --path DIR --expected-revision N
  project update ID --expected-revision N [--name NAME] [--path DIR --replace-path OLD]
  context --cwd DIR [--limit 100 --offset 0]
  list [--project ID|all|unclassified] [--status todo|in_progress|done] [--limit N --offset N]
  get ID
  add --title TITLE (--project ID|unclassified | --parent ID) [--request-key KEY] [--source user|codex]
  update ID --expected-revision N [fields]
  complete ID --expected-revision N [--cascade]
  move ID --expected-revision N [--project ID|unclassified] [--parent ID|root]
  place ID --expected-revision N --anchor ID --anchor-revision N --placement before|after
  place ID --expected-revision N --project ID|unclassified --parent ID|root --placement end
  group ID --expected-revision N --target ID --target-revision N (--name NAME | --project EMPTY_ID)
  delete ID --expected-revision N
  trash
  restore ID --expected-revision N
  attachment add ID --path FILE --expected-revision N [--request-key KEY]
  attachment delete|restore ID --attachment ATTACHMENT_ID --expected-revision N
Fields: --title, --description, --description-file FILE (or - for stdin), --status,
        --priority high|medium|low, --color none|red|orange|green|blue|purple,
        --due-date yyyy-MM-dd, --due-at ISO8601 (timezone required); empty value clears.
Task lookup: get accepts UUID or global short code (A1, AA1), case-insensitive. Writes use the returned UUID, including parent/target/anchors; codes can be reused.
Data: NEXT_ONE_HOME overrides Application Support/\(Store.defaultDirectoryName). No network server.
Resolved data directory: \(Store.defaultDirectory.path)
"""
do {
    var tokens = Array(CommandLine.arguments.dropFirst())
    if tokens.isEmpty || tokens.contains("--help") || tokens == ["help"] { print(help); exit(0) }
    var command = tokens.removeFirst()
    if ["project", "attachment", "board", "archive"].contains(command), !tokens.isEmpty { command += " " + tokens.removeFirst() }
    var args: [String: String] = [:]
    while !tokens.isEmpty {
        let token = tokens.removeFirst()
        if token == "--json" { continue }
        if token == "--cascade" { args["cascade"] = "true"; continue }
        if token.hasPrefix("--") {
            let key = String(token.dropFirst(2))
            guard !tokens.isEmpty, args[key] == nil else { throw TodoError("invalid_field", "缺少参数值或参数重复：\(token)") }
            args[key] = tokens.removeFirst()
        } else {
            guard args["id"] == nil else { throw TodoError("invalid_field", "多余参数：\(token)") }
            args["id"] = token
        }
    }
    if let path = args.removeValue(forKey: "description-file") {
        guard args["description"] == nil else { throw TodoError("invalid_field", "description 与 description-file 不能同时提供。") }
        let data = try path == "-" ? FileHandle.standardInput.readToEnd() ?? Data() : Data(contentsOf: URL(fileURLWithPath: path))
        guard let value = String(data: data, encoding: .utf8) else { throw TodoError("invalid_field", "描述文件必须为 UTF-8。") }
        args["description"] = value
    }
    let result = try Store().execute(command, args)
    let data = try JSONSerialization.data(withJSONObject: ["ok": true, "data": result], options: [.prettyPrinted, .sortedKeys, .fragmentsAllowed])
    print(String(decoding: data, as: UTF8.self))
} catch {
    let error = error as? TodoError ?? TodoError("storage_unavailable", verbatim: error.localizedDescription)
    let data = try! JSONSerialization.data(withJSONObject: ["ok": false, "error": ["code": error.code, "message": error.message]], options: [.sortedKeys])
    FileHandle.standardError.write(data + Data("\n".utf8)); exit(1)
}
