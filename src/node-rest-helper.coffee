RateLimiter = require 'request-rate-limiter'

# https://developers.facebook.com/docs/graph-api/advanced/rate-limiting

# Workplace Graph API allowable limits do not work like this, they scale with number of users
# However, this should provide a healthy safety net in case the app goes crazy with requests
# and it would take a few minutes of running to burn through even a small instances API limits
DEFAULT_LIMITS =
  rate: 20               # requests per interval,
  interval:  10          # interval for the rate, x
  backoffCode: 429       # back off when this status is returned
  backoffTime: 10        # back off for n seconds,
  maxWaitingTime: 120    # return errors for requests that will have to wait for n seconds or more.


RequestBuilder = class RequestBuilder

  constructor: (context, opts) ->
    @debug = context.debug
    @opts = opts
    @opts.url ?= "#{context.url}/#{@opts.endpoint}"
    @opts.method ?= 'GET'
    @opts.headers ?= {}
    @opts.qs ?= {}
    @auth = null
    @description = null
    @results = []
    @nextCursor = null
    @firstPage()

# -----------------------------------------------------------------------------------
# Set rich description for debug output
# -----------------------------------------------------------------------------------
  describe: (text) ->
#todo: Blank in PROD
    @description = text
    @

# -----------------------------------------------------------------------------------
# Set Bearer {token} authorization header directly
# Consider using authorizeBy() functions instead which inherit token from context
# -----------------------------------------------------------------------------------
  setAuthorization: (token) ->
    token = token.substr(7) if token.startsWith 'Bearer '

    @

  addHeader: (header, value ) ->
    @opts.headers[header] = value
    @


# -----------------------------------------------------------------------------------
# Set request to authorize by token (will be auto injected from context)
# -----------------------------------------------------------------------------------
  authorizeByToken: ->
    @auth = 'token'
    @

# -----------------------------------------------------------------------------------
# Set request to authorize by app id | app secret (will be auto injected from context)
# -----------------------------------------------------------------------------------
  authorizeByAppSecret: ->
    @auth = 'appsecret'
    @


  authorizeByDefault: ->
    @auth = 'default'
    @


  authorizeBy: (type) ->
    @auth = type
    @


# -----------------------------------------------------------------------------------
# Set request to authorize via an impersonation token passed as  {token}
# See user.getImpersonationToken for details
# -----------------------------------------------------------------------------------
  impersonate: (token) ->
    delete @auth
    @setAuthorization token
    @


# -----------------------------------------------------------------------------------
# Shortcut to set an array {fields} as querystring.fields
# Hint: Many modules export an .ALL_FIELDS property (e.g. user.ALL_FIELDS)
# -----------------------------------------------------------------------------------
  setFields: (fields) ->
    @opts.qs['fields'] = fields.join ',' if fields? and Array.isArray(fields) and fields.length > 0
    @

# -----------------------------------------------------------------------------------
# Shortcut to send the requests json payload
# -----------------------------------------------------------------------------------
  setJson: (json) ->
    @opts.json = json
    @

# -----------------------------------------------------------------------------------
# Shortcut to add {key} with {value} to the requests json payload
# -----------------------------------------------------------------------------------
  addJson: (key, value) ->
    return @ if not value?
    @opts.json ?= {}
    @opts.json[key] = value
    @

# -----------------------------------------------------------------------------------
# Shortcut to set request body
# -----------------------------------------------------------------------------------
  setBody: (body) ->
    @opts.body = body
    @

# -----------------------------------------------------------------------------------
# Shortcut to set the request method (GET, POST, DELETE, PUT)
# -----------------------------------------------------------------------------------
  setMethod: (method) ->
    throw new Error("#{method} is not a valid request method") if ['GET', 'POST', 'DELETE', 'PUT'].indexOf(method) == -1
    @opts.method = method
    @

# -----------------------------------------------------------------------------------
# Shortcut to add/merge {qs} to the requests querystring object
# e.g. #{ x: 'y', z : 'a'} becomes ?x=y&z=a
# -----------------------------------------------------------------------------------
  addQueryStringParams: (qs) ->
    @opts.qs = Object.assign @opts.qs, qs
    @

# -----------------------------------------------------------------------------------
# Shortcut to set the requests query string parameters to {qs}
# -----------------------------------------------------------------------------------
  setQueryStringParams: (qs) ->
    @opts.qs = qs
    @


# -----------------------------------------------------------------------------------
# Instructs the request to recursively follow any pagination/next cursors returned
# until {limit} results are reached (default = Infinity). Results are added to an
# results array on the {aggregationNode property}, usually 'data'
#
# WARNING: This uses a recursive implementation which will blow the stack if a large
# number of pages is returned
# -----------------------------------------------------------------------------------
  allPages: (limit = Infinity, aggregationNode = 'data') ->
    @followNextCursor = true
    @resultsLimit = limit
    @aggregationNode = aggregationNode
    @


# -----------------------------------------------------------------------------------
# Instructions the request to not follow pagination and only return the first page
# of results. This is the default.
# -----------------------------------------------------------------------------------
  firstPage: () ->
    @followNextCursor = false
    @aggregationNode = null
    @resultsLimit = Infinity


# -----------------------------------------------------------------------------------
# Helper function to redact tokens from a message/opts object
# -----------------------------------------------------------------------------------
  @redactTokens: (object) ->
    object = JSON.parse JSON.stringify object
    object.qs.access_token = 'REDACTED' if object.qs.access_token?
    object.headers.Authorization = 'REDACTED' if object.headers.Authorization?
    object.json.verify_token = 'REDACTED' if object.json?.verify_token?
    object

