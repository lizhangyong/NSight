-- -*- coding: utf-8 -*-
-- -- @Date    : 2016-03-28 15:40
-- -- @Author  : Aifei (aifei@openresty.org)
-- -- @Link    : 
-- -- @Disc    : record nginx infomation 

local json   = require "lua.resty.dkjson"
local common = require "lua.module.common"
-- local redis  = require "lua.module.redis"
-- local red    = redis:new()


local _M = {}

local SYS_SHARED_NAME     = "sys"
local KEY_CONFIG_UPSTREAM = "U_"
local KEY_CONFIG_RULE     = "R_"
local KEY_CONFIG_SYS      = "S_"
local KEY_SINGLE_INIT     = "I_"
local KEY_CONFIG          = "C_"
local KEY_FILTER_KEY      = "FILTER_"

-- init singleton configure
function _M.init()

    if not common.single_action(SYS_SHARED_NAME, KEY_SINGLE_INIT) then
        return
    end

    path = ngx.config.prefix() .. "conf/config"

    local simproxy = common.load_file_to_string(path)

    common.store_in_shared_cache(SYS_SHARED_NAME, KEY_CONFIG_RULE, simproxy) 

end

function _M.add_upstream( ... )
    -- body
    ngx.req.read_body()
    local data = ngx.req.get_body_data()
    local json_body = common.json_decode(data)

    if not json_body.name then
        return ngx.say(common.json_encode({ret="failed", err="wrong param"}))
    end 

    red:hset(KEY_CONFIG_UPSTREAM, json_body.name, data)

    return ngx.say(common.json_encode({ret="success", err=""}))
end


function _M.del_upstream( ... )
    -- body
    local name = ngx.var.arg_name

    if not name then
        return ngx.exit(ngx.HTTP_BAD_REQUEST)
    end

    red:hdel(KEY_CONFIG_UPSTREAM, name)

    return ngx.say(common.json_encode({ret="success", err=""}))
end


function _M.fetch_upstream( ... )
    -- body
    local res, err = red:hvals(KEY_CONFIG_UPSTREAM)

    local tmp = {}

    if res then 
        for index, v in pairs(res) do
            table.insert(tmp, common.json_decode(v))
        end
    end

    return common.json_encode(tmp)
end

function _M.fetch_upstream_debug( ... )
    -- body
    local res, err = red:hvals(KEY_CONFIG_UPSTREAM)

    local tmp = {}

    if res then 
        for index, v in pairs(res) do
            table.insert(tmp, common.json_decode(v))
        end
    end

    return ngx.say(common.json_encode(tmp)) 
end



-- function: sys_fetch_upstream_matcher()

-- ret:
-- {
--     all = true,
--     uri = [
--         {compare = '≈', value = '/api/xxx'},
--         {compare = '=', value = '/api/xxx'}
--     ],
--     ua = [
--         {compare = '≈', value = '/api/xxx'}
--     ]
-- }


function _M.sys_fetch_upstream_matcher()
    local configure = red:get(KEY_CONFIG)

    local t = common.json_decode(configure)

    if not t then
        return {}
    end

    return common.json_encode(t.upstream_matcher)
end

function _M.sys_set_upstream_matcher()
     -- body
    ngx.req.read_body()
    local t = common.json_decode(ngx.req.get_body_data())

    local configure = common.json_encode(red:get(KEY_CONFIG))

    configure.upstream_matcher = t

    red:set(KEY_CONFIG, common.json_encode(configure))

    return true
end


-- function: sys_fetch_redirect_matcher()

-- ret:
-- {
--     uri = [
--         {compare = '≈', value = '/api/xxx', url = ''},
--         {compare = '=', value = '/api/xxx', url = ''}
--     ],
--     ua = [
--         {compare = '≈', value = '/api/xxx', url= ''}
--     ]
-- }


function _M.sys_fetch_redirect_matcher()
    local configure = red:get(KEY_CONFIG)

    local t = common.json_decode(configure)

    if not t then
        return {}
    end

    return common.json_encode(t.redirect_matcher)
end

function _M.sys_set_redirect_matcher()
    -- body
    ngx.req.read_body()
    local t = common.json_decode(ngx.req.get_body_data())

    local configure = common.json_encode(red:get(KEY_CONFIG))

    configure.redirect_matcher = t

    red:set(KEY_CONFIG, common.json_encode(configure))

    return true
end

-- function: sys_add_access_rule()
-- ret:
-- {
--     "name":"UNID",
--     "enable":true,
--     "matcher":{
--         ['uri'] = {'compare' = '≈', 'val' = ''}
--     },
--     "action":{
--         ['code'] = 403
--     }
-- }

function _M.sys_add_access_rule()
    -- body
    ngx.req.read_body()
    
    local data = ngx.req.get_body_data()

    local json_data = common.json_decode(data)

    local ret = red:hexists(KEY_FILTER_KEY, json_data.name)

    if ret == 1 then
        ngx.say(common.json_encode({ret="failed", err="rule exists"}))   
        return 
    end
    
    red:hset(KEY_FILTER_KEY, json_data.name, data)

    ngx.say(common.json_encode({ret="success", err=""}))
    return
end

function _M.sys_del_access_rule()
    -- body
    local rule_name = ngx.var.arg_name

    if not rule_name then
        return ngx.exit(ngx.HTTP_BAD_REQUEST)
    end

    red:hdel(KEY_FILTER_KEY, rule_name)

    ngx.say(common.json_encode({ret="success", err=""}))
    return
end

function _M.sys_enable_access_rule()
    -- body
    local rule_name = ngx.var.arg_name

    if not rule_name then
        return ngx.exit(ngx.HTTP_BAD_REQUEST)
    end

    local ret = red:hget(KEY_FILTER_KEY, rule_name)

    local json_ret = common.json_decode(ret)

    json_ret.enable = true
    red:hset(KEY_FILTER_KEY, json_ret.name, common.json_encode(json_ret))
    ngx.say(common.json_encode({ret="success", err=""}))
    return
end

function _M.sys_disable_access_rule()
    -- body
     local rule_name = ngx.var.arg_name

    if not rule_name then
        return ngx.exit(ngx.HTTP_BAD_REQUEST)
    end

    local ret = red:hget(KEY_FILTER_KEY, rule_name)

    local json_ret = common.json_decode(ret)

    json_ret.enable = false
    red:hset(KEY_FILTER_KEY, json_ret.name, common.json_encode(json_ret))
    ngx.say(common.json_encode({ret="success", err=""}))
    return
end

function _M.sys_fetch_all_access_rules()
    -- body
    local res = red:hvals(KEY_FILTER_KEY)

    local tmp = {}

    if res then 
        for index, v in pairs(res) do
            table.insert(tmp, common.json_decode(v))
        end
    end

    return ngx.say(common.json_encode(tmp)) 

end

function _M.sys_fetch_enabled_access_rules()
    -- body
    local res = red:hvals(KEY_FILTER_KEY)

    local tmp = {}

    if res then 
        for index, v in pairs(res) do

            local t = common.json_decode(v)
            if t.enable == true then
                table.insert(tmp, t)
            end

        end
    end

    return tmp
    
end

return _M











