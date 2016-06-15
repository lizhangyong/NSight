-- -*- coding: utf-8 -*-
-- -- @Date    : 2016-03-28 15:40
-- -- @Author  : Aifei (aifei@openresty.org)
-- -- @Link    : 
-- -- @Disc    : record nginx infomation 

local json = require "cjson"

local login     = require "lua.module.login"
local dashboard = require "lua.module.dashboard" 
local template  = require "lua.resty.template"
-- local upm       = require "dashboard.lua.upstream"
local status    = require "lua.module.status"
local summary   = require "lua.module.summary"
local config    = require "lua.module.config"
local accounts  = require "lua.module.accounts"
local upstream  = require "lua.module.upstream"

local _M = {}

_M.url_route = {}

function _M.run()
    -- body
    local uri    = ngx.var.uri
    local action = string.lower(ngx.req.get_method().." ".. uri)
    local handle = _M.url_route[action]
    
    if handle then        
        handle(action)     
        return ngx.exit(200)
    else
        return ngx.exit(404)
    end
end

-- _M.url_route["get /dashboard/login"] = login.init  -- show login interface

_M.url_route["post /add_upstream"] = config.add_upstream
_M.url_route["post /del_upstream"] = config.del_upstream
_M.url_route["get /fetch_upstream"] = config.fetch_upstream_debug


_M.url_route["get /status"]        = status.report
_M.url_route["get /upstreams"]     = upstream.upstreams

_M.url_route["get /summary"]       = summary.report 
_M.url_route["get /summary_clear"] = summary.clear

_M.url_route["post /add_filter_rule"]          = config.sys_add_access_rule
_M.url_route["post /del_filter_rule"]          = config.sys_del_access_rule
_M.url_route["post /enable_filter_rule"]       = config.sys_enable_access_rule
_M.url_route["post /disable_filter_rule"]      = config.sys_disable_access_rule
_M.url_route["get /fetch_filter_rules"]        = config.sys_fetch_all_access_rules
_M.url_route["get /fetch_enable_filter_rules"] = config.sys_fetch_enabled_access_rules

return _M

