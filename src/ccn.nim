import os,osproc,terminal,sequtils,strformat,strutils

import kdl

var doc: KdlDoc
const default = staticRead("./default.kdl")

type
  Config = object
    types: KdlNode
    breaking: bool

# TODO: support global config in $XDG_CONFIG_HOME/ccn/ccn.kdl
const configFile = ".ccn.kdl"
proc loadConfigFile(): KdlDoc =
  if fileExists(configFile):
    doc = parseKdlFile(configFile)
    return doc
  else:
    echo "using default config"
    doc = parseKdl(default)
    return doc

proc warn(msg: string) =
  styledEcho styleBright, fgYellow, "[Warn]", resetStyle, ": " & msg

proc error(msg: string, code: int = 0) =
  styledEcho styleBright, fgRed, "[Error]", resetStyle, ": " & msg
  if code != 0:
    quit(code)

proc parseConfigFile(doc: KdlDoc): Config =
  var config = Config()
  for node in doc:
    case node.name:
      of "types":
        config.types = node
      of "allow-breaking":
        config.breaking = node[0].getBool()
      else:
        warn "Ignoring unknown property -> " & $node

  return config

proc getChoice(options: seq[KdlNode]): KdlNode =
  var maxTypeLen = options.mapIt(len(it.name)).max()
  for i, opt in options:
    if len(opt.args) > 1:
      error &"unexpected attributes for type {opt.name} -> {opt.args}", 1
    echo &"{i}: {alignLeft(opt.name,maxTypeLen)} -> {opt.args[0]}"

  # this is a clunky solution probably
  var selection: int = len(options) + 1
  while not (0..len(options)).contains(selection):
    write(stdout, "choice: ")
    # TODO: elegantly reset while if letter?
    selection = parseInt(readLine(stdin))
  return options[selection]

proc getScope(commitType: KdlNode): string =
  echo "Is this a specific scope?"
  stdout.styledWrite(styleBright,fgCyan, commitType.name, resetStyle,"(<scope>): ")
  result = stdin.readLine()

proc getCommitMessage(commitType: KdlNode): string =
  var scope = getScope(commitType)
  echo "What is your commit message?"
  if scope != "": scope = &"({scope})"
  stdout.styledWrite(styleBright, fgCyan, commitType.name, resetStyle, styleDim, scope, resetStyle,": ")
  var message = readLine(stdin)
  if message == "":
    error("Blanks commit messages are useless...shame!", 1)
  result = commitType.name & scope & ": " & message

proc main() =
  doc = loadConfigFile()
  var config = parseConfigFile(doc)
  var commitType = getChoice(config.types.children)
  echo &"You chose {commitType}!"
  var commitMessage = getCommitMessage(commitType)
  var code = execCmd(&"git commit -m \'{commitMessage}\' -e")
  if code != 0:
    error "Issue running git", code


when isMainModule:
  main()
