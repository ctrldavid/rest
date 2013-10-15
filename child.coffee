redis = require 'redis'
express = require 'express'
Future = require 'fibers/future'
uuid = require 'node-uuid'

client = redis.createClient()
client.setFuture = Future.wrap client.set, 2
client.getFuture = Future.wrap client.get, 1
client.smembersFuture = Future.wrap client.smembers, 1
client.saddFuture = Future.wrap client.sadd, 2
client.mgetFuture = Future.wrap client.mget, 1

client.on 'error', () ->
  console.error "REDIS ERROR:", arguments

client.on 'end', () -> console.log 'REDIS END'

client.select 8

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
  console.log "#{req.method} #{req.url} from #{req.ip}"
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
  res.end ''

app.put collection, (req, res) -> res.status(405).end('Cannot PUT to a collection')

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





