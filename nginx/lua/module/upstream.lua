-- -*- coding: utf-8 -*-
-- -- @Date    : 2016-03-28 15:40
-- -- @Author  : Aifei (aifei@openresty.org)
-- -- @Link    : 
-- -- @Disc    : record nginx infomation 

local config  = require "lua.module.config"
local common  = require "lua.module.common"
local matcher = require "lua.module.matcher"

local _M = {}

_M.url_route = {}

local KEY_UPSTREAM = "upstream_"

function _M.run()
    -- body 
    -- matcher:run will return true if matches
    if matcher:run(config.sys_fetch_upstream_matcher()) then
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

function _M.log()
    -- report according to host
    local upstream_status = ngx.shared.status

    -- local server_zone = comm.json_encode(upstream_status:get(ngx.var.host)) or {total_req=0, }
    if ngx.var.upstream_addr then
        ngx.log(ngx.DEBUG, "upstream_addr= ", ngx.var.upstream_addr)
        ngx.log(ngx.DEBUG, "upstream_cache_status= ", ngx.var.upstream_cache_status)
        ngx.log(ngx.DEBUG, "upstream_connect_time= ", ngx.var.upstream_connect_time)
        ngx.log(ngx.DEBUG, "upstream_response_length= ", ngx.var.upstream_response_length)
        ngx.log(ngx.DEBUG, "upstream_response_time= ", ngx.var.upstream_response_time)
        ngx.log(ngx.DEBUG, "upstream_status= ", ngx.var.upstream_status)
        ngx.log(ngx.DEBUG, "host= ", ngx.var.host)
    end

end


function  _M.upstreams( ... )
    -- body
    local tmp = {}
    local upstream = require "ngx.upstream"

    for index, name in pairs(upstream.get_upstreams()) do
        tmp[name] = upstream.get_servers(name)
    end

    ngx.say(common.json_encode(tmp))
end

function _M.report()
    -- body
    
end

return _M
