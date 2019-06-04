import
  os,
  rdstdin,
  tables,
  strutils,
  sequtils,
  re,
  nasty,
  sugar

var cmdMap = initTable[string, seq[string] -> int]()

var varMap = initTable[string, string]()

proc defaultCmd(args: seq[string]): int =
  echo "Unknown command: " & args[0]
  1

let whitespaceChars = " \n\r\t\b\f"
let whitespaceChar = charIn(whitespaceChars)
let statementEnd: Matcher[char] = charIn(",|&")

let specialChars = whitespaceChar | statementEnd | '"'

let token: Matcher[string] = anyChar.untilMatch(specialChars).asString
let variableExpansion: Matcher[string] = S("$") ?: token.map(name => varMap[name])
let quotedString: Matcher[string] = S("\"") ?: anyChar.untilMatch('"').asString :? S("\"")

let stringMatch: Matcher[string] = quotedString | variableExpansion | token
let whiteSpaceSeparatedStrings: Matcher[seq[string]] = (whitespaceChar.anyCount ++ stringMatch).map(t => t[1]).untilMatch(statementEnd)
let empty: Matcher[() -> int] = whitespaceChar.anyCount ?: ending.map(proc(_: Empty): proc(): int = return () => 0)
let statement: Matcher[() -> int] = empty | whiteSpaceSeparatedStrings.map(ss => (() => cmdMap.getOrDefault(ss[0], defaultCmd)(ss)))

let commaSeparatedStatements: Matcher[seq[() -> int]] = statement :& (',' ++ statement).map(t => t[1]).anyCount
let commandLineMatch: Matcher[() -> int] = commaSeparatedStatements.map(proc(statements: seq[() -> int]): () -> int = (proc(): int =
                                            for statement in statements:
                                              let rc = statement()
                                              if rc != 0: return rc
                                            return 0
                                           ))


proc eval(input: string): int =
  let match = input.match(commandLineMatch)
  if match.success:
    return match.matchData()
  else:
    echo match.reason
    return 111

const builtins = {
  ".return": proc(a: seq[string]): int =
    if len(a) == 1: return 0
    return parseint(a[1]), 
  ".echo": proc(a: seq[string]): int =
    echo(join(a[1..^1], " ")),
  ".alias": proc(a: seq[string]): int =
    if len(a) < 3: return 123
    cmdMap[a[1]] = proc(b: seq[string]): int =
      if len(b) == 1: eval(a[2..^1].join(" "))
      else: eval((a[2..^1] & b[1..^1]).join(" ")),
  ".set": proc(a: seq[string]): int =
    if len(a) < 2: return 123
    varMap[a[1]] = a[2..^1].join(" ")
    debugEcho varMap
}.toTable

for key, val in builtins.pairs:
  cmdMap[key] = val

var returnCode = 0

while true:
  let input = readLineFromStdin($returnCode & ">")
  try:
    returnCode = eval(input)
  except:
    let e = getCurrentExceptionMsg()
    echo($e)
