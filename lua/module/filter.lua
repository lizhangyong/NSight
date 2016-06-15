-- -*- coding: utf-8 -*-
-- -- @Date    : 2016-03-28 15:40
-- -- @Author  : Aifei (aifei@openresty.org)
-- -- @Link    : 
-- -- @Disc    : record nginx infomation 

local _M = {}

local config  = require "lua.module.config"
local matcher = require "lua.module.matcher"
local common = require "lua.module.common"

function _M.run()
    -- body 
    -- matcher:run will return true if matches
    local rules = config.sys_fetch_enabled_access_rules()

    for _, rule in pairs(rules) do 
        if matcher:run(rule.matcher) then
            return ngx.exit(rule.action.code or 403)        
        end
    end
  
end

return _M
