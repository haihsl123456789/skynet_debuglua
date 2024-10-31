local skynet = require "skynet"

local sprotoparser = require "sprotoparser"  
local sproto = require "sproto"  


local test_net = function ()
	local schema = [[  
		.package {  
			type 0 : integer  
			session 1 : integer  
		}  
		
		.Request {  
			id 0 : integer  
			message 1 : string  
		}  
		
		.Response {  
			success 0 : boolean  
			info 1 : string  
		}  
		]]  
		
		local sp = sproto.parse(schema)  

		local host = sp:host("package") 
		local request_proto = sp:attach(sp)  


		local function request_handler(name, args, response)  
			print("Received request:", name)  
			print("Arguments:", args.id, args.message)  
		
			-- 生成响应  
			if response then  
				return response { success = true, info = "Request processed" }  
			end  
		end  
		local function on_receive_message(data)  
			local type, name, request, response = host:dispatch(data)  
			if type == "REQUEST" then  
				local result = request_handler(name, request, response)  
				if result then  
					-- 发送响应  
					send_message(result)  
				end  
			elseif type == "RESPONSE" then  
				print("Received response:", name)  
			end  
		end  		

		local session = 1  
		local request_data = request_proto("Request", { id = 123, message = "Hello" }, session)  
		-- send_message(request_data)  
end

skynet.start(function()
	print("Main Server start")
	--

	
	local schema = [[  
	.package {  
		type 0 : integer  
		session 1 : integer  
	}  
	.Person {  
		name 0 : string  
		age 1 : integer  	
	}
	Personx 1{  
		request {
			name 0 : string  
			age 1 : integer  
		}
	}  
	]]  
	
	local sp = sproto.parse(schema)  

	--
	local person = {  
		name = "Alice",  
		age = 30  
	}  
	
	local encoded = sp:encode("Person", person)  
	
	--
	local decoded = sp:decode("Person", encoded)  
	print(decoded.name)  -- 输出 "Alice"  
	print(decoded.age)   -- 输出 30  

	--
	-- test_net()
	
	print("Main Server exit")
	skynet.exit()
end)
