_ = require("lodash")
$ = require("jquery")
Promise = require("bluebird")

$Log = require("../../../cypress/log")
$utils = require("../../../cypress/utils")

module.exports = (Commands, Cypress, cy) ->
  Commands.addAll({ prevSubject: "dom" }, {
    select: (subject, valueOrText, options = {}) ->
      _.defaults options,
        $el: subject
        log: true
        force: false

      @ensureDom(options.$el)

      consoleProps = {}

      if options.log
        ## figure out the options which actually change the behavior of clicks
        deltaOptions = $utils.filterOutOptions(options)

        options._log = Cypress.log
          message: deltaOptions
          $el: options.$el
          consoleProps: ->
            ## merge into consoleProps without mutating it
            _.extend {}, consoleProps,
              "Applied To": $utils.getDomElements(options.$el)
              "Options":    deltaOptions

        options._log.snapshot("before", {next: "after"})

      ## if subject is a <select> el assume we are filtering down its
      ## options to a specific option first by value and then by text
      ## we'll throw if more than one is found AND the select
      ## element is multiple=multiple

      ## if the subject isn't a <select> then we'll check to make sure
      ## this is an option
      ## if this is multiple=multiple then we'll accept an array of values
      ## or texts and clear the previous selections which matches jQuery's
      ## behavior

      if not options.$el.is("select")
        node = $utils.stringifyElement(options.$el)
        $utils.throwErrByPath "select.invalid_element", { args: { node } }

      if (num = options.$el.length) and num > 1
        $utils.throwErrByPath "select.multiple_elements", { args: { num } }

      ## normalize valueOrText if its not an array
      valueOrText = [].concat(valueOrText)
      multiple    = options.$el.prop("multiple")

      ## throw if we're not a multiple select and we've
      ## passed an array of values
      if not multiple and valueOrText.length > 1
        $utils.throwErrByPath "select.invalid_multiple"

      getOptions = =>
        newLineRe = /\n/g

        ## throw if <select> is disabled
        if options.$el.prop("disabled")
          node = $utils.stringifyElement(options.$el)
          $utils.throwErrByPath "select.disabled", { args: { node } }

        values = []
        optionEls = []
        optionsObjects = options.$el.find("option").map((index, el) ->
          ## push the value in values array if its
          ## found within the valueOrText
          value = el.value
          optEl = $(el)

          if value in valueOrText
            optionEls.push optEl
            values.push(value)


          ## replace new line chars, then trim spaces
          trimmedText = optEl.text().replace(newLineRe, "").trim()

          ## return the elements text + value
          {
            value: value
            text: trimmedText
            $el: optEl
          }
        ).get()

        ## if we couldn't find anything by value then attempt
        ## to find it by text and insert its value into values arr
        if not values.length
          ## if all the values are the same and the user is trying to
          ## select based on the text, setting the value won't work
          ## `allSameValue` is used later to do the right thing
          uniqueValues = _.chain(optionsObjects).map("value").uniq().value()
          allSameValue = uniqueValues.length is 1

          _.each optionsObjects, (obj, index) ->
            if obj.text in valueOrText
              optionEls.push obj.$el
              values.push(obj.value)

        ## if we didnt set multiple to true and
        ## we have more than 1 option to set then blow up
        if not multiple and values.length > 1
          $utils.throwErrByPath("select.multiple_matches", {
            args: { value: valueOrText.join(", ") }
          })

        if not values.length
          $utils.throwErrByPath("select.no_matches", {
            args: { value: valueOrText.join(", ") }
          })

        _.each optionEls, ($el) =>
          if $el.prop("disabled")
            node = $utils.stringifyElement($el)
            $utils.throwErrByPath("select.option_disabled", {
              args: { node }
            })

        {values: values, optionEls: optionEls, allSameValue: allSameValue}

      retryOptions = =>
        Promise
        .try(getOptions)
        .catch (err) =>
          options.error = err
          @_retry(retryOptions, options)

      Promise
      .try(retryOptions)
      .then (obj = {}) =>
        {values, optionEls, allSameValue} = obj

        ## preserve the selected values
        consoleProps.Selected = values

        @execute("click", {
          $el: options.$el
          log: false
          verify: false
          errorOnSelect: false ## prevent click errors since we want the select to be clicked
          _log: options._log
          force: options.force
          timeout: options.timeout
          interval: options.interval
        }).then( =>

          ## TODO:
          ## 1. test cancellation
          ## 2. test passing optionEls to each directly
          ## 3. update other tests using this Promise.each pattern
          ## 4. test that force is always true
          ## 5. test that command is not provided (undefined / null)
          ## 6. test that option actually receives click event
          ## 7. test that select still has focus (i think it already does have a test)
          ## 8. test that multiple=true selects receive option event for each selected option
          Promise
            .resolve(optionEls) ## why cant we just pass these directly to .each?
            .each (optEl) =>
              @execute("click", {
                $el: optEl
                log: false
                verify: false
                force: true ## always force the click to happen on the <option>
                timeout: options.timeout
                interval: options.interval
              })
            .cancellable()
            .then =>
              if allSameValue
                ## if all the values are the same and the user is trying to
                ## select based on the text, setting the val() will just
                ## select the first one
                _.each optionEls, ($el) ->
                  $el.prop("selected", "selected")
              else
                ## reset the selects value after we've
                ## fired all the proper click events
                ## for the options
                ## TODO: shouldn't we be updating the values
                ## as we click the <option> instead of
                ## all afterwards?
                options.$el.val(values)

              input = new Event "input", {
                bubbles: true
                cancelable: false
              }

              options.$el.get(0).dispatchEvent(input)

              ## yup manually create this change event
              ## 1.6.5. HTML event types
              ## scroll down to 'change'
              change = document.createEvent("HTMLEvents")
              change.initEvent("change", true, false)

              options.$el.get(0).dispatchEvent(change)
        ).then =>
          do verifyAssertions = =>
            @verifyUpcomingAssertions(options.$el, options, {
              onRetry: verifyAssertions
        })
  })
