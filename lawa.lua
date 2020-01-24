--[[

Copyright © 2017 Mihail Zuev <z.m.c@list.ru>. 
Author: Mihail Zuev <z.m.c@list.ru>.
 
All rights reserved.
 
Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of the <organization> nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.
                                                                                
THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

--]]

--[[
		NOTE:
			This module requires upvalue variables based on the lua-ev library
				timer: event-driven timer object
				kernel: event-driven main loop object

			This variables usually uses only in "await" implementation
			If another event-driven library will be use, then correct the "await" function according to the library used
--]]

-- Future Lightweight Asynchronous WWW Agent
local lawa = {}

-- Init upvalue variables if any
local mod, mpath, kernel, timer, log = ...

-- Flag that indicates where we are executing whithin an existing loop or not
local main = kernel and true or false

-- Standart LUA Socket Library
local socket = require "socket"

-- Event Library
local ev = require "ev"

-- Coroutine Oriented Portable Asynchronous Services Library
-- It will be used only as a dispatcher
local copas = require "copas"

-- Implementation of HTTP(s) from a Coroutine Oriented Portable Asynchronous Services Library
-- Only required for parsing(asynchronously) HTTP(s) requests.
local request = require("copas.http").request

-- This module usually used with "log" function implementation as upvalue
-- If "log" function is not implemented then masquarade "print" as "log" object
log = log or setmetatable({},{__index = function(t,k) return print end})

--The Timer object. If not defined upvalue use ev.Timer object
timer = timer or ev and ev.Timer
-- The "default" event loop. If not defined upvalue use default by ev.Loop
kernel = kernel or ev and ev.Loop.default

-- Non-blocking wait until function(as incoming parameter) return non-true
local await = function(n)
	local thread, main = coroutine.running()
	-- run only inside a coroutine not main thread
	if not main then
		local stat, err
		local w = 0.005

		-- Idle simulation with 5ms interval
		timer.new(function(l,t)
			if n(w) then
				t:stop(l)

				stat, err = coroutine.resume(thread)

				-- If an error ocurred inside coroutine
				-- Just print error message and move on
				if not stat then
					log.error(err)
				end
			end
		end,w,w):start(kernel)
		
		return coroutine.yield()
	else
		log.warn("run only inside a coroutine")
	end
end

-- Function of request itself
local query = function(url, timeout)
	-- Future response objects
	local body, status, header, response
	-- Create coroutine obviously
	local thread = copas.addthread(function()
		-- Asynchronous http request
		body, status, header, response = request(url)

		-- If closed by connection timeoud
		if status == 'closed' then
			body, status, response = 'connection timeout', 504, "HTTP/1.1 504 Gateway Timeout"
		end
	end)
	-- Get linked socket
	local skt = select(2,coroutine.resume(thread))

	-- Simulate a synchronous wait until get response or error occured or timeout
	await(
		(function(count)
			local step = 0
			local count = type(count) == 'number' and count or 5.25

			return function(n)
				-- Request function is ended
				if coroutine.status(thread) == 'dead' then
					-- Just exit from wait
					return true
				else
					-- Check if timeout occured
					if step > count then
						-- Close linked socket and enden coroutine
						pcall(skt['close'],skt) return coroutine.resume(thread)
					end
					-- Another iteration step
					step = (not copas.step(0))
						and step + n -- If no data on socket, then increment timer
						or step -- Data is present, just copy "step"
				end
			end
		end)(timeout)
	)

	-- Return response objects
	return body, status, header, response
end

-- Create Lightweight Asynchronous WWW Agent
lawa = setmetatable(
	{
		-- Just for the call chain
		xhr = main
		-- Working inside an existing loop
		-- Just redirect in to __call metamethod
		and function(self,...)
			local ua
			local url, timeout = ...
			-- OOP style check execution
			if (type(self) == 'table' and getmetatable(self) and type(getmetatable(self)['__call']) == 'function') then
				-- OOP style
				ua = self
			else
				-- not OOP style
				timeout, url, ua = url, self, lawa
			end
			-- Just redirect in to __call metamethod
			return ua(url,timeout)
		end
		-- Working standalone
		-- We Prepart our own coroutine and start an event-driven loop
		or function(self,...)
			local url, timeout = ...
			local body, status, header, response
			-- OOP style check execution
			if not (type(self) == 'table' and type(getmetatable(self)['__call']) == 'function') then
				-- not OOP style
				-- Prepare variables
				timeout, url = url, self
			end

			-- Request coroutine
			local thread = coroutine.create(
				function(...)
					-- Request obviously
					body, status, header, response = query(url,timeout)
				end
			)

			-- Start Request
			coroutine.resume(thread)

			-- Waiting result
			kernel:loop()

			-- Return what we have
			return body, status, header, response
		end
	},
	{
		__call = function(self, url, timeout)
			-- Check startup environment
			if not main then
				-- Standalone
				return self:xhr(url, timeout)
			else
				-- With event-driven environment
				return query(url,timeout)
			end
		end
	}
)

return lawa

