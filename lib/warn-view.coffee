{View} = require 'space-pen'

module.exports =
class WarnView extends View
  @content: ->
    @div class: 'padded epitech-norm-checker-warnview', =>
      @ul outlet: 'warnView', =>

  initialize: ->
    atom.workspace.addBottomPanel item:this
    @hide()

  clearWarns: ->
    @warnView.empty()

  addWarn: (message) ->
    @warnView.append "<li>#{message}</li>"
