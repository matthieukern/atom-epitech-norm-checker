{CompositeDisposable, Disposable} = require 'atom'
EpitechNormChecker = require('./epitech-norm-checker')

module.exports =
  config:
    autoCheckNorm:
      type: 'boolean'
      default: false

  normCheckerByEditor: null

  activate: ->
    @normCheckerByEditor = new WeakMap

    atom.workspace.observeTextEditors (editor) =>
      return unless editor

      normChecker = new EpitechNormChecker(editor)
      @normCheckerByEditor.set(editor, normChecker)

      editor.onDidStopChanging =>
        [..., fileName] = activeEditor().getPath().split "/"
        if atom.config.get('epitech-norm-checker.autoCheckNorm') and fileName.match /^.*\.[ch]$/
          getNorm(activeEditor())?.check()

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
