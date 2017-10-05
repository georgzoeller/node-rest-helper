
#assert = require 'assert'
should = require 'should'


describe 'Core Module', ->
  describe 'validate exports', ->
    core = require './../dist/node-rest-helper'
    it 'should return something', ->
      should.exists core


describe 'API Wrapper', ->
  api = null
  request = null
  describe 'validate exports', ->
    core = require './../dist/node-rest-helper'
    it 'should require successfully', ->
      should.exists core
    it 'should export create function', ->
      should.exists core.create

    it 'should create successfully', ->
      api = core.create 'test.api'
      should.exists api
      api.should.have.property('name').which.is.a.String().and.match 'test.api'
      api.should.have.property('RequestBuilder').which.is.a.Function()
      api.should.have.property('createCall').which.is.a.Function()
      api.name.should.equal 'test.api'

  describe 'load', ->
    core = require './../dist/node-rest-helper'
    it 'should load a dummy definition', ->
      api = core.create 'test.api'
      api.should.not.have.property('test')
      api.load require '../test/test-module'
      api.should.have.property('url').which.is.a.String().and.match 'http://localhost'
      api.should.have.property('test').which.is.a.Function()

    it 'should throw when attempting to load twice', ->
      (-> api.load '../test/test-module').should.throw "Can only load one extension"


    it 'should return a request object', ->
      request = api.test endpoint: 'test1'
      should.exist request
      request.should.have.property('opts').which.is.an.Object()



describe 'RequestBuilder', ->
  api = null
  request = null
  core = require './../dist/node-rest-helper'
  api = core.create 'test.api'
  api.load require '../test/test-module'
  request = api.test endpoint: 'test1'

  it 'request.addHeader should add a header', ->
    request.addHeader 'a','b'
    request.opts.should.have.property('headers').which.is.an.Object()
    request.opts.headers.should.have.property('a').match('b')

  it 'request.addJson should add JSON field', ->

    # addJson should not add null values
    request.addJson 'a', null
    request.opts.should.not.have.property('json')

    request.addJson 'a','b'
    request.opts.should.have.property('json').which.is.an.Object()
    request.opts.headers.should.have.property('a').match('b')

  it 'request.addQueryStringParams should add a param', ->
    request.addQueryStringParams {a: 'b'}
    request.opts.should.have.property('qs').which.is.an.Object()
    request.addQueryStringParams {d: true, f: 1}
    request.opts.qs.should.have.property('a').which.is.a.String().and.match 'b'
    request.opts.qs.should.have.property('d').which.is.a.Boolean().and.match true
    request.opts.qs.should.have.property('f').which.is.a.Number().and.match 1

  it 'should default to method=GET', ->
    request.opts.should.have.property('method').which.is.a.String().and.match 'GET'

  it 'request.setMethod should only allow valid values', ->
    for method in ['GET', 'POST', 'DELETE', 'PUT']
      request.setMethod method
      request.opts.should.have.property('method').which.is.a.String().and.match method

  it 'request.setMethod throw on invalid values', ->
    (-> request.setMethod('INVALID')).should.throw "INVALID is not a valid request method"