# -----------------------------------------------------------------------------------
# Returns the message with tokens redacted
# -----------------------------------------------------------------------------------
  toString: ->
    clone = RequestBuilder.redactTokens @
    JSON.stringify clone


# -----------------------------------------------------------------------------------
# set a function to run on results. If the results are a data array (e.g. group/feed)
# the transform will be applied to each element in the array
# -----------------------------------------------------------------------------------
  setResultsTransform: (func) ->
    @resultsTransform = func
    @



# -----------------------------------------------------------------------------------
# Internal: set the next cursor to traverse in a recursive call
# -----------------------------------------------------------------------------------
  _setNextCursor: (cursor) ->
    @nextCursor = cursor
    @

# -----------------------------------------------------------------------------------
# Internal: For recursive calls, append more results to the message.
# -----------------------------------------------------------------------------------
  _addResults: (results) ->
    if @aggregationNode
      if results[@aggregationNode]
        results = results[@aggregationNode]
      else
        throw new Error ("Trying to aggregate results on non existent node #{@aggregationNode}")

    results.map @resultsTransform if @resultsTransform?
    @debug "Appending #{results.length} results"
    #TODO: Strinctly enforce results limit
    @results = @results.concat results
    @


# -----------------------------------------------------------------------------------
# Returns a promise to the results of the request, which is immediately sent
# -----------------------------------------------------------------------------------
  send: (context) ->
    RequestBuilder.send context, @


# -----------------------------------------------------------------------------------
# Send a RequestBuilder object {message} using APIContext {context}
# -----------------------------------------------------------------------------------
  @send: (context, message) ->
    context.injectAuthorization message.auth, message


    ## Return promise

    opts = JSON.parse JSON.stringify message.opts

    if message.nextCursor?
      context.debug "Request has cursor, generating call to #{message.nextCursor}"
      delete opts.qs
      delete opts.body
      delete opts.json
      opts.url = message.nextCursor
      delete message.nextCursor


    context.debug 'Sending Request: %o', RequestBuilder.redactTokens opts
    opts.resolveWithFullResponse = true
    return context.limiter.request(opts)
      .then (response) ->
        if response?['statusCode'] == 200
          context.debug "#{message.description} ...  result: #{response['statusCode']}"
          resp = response['body']
          if typeof response['body'] is 'string'
            resp = JSON.parse response['body']
            # Multi response
            # TODO: While this works for most communities,
            # the recursion will blow the stack when there is a very large number
            #       of results. Utilize an async queue to avoid
            if message.followNextCursor
              message._addResults resp
              if resp['paging']?['next']?
                if message.results.length < message.resultsLimit
                  context.debug "Received a next cursor #{resp['paging']['cursors']['after']}, following..."
                  await RequestBuilder.send context, message._setNextCursor resp['paging'].next
                else
                  context.debug "limit (#{message.results.length}/#{message.resultsLimit}) reached, stopping recursion"
                  return message.results #... aannnd we are back from the stack dive
              else
                context.debug "No more cursor, resolving promise with #{message.results.length} total results"
                return message.results ## maximum depth, prepare to surface..

            else
              resp = message.resultsTransform resp if typeof message.resultsTransform is 'function'
              return resp
          else
            return resp
        else
          throw new Error ("Non 200 status code #{JSON.stringify response}")

      .catch (error) ->
        context.debug 'Request Error: %o', error
        throw error


module.exports.APIContext = class APIContext

  constructor: (@name, load) ->
    @debug = require('debug')("API:#{@name}")
    @debug "Creating new context #{@name}"
    @authHooks = {}
    @RequestBuilder = RequestBuilder
    @load load if load?


  load: (api) ->
    throw new Error('Can only load one extension') if @loaded
    @loaded = true
    @debug "Loading #{api.name}, #{api.url}"
    @url = api.url
    @registerExtensions api.registerExtensions(@) if api.registerExtensions?
    @registerAuthCallbacks api.authCallbacks if api.authCallbacks
    @loadImports(api.imports) if api.imports?
    @limiter = new RateLimiter api.limits || DEFAULT_LIMITS
    @



  registerAuthCallbacks: (callbacks) ->
    @debug 'Registering Auth Callbacks'
    for k, v of callbacks
      @authHooks[k] = v
      @debug "  #{k} registered"


  registerExtensions: (ext) ->
    @debug 'Registering api extensions'
    for k, v of ext
      @debug "  #{k} registered"
      @[k] = v


  loadImports: (imports) ->
    @debug 'Loading helper imports', imports

    for key, modules of imports
      @[key] = {}
      for mod in modules
        loadedModule = require(mod)(@)
        for name, value of loadedModule
          @debug "  Loaded  #{@name}.#{key}.#{name} from #{mod}"
          @[key][name] = value

    return

  setAuthCallback: (type, fn) ->
    @debug 'Setting authorization function'
    throw new Error('fn must be a function') if typeof fn != 'function'
    @authHooks[type] = fn
    return

  injectAuthorization: (type, message) ->
    throw new Error("No authorization function #{type} set") if not @authHooks[type]?
    @authHooks[type](message)

  send: (req) ->
    RequestBuilder.send @, req

  createCall: (opts) -> new RequestBuilder({url: @url}, opts)
  customCall: (CustomClass, opts) -> new CustomClass({url: @url}, opts)


module.exports.create  = (name, load) ->
  new APIContext(name, load)