module.exports =
  name: 'test module'
  url: 'http://localhost'

  registerExtensions: (api) ->
    test: (id, edge, opts={}) ->
      opts.endpoint ?= "#{id}/#{edge}"
      new api.RequestBuilder({url: @url, version: "v#{@version}"}, opts)