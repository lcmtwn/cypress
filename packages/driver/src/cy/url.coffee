_ = require("lodash")

$Log = require("../cypress/log")

module.exports = ($Cy) ->
  $Cy.extend
    urlChanged: (url, options = {}) ->
      ## allow the url to be explictly passed here
      url ?= @_getLocation("href")

      ## about:blank returns "" and we dont
      ## want to trigger the url:changed
      return if _.isEmpty(url)

      urls = @state("urls") ? []

      previousUrl = _.last(urls)

      urls.push(url)

      @state("urls", urls)

      @state("url", url)

      _.defaults options,
        log: true
        by: null
        args: null

      ## ensure our new url doesnt match whatever
      ## the previous was. this prevents logging
      ## additionally when the url didnt actually change
      if options.log and (url isnt previousUrl)
        Cypress.log
          name: "new url"
          message: url
          event: true
          type: "parent"
          end: true
          snapshot: true
          consoleProps: ->
            obj = {
              Event: "url updated"
              "New Url": url
            }

            if options.by
              obj["Url Updated By"] = options.by

            obj.args = options.args

            return obj

      @Cypress.trigger "url:changed", url

    pageLoading: (bool = true) ->
      @Cypress.trigger "page:loading", bool
