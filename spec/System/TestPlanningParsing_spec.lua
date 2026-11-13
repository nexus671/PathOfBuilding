describe("Cooperative build XML parsing",function()
	local xml=common.xml
	it("preserves entities, comments, attributes and CDATA across yields",function()
		local text=[=[<?xml version="1.0"?><Root title="Life &amp; mana"><!-- omitted --><Item id='1'>A &lt; B</Item><Notes><![CDATA[Keep <raw> & text]]></Notes><Empty/></Root>]=]
		local expected=assert(xml.ParseXML(text));local yields=0
		local thread=coroutine.create(function() return xml.ParseXML(text,function() yields=yields+1;coroutine.yield() end) end)
		local result
		while coroutine.status(thread)~="dead" do local ok,value=coroutine.resume(thread);assert.is_true(ok,tostring(value));result=value end
		assert.is_true(yields>5);assert.are.same(expected,result)
		assert.are.equal("Life & mana",result[1].attrib.title);assert.are.equal("A < B",result[1][1][1]);assert.are.equal("Keep <raw> & text",result[1][2][1])
	end)
	it("retains malformed-document errors when parsing cooperatively",function()
		for _,text in ipairs({"</Root>","<Root><Child></Root>","<Root>"}) do
			local expected,message=xml.ParseXML(text);local count=0
			local result,err=xml.ParseXML(text,function() count=count+1 end)
			assert.is_nil(expected);assert.is_nil(result);assert.are.equal(message,err);assert.is_true(count>0)
		end
	end)
	it("allows cancellation between tags without returning a partial document",function()
		local count=0;local document="<Root>"..string.rep('<Item value="1"/>',1000).."</Root>"
		local ok,message=pcall(xml.ParseXML,document,function() count=count+1;if count==10 then error("Cancelled parsing") end end)
		assert.is_false(ok);assert.is_truthy(message:find("Cancelled parsing",1,true));assert.are.equal(10,count)
		assert.are.equal(1000,#assert(xml.ParseXML(document))[1])
	end)
end)
