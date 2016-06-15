-- -*- coding: utf-8 -*-
-- -- @Date    : 2016-03-28 15:40
-- -- @Author  : Aifei (aifei@openresty.org)
-- -- @Link    : 
-- -- @Disc    : record nginx infomation 

local config  = require "lua.module.config"
local matcher = require "lua.module.matcher"

local _M = {}

_M.url_route = {}

function _M.run()
    -- body 
    -- matcher:run will return true if matches
    if matcher:run(config.sys_fetch_redirect_matcher()) then
        local res, err = ngx.location.capture('/internal_proxy', {
                copy_all_vars = true,
                always_forward_body = true
            }) 

        if not res then
            ngx.log(ngx.WARN, "backend proxy err = ", err)
            return ngx.exit(res.status)
        else
            return ngx.say(res.body)
        end
    end

end


return _M
