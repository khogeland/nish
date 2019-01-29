import
  os,
  tables,
  strutils,
  re,
  sugar

var cmdMap = initTable[string, seq[string] -> int]()

proc defaultCmd(args: seq[string]): int = 1

proc eval(input: seq[string]): int =
  echo(input)
  if len(input) == 0: return 111
  return cmdMap.getOrDefault(input[0], defaultCmd)(input)

const builtins = {
  ".echo": proc(a: seq[string]): int =
    echo(join(a[1..^1], " ")),
  ".set": proc(a: seq[string]): int =
    if len(a) < 3: return 123
    cmdMap[a[1]] = proc(b: seq[string]): int =
      if len(b) == 1: eval(a[2..^1])
      else: eval(a[2..^1] & b[1..^1])
}.toTable

for key, val in builtins.pairs:
  cmdMap[key] = val

var returnCode = 0

while true:
  write(stdout, $returnCode & ">")
  let input = readLine(stdin)
  let cmd: seq[string] = re.split(string(input), re"\s+")
  returnCode = eval(cmd)
