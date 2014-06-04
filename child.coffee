redis = require 'redis'
express = require 'express'
Future = require 'fibers/future'
uuid = require 'node-uuid'

Prefixes = {
  json: 'json'
  metadata: 'metadata'
  mimetype: 'metadata-mimetype'
}

client = redis.createClient()
client.setFuture = Future.wrap client.set, 2
client.getFuture = Future.wrap client.get, 1
client.smembersFuture = Future.wrap client.smembers, 1
client.saddFuture = Future.wrap client.sadd, 2
client.mgetFuture = Future.wrap client.mget, 1
client.delFuture = Future.wrap client.del, 1
client.sremFuture = Future.wrap client.srem, 2

client.on 'error', () ->
  console.error "REDIS ERROR:", arguments

client.on 'end', () -> console.log 'REDIS END'

client.select 0

# regexes for collection and item
collection = /\/$/
item = /[^\/]$/

app = express()

app.use express.bodyParser()
sid = uuid.v4()
served = 0
app.use (req, res, next) ->
  served = served + 1
  res.set "X-Server", sid
  res.set "Access-Control-Allow-Origin", "*"
  res.set "Access-Control-Allow-Headers", "Content-Type"
  res.set "Access-Control-Allow-Methods", "GET,POST,PUT,PATCH,DELETE"
  next()

app.use (req, res, next) ->
  console.log "#{req.method} #{req.url} from #{req.ip} (x-real-ip: #{req.headers['x-real-ip']})"
  try
    next.future()()
  catch e
    console.error 'ERROR', e

# Get item
app.get item, (req, res) ->
  value = client.getFuture(req.path).wait()
  res.end value

# Get collection
app.get collection, (req, res) ->
  ids = client.smembersFuture(req.path).wait()
  # mget freaks out if you send it an empty array.
  if ids.length > 0
    values = client.mgetFuture(ids.map((id)->"#{req.path}#{encodeURIComponent id}")).wait().map (str) -> JSON.parse str
  else
    values = []
  #value = JSON.stringify ids.map (id) -> {id}

  res.end JSON.stringify values

app.post item, (req, res) -> res.status(405).end('Must POST to a collection (url ending in /)')

app.post collection, (req, res) ->
  id = uuid.v4()
  req.body.id = id
  str = JSON.stringify req.body
  client.setFuture("#{req.path}#{id}", str).wait()
  client.saddFuture(req.path, id).wait()
  value = client.getFuture("#{req.path}#{id}").wait()
  # Response only needs to contain changed attributes. In this case we are giving the model an ID.
  res.status(201).end JSON.stringify {id}

app.put item, (req, res) ->
  col = req.path.match(/^.*\//)[0]
  id = decodeURIComponent req.path.match(/[^\/]*$/)[0]
  req.body.id = id
  str = JSON.stringify req.body
  client.setFuture(req.path, str).wait()
  # add it to the collection's set
  client.saddFuture(col, id).wait()
  res.end JSON.stringify {id}

app.put collection, (req, res) -> res.status(405).end('Cannot PUT to a collection')

app.delete item, (req, res) ->
  col = req.path.match(/^.*\//)[0]
  id = decodeURIComponent req.path.match(/[^\/]*$/)[0]

  client.delFuture(req.path).wait()
  client.sremFuture(col, id).wait()
  res.end ''

#app.listen 4001

# Child listen stuff

http = require 'http'

server = http.createServer()
server.on 'request', app

process.on 'message', (m, handle) ->
  if m == 'handle'
    server.listen handle
  else if m == 'log'
    console.log "Served by #{sid}: #{served}"

# Inform the master that we are ready to start handling requests
process.send 'ready'


###

TODO:
  Metadata stuff
  PUT /path/item?metadata=field
    Creates metadata:path/item hashmap if not already there
    sets metadata:path/item field to whatever was in the body of PUT
    tries to set metadata-mimetype:path/item field to the correct mimetype

  GET /path/item?metadata
    returns an array of the keys of metadata:path/item hashmap

  GET /path/item?metadata=field
    returns the raw contents of metadata:path/item field
    with mimetype set to metadata-mimetype:path/item field

  POST /path/?metadata=field
    Same as PUT, but creates a new item in /path/ and returns its ID
    so:
      /path/id -> {id:id}
      metadata:path/id field -> body of POST
      metadata-mimetype:path/id field -> mimetype of POST

  PATCH doesn't really work....
  DELETE just delete the fields




flushdb

GET /path/value -> get
GET /path/ -> smembers

POST /path/value -> ERR
POST /path/ -> sadd, set, return /path/:UID

PUT /path/value -> set
PUT /path/ -> ERR

PATCH /path/value -> obj merge then set?
PATCH /path/ -> ERR

DELETE /path/value -> del
DELETE /path/ -> ERR

###





