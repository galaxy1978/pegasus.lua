local Request = require 'pegasus.request'

function getInstance(headers)
  local position = 1
  local param = {
    receive = function()
      if headers[position] ~= nil then
        local outcome = headers[position]
        position = position + 1

        return outcome
      end

      return nil
    end,

    getpeername = function(self)
      return '192.30.252.129'
    end
  }

  return Request:new(8080, param)
end

function length(dict)
  local count = 0
  for k in pairs(dict) do count = count + 1 end

  return count
end

function verifyHttpMethod(method)
  local headers = { method .. ' /index.html HTTP/1.1', '' }
  local request = getInstance(headers)
  local result = request:method()

  assert.are.equal(method, result)
end

describe('require', function()
  test('basic request', function()
    local headers = { 'GET /index.html HTTP/1.1', '' }
    local request = getInstance(headers)

    assert.are.equal(request:path(), '/index.html')
    assert.equal(request.ip, '192.30.252.129')
    assert.equal(request.port, 8080)
  end)

  test('http methods', function()
    verifyHttpMethod('GET')
    verifyHttpMethod('POST')
    verifyHttpMethod('DELETE')
    verifyHttpMethod('PUT')
  end)

  test('headers', function()
    local request = getInstance(
      { 'GET /Makefile?a=b&c=d HTTP/1.1', 'a: A', 'b: B', '', 'C=3', '' }
    )

    assert.are.same(
      request:headers(),
      { ['a'] = 'A', ['b'] = 'B' }
    )

    assert.are.same(
      request.querystring,
      { ['a'] = 'b', ['c'] = 'd' }
    )
  end)

  test('find value with = signal', function()
    local headers = { 'GET /Makefile?a=b= HTTP/1.1', 'a: A=', '' }
    local request = getInstance(headers)
    local result = request:headers()

    assert.are.same(
      request:headers(),
      { ['a'] = 'A=' }
    )
  end)

  test('empty path', function()
    local headers = { 'GET HTTP/1.1' }
    local request = getInstance(headers)

    assert.is_nil(request:method())
  end)

  test('path with spaces', function()
    local headers = { 'GET   HTTP/1.1', '' }
    local request = getInstance(headers)

    assert.is_nil(request:method())
  end)

  it('should not crash on invalid first line', function()
    local request, result
    assert.not_error(function()
      local headers = { 'garbage', nil }
      request = getInstance(headers)
      result = request:headers()
    end)

    assert.is_nil(request:method())
  end)

  describe('path', function()
    local fixtures = {
      ['/'              ] = '/';
      ['./'             ] = '/';
      ['/.'             ] = '/';
      ['.'              ] = '/';
      ['../'            ] = '/';
      ['/..'            ] = '/';
      ['a/../b/..'      ] = '/';
      ['a/../b/../'     ] = '/';
      ['a/../../b/../'  ] = '/';
      ['a/../../b/c/../'] = '/b/';
      ['a/../../b'      ] = '/b';
      ['a/../../b/'     ] = '/b/';
      ['./b'            ] = '/b';
      ['./b/'           ] = '/b/';
      ['./b/.'          ] = '/b/';
      ['./.b'           ] = '/.b';
      ['a/..b'          ] = '/a/..b';
      ['a/.../b'        ] = '/a/.../b';
      ['/a..'           ] = '/a..';
      ['/a../'          ] = '/a../';
      ['/../../a'       ] = '/a';
      ['a/../../././//' ] = '/';
    }

    for fixture, result in pairs(fixtures) do
      local name = 'should normalize path - ' .. fixture
      it(name, function()
        local headers = { 'GET ' .. fixture .. ' HTTP/1.1' }
        local request = getInstance(headers)

        assert.equal(request:path(), result)
      end)
    end
  end)
end)
