WarnView = require('./warn-view')

module.exports =
class EpitechNormChecker
  enabled: true

  text: null
  fileType: null
  isInFunc: false
  isInDoc: false
  funcLines: 0
  funcNum: 0
  lineNum: 0

  markers: []
  warns: []

  warnView: null

  constructor: (@editor, @warnView) ->

  warn: (msg, row, col, length) ->
    marker = @editor.markBufferRange([[row, col], [row, col + length]], invalidate: 'inside')
    @editor.decorateMarker(marker, {type: 'highlight', class: 'norm-error'})
    @markers.push(marker)
    @warns.push(message: msg, row: row, col: col)

  replaceTabsBySpaces: (str) ->
    i = 0
    ret = ""
    for ch in str
      if ch == '\t'
        ret += " ".repeat(8 - i % 8)
        i += 8 - i % 8
      else
        ret += ch
        i += 1
    return ret

  toggle: ->
    if @enabled then @disable() else @enable()

  enable: ->
    @enabled = true
    @check()

  disable: ->
    @enabled = false
    if @warnView
      @warnView.clearWarns()
      @warnView.hide()
      for marker in @markers
        marker.destroy()
      @markers = []
      @warns = []

  displayWarnsForLine: (line) ->
    return unless @warnView and @enabled
    @warnView.clearWarns()
    @warnView.hide()
    disp = false
    for w in @warns
      if w.row == line
        @warnView.addWarn(w.message)
        disp = true
    @warnView.show() if disp

  check: ->
    return unless @enabled

    [..., fileName] = @editor.getPath().split "/"
    @fileType = "c" if fileName.match /^.*\.[c]$/
    @fileType = "h" if fileName.match /^.*\.[h]$/
    @fileType = "mk" if fileName.match /^[Mm]akefile$/

    for marker in @markers
      marker.destroy()
    @markers = []
    @warns = []

    @funcNum = 0
    @funcLines = 0
    @isInFunc = false
    @lineNum = 0
    @text = @editor.getText().split "\n"
    for line in @text
      @checkFuncScope line
      @checkLineLength line
      @checkEndlineSpaces line
      @checkSpacesParen line
      @checkKeyWordsSpaces line
      @checkEndLineSemicolon line
      @checkComment line
      @checkBracket line
      @checkSpaceAfterComma line
      @checkFuncArgs line
      @checkOperators line
      @lineNum += 1

  checkFuncScope: (line) ->
    if @fileType == "c"
      if line.match /^\}.*$/
        @isInFunc = false
        @funcLines = 0
      if line.match /^\{.*$/
        @isInFunc = true
        @funcLines = 0
        @funcNum += 1
        @warn("More than 5 functions in the file.", @lineNum - 1, 0, @text[@lineNum - 1].length) if @funcNum > 5
        @checkFuncVars()
      else if @isInFunc and @funcNum > 0
        @funcLines += 1
      @warn("Function of more than 25 lines.", @lineNum, 0, line.length) if @funcLines > 25

  checkFuncVars: ->
    return if @isInDoc

    i = @lineNum - 1
    while not @text[i].match /^[^\s]/
      i -= 1
    funLine = @replaceTabsBySpaces @text[i]
    tabSize = funLine.match /^(.*?)[^\s]+\(.*$/
    return unless tabSize and tabSize[1]
    tabSize = tabSize[1].length
    i = @lineNum + 1
    while !(i >= @text.length or @text[i].match /^\s*$/)
      if @text[i].match /^}.*$/
        return
      i += 1
    if i >= @text.length
      return
    i = @lineNum + 1
    while !(@text[i].match /^\s*$/)
      varLine = @replaceTabsBySpaces @text[i]
      varSize = varLine.match /^(.*?)[^\s]+$/
      if varSize
        varSize = varSize[1].length
        @warn("Function and var name aren't aligned.", i, 0, @text[i].length) if varSize != tabSize
      i += 1

  checkLineLength: (line) ->
    tmp = @replaceTabsBySpaces line
    if tmp.length > 80
      @warn("Line of more than 80 characters.", @lineNum, 0, line.length)

  checkEndlineSpaces: (line) ->
    tmp = line.match /\s+$/
    if tmp
      @warn("Space at the end of the line.", @lineNum, tmp.index, line.length - tmp.index)

  checkEndLineSemicolon: (line) ->
    return if @isInDoc
    tmp = line.match /\s+$;/
    if tmp
      @warn("Space before semicolon at end of line", @lineNum, tmp.index, line.length - tmp.index)

  checkSpacesParen: (line) ->
    return if @isInDoc
    if @fileType == "c" or @fileType == "h"
      i = 0
      quote = false
      while i < line.length and line.charAt i != '\n'
        ch = line.charAt i
        prev = line.charAt i - 1
        next = line.charAt i + 1
        if (ch == '\'' or ch == '"') and (i > 0 and prev != '\\' or i == 0)
          quote = not quote
        if not quote
          if ch == '('
            @warn("Space after open paren.", @lineNum, i, 2) if next == ' ' or next == '\t'
          if ch == ')'
            @warn("Space before close paren.", @lineNum, i - 1, 2) if prev == ' ' or prev == '\t'
        i += 1

  checkKeyWordsSpaces: (line) ->
    return if @isInDoc
    tmp = line.match /(if|else|return|while|for)\(/
    @warn("Missing space after a keyword.", @lineNum, tmp.index, tmp[0].length) if tmp

  checkComment: (line) ->
    tmp = line.match /(\/\/.*)/
    if tmp
      @warn("C++ style comment!", @lineNum, tmp.index, line.length - tmp.index)
      return
    tmp = line.match /(\/\*(?:(?!\*\/).)*(?:\*\/)?)/
    if @isInFunc and tmp
      @warn("Comment in function.", @lineNum, tmp.index, tmp[0].length)
      return
    tmp = line.match /(^\/\*.*)/
    if not @isInFunc and tmp
      @isInDoc = true
      return
    else
      tmp = line.match /(\/\*.*)/
      if tmp
        @warn("Malformed doc.", @lineNum, 0, tmp.index)
        @isInDoc = true
        return
    tmp = line.match /^(\*\/$)/
    if @isInDoc and tmp
      @isInDoc = false
      return
    else
      tmp = line.match /(\*\/)/
      if @isInDoc and tmp
        @isInDoc = false
        @warn("Malformed doc.", @lineNum, 0, line.length)
    tmp = line.match /^\*\*/
    if @isInDoc and not tmp
      @warn("Malformed doc.", @lineNum, 0, line.length)

  checkBracket: (line) ->
    return if @isInDoc
    tmp = line.match /((?:[^\s]+[\s]*[\{\}])|(?:[\{\}][\s]*[^\s]+))/
    if tmp
      @warn("Bracket not alone on the line.", @lineNum, tmp.index, tmp[0].length)

  checkSpaceAfterComma: (line) ->
    return if @isInDoc
    n = 0
    quote = false
    while n < line.length and line.charAt(n) != '\n'
      quote = not quote if line.charAt(n) == '\'' or line.charAt(n) == '"'
      if line.charAt(n) == ',' and not quote
        if line.charAt(n + 1) and line.charAt(n + 1) != ' '
          @warn("Missing space after comma.", @lineNum, n, 1)
        if line.charAt(n - 1) and line.charAt(n - 1) == ' '
          @warn("It shouldn't have a space before a comma.", @lineNum, n - 1, 2)
      n += 1

  checkFuncArgs: (line) ->
    return if @isInDoc or @isInFunc

    tmpLine = @replaceTabsBySpaces line
    tmp = tmpLine.match /^(.*?[^\s]+\()(.*$)/
    if tmp
      spacesBeforeArgs = tmp[1].length
      nbArgs = if tmpLine.match /\([\s]*\)/ then 0 else 1
      i = @lineNum
      while i < @text.length
        tmp = @text[i].split(',')
        nbArgs += tmp.length - 1
        if nbArgs > 4
          @warn("More than 4 args in the function.", i, 0, @text[i].length)
        tmpLine = @replaceTabsBySpaces @text[i]
        tmp = tmpLine.match /^[\s]*/
        if i > @lineNum
          if tmp
            if tmp[0].length != spacesBeforeArgs
              @warn("Wrong indentation.", i, 0, tmp[0].length // 8 + tmp[0].length % 8)
          else if spacesBeforeArgs > 0
            @warn("Missing indentation.", i, 0, @text[i].length)
        if @text[i].match /.*\)$/
          return
        i += 1

  checkOperators: (line) ->
    return if @isInDoc

    tmpLine = line + '\n'
    tmp = line.match /[\s]*(?:(?:[\+\-\*\/%]*[\w]+[ ]*)|([\s]+))[\+\-\*\/%][ ]*(?:(?:[\+\-\*\/%]*[\w]+)|(?:\n))/
    if tmp and not line.match /(:?[\s]*(?:(?:[+\-*/%]*[\w]+ )|(?:^[\s]+))(?:[+\-*/%](?: [+\-*/%]*[\w]+)|(?:\n)))|(:?^[\s]+[+\-*/%]*[\w]+[^\w+\-*/%]*$)/
      @warn("Not right spaces number between operator and operande.", @lineNum, tmp.index, tmp[0].length)
