_ = require("lodash")

$Log = require("../../cypress/log")
$utils = require("../../cypress/utils")

traversals = "find filter not children eq closest first last next nextAll nextUntil parent parents parentsUntil prev prevAll prevUntil siblings".split(" ")

module.exports = (Commands, Cypress, cy) ->
  _.each traversals, (traversal) ->
    Commands.add traversal, {prevSubject: "dom"}, (subject, arg1, arg2, options) ->
      if _.isObject(arg2)
        options = arg2

      if _.isObject(arg1)
        options = arg1

      options ?= {}

      _.defaults options, {log: true}

      @ensureNoCommandOptions(options)

      getSelector = ->
        args = _.chain([arg1, arg2]).reject(_.isFunction).reject(_.isObject).value()
        args = _.without(args, null, undefined)
        args.join(", ")

      consoleProps = {
        Selector: getSelector()
        "Applied To": $utils.getDomElements(subject)
      }

      if options.log isnt false
        options._log = Cypress.log
          message: getSelector()
          consoleProps: -> consoleProps

      setEl = ($el) ->
        return if options.log is false

        consoleProps.Yielded = $utils.getDomElements($el)
        consoleProps.Elements = $el?.length

        options._log.set({$el: $el})

      do getElements = =>
        ## catch sizzle errors here
        try
          $el = subject[traversal].call(subject, arg1, arg2)

          ## normalize the selector since jQuery won't have it
          ## or completely borks it
          $el.selector = getSelector()
        catch e
          e.onFail = -> options._log.error(e)
          throw e

        setEl($el)

        @verifyUpcomingAssertions($el, options, {
          onRetry: getElements
          onFail: (err) ->
            if err.type is "existence"
              node = $utils.stringifyElement(subject, "short")
              err.displayMessage += " Queried from element: #{node}"
        })
