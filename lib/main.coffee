{CompositeDisposable, Disposable} = require 'atom'
EpitechNormChecker = require('./epitech-norm-checker')
WarnView = require('./warn-view')

module.exports =
  config:
    autoCheckNorm:
      type: 'boolean'
      default: false

  normCheckerByEditor: null
  warnView: null

  activate: ->
    @normCheckerByEditor = new WeakMap
    @warnView = new WarnView()

    atom.workspace.observeTextEditors (editor) =>
      return unless editor

      normChecker = new EpitechNormChecker(editor, @warnView)
      @normCheckerByEditor.set(editor, normChecker)

      editor.onDidStopChanging =>
        return unless activeEditor()
        [..., fileName] = activeEditor().getPath().split "/"
        if atom.config.get('epitech-norm-checker.autoCheckNorm') and fileName.match /^.*\.[ch]$/
          getNorm(activeEditor())?.check()

      editor.onDidChangeCursorPosition =>
        return unless activeEditor()
        [..., fileName] = activeEditor().getPath().split "/"
        if atom.config.get('epitech-norm-checker.autoCheckNorm') and fileName.match /^.*\.[ch]$/
          [line, _] = activeEditor().getCursorBufferPosition().toArray()
          getNorm(activeEditor())?.displayWarnsForLine line

    getNorm = (e) =>
      return null unless e and @normCheckerByEditor
      return @normCheckerByEditor.get(e)

    activeEditor = () =>
      atom.workspace.getActiveTextEditor()

    atom.commands.add 'atom-workspace',
      'epitech-norm-checker:enable': =>
        getNorm(activeEditor())?.enable()
      'epitech-norm-checker:disable': =>
        getNorm(activeEditor())?.disable()
      'epitech-norm-checker:checkNorm': =>
        getNorm(activeEditor())?.check()
