cp = require 'child_process'
http = require 'http'

server = http.createServer()

children = []

server.listen 5770, ->
  children = (cp.fork('child.coffee') for n in [0..0])  # 0..7 is 8 threads which seems to be best on my rmbp
  server.close()
  for child, i in children
    do (child, i) ->
      child.on 'message', (msg) ->
        if msg == 'ready'
          console.log "Child #{i} ready."
          child.send 'handle', server._handle
          # child.send 'server', server
  # server.close()

  server.on 'request', -> console.log 'fuck'

setInterval ->
    console.log '--------------------------------------'
    child.send('log') for child in children
, 60000

