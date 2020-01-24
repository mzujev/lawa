# Lawa is a Lightweight Asynchronous WWW Agent.

### Features

- Asynchronous (uses the event-driven [lua-ev](https://github.com/brimworks/lua-ev) library along with coroutines)
- Supports HTTP(s) (uses an http request object from [copas](https://github.com/keplerproject/copas) dispatcher)
- Compatible with Lua 5.1, 5.2, 5.3 and [LuaJIT](http://luajit.org/)

### Installation

To install ***Lawa*** use `git clone` and manually resolve the dependencies.
```sh
	mkdir -p ~/lawa/ && cd ~/lawa/
	git clone https://github.com/mzujev/lawa
```
After that, copy `lawa.lua` to the appropriate Lua environment path or strictly require `lawa.lua` in your project.

### Usage 
***Lawa*** can be used as a standalone WWW-Agent or inside an coroutines based environment with the [lua-ev](https://github.com/brimworks/lua-ev) library as dispatcher. If ***Lawa*** is planned to be used in a coroutine environment, then the [lua-ev](https://github.com/brimworks/lua-ev)  library is needed for dispatching, because `await`(see sources) implementation is based on `ev.Timer` and uses main loop from [lua-ev](https://github.com/brimworks/lua-ev) library.

*Example: as standalone*
```lua
    local ltn12 = require 'ltn12'
    local lawa = require 'lawa'
    local body, status, headers, response
    
    -- Simple request
    body, status, headers, response = lawa('http://checkip.dyndns.org')
    
   -- POST request with headers set
   _, status, headers, response = lawa(
    method = 'POST',
    sink = ltn12.sink.table(body),
    url = 'http://checkip.dyndns.org',
    headers = {['content-type'] = 'x-form-request/json'}
   )
   
```

*Example: in a coroutine environment*
```lua

    -- Compatibility/Extensions module located at https://github.com/mzujev/extens.
    -- Which in particular contains a modified 'require' function.
    -- That allows to pass some parameters to the loadable module at require.
    require 'extens'
    
    local ev = require 'ev'
    local timer = ev.Timer
    local kernel = ev.Loop.default
    local lawa = require('lawa', kernel)
    
    --[[
        ...
        SOME LOGIC WITH FEW COROUTINES
        ...
    --]]
    
    -- Delayed request
    timer.new(
        coroutine.wrap(
            function()
                print('After 5 seconds', lawa('http://checkip.dyndns.org'))
            end 
    ),5):start(kernel)
    
    -- Display the result when it will come
    coroutine.wrap(
        function()
            print('When response will come', lawa('http://checkip.dyndns.org'))
        end
    )()
    
    -- Run main loop dispatcher
    kernel:loop()
```

### Dependencies

- [lua-ev](https://github.com/brimworks/lua-ev) - Lua integration with libev
- [copas](https://github.com/keplerproject/copas) - Coroutine-based Asynchronous Dispatcher
- [luasocket](https://github.com/diegonehab/luasocket) - Lua interface library with the TCP/IP stack
- [luasec](https://github.com/brunoos/luasec) - Library for ssl support

### Copyright
See [Copyright.txt](https://github.com/mzujev/lawa/blob/master/Copyright.txt) file for details
