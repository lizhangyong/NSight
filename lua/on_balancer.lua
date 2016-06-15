-- -*- coding: utf-8 -*-
-- -- @Date    : 2016-03-28 15:40
-- -- @Author  : Aifei (aifei@openresty.org)
-- -- @Link    : 
-- -- @Disc    : dynamic upstream

local config = require "lua.module.config"
local balancer = require "ngx.balancer"
local common = require "lua.module.common"

-- [{"addr":"10.18.31.87:80","weight":"4"}] format like
local function random_select( tab )
    -- body
    if #tab == 0 then -- never happen
        return nil, nil, "no upstream found"
    end

    ----------   get index accord weight    --------

    local list   = {}
    local index  = 0
    local weight = 0
    for _, v in pairs(tab) do
        weight = (v.weight or 1) + weight
        table.insert(list, weight)
    end

    math.randomseed(ngx.time())
    local random = math.random(1, weight)

    for i, v in pairs(list) do
        if random <= v then
            index = iweight
            break
        end
    end

    -------------------  end  ----------------------
    
    local selected = tab[index]

    local t = common.split_no_pat(selected.addr, ":")

    ngx.log(ngx.DEBUG, "random_select host:", t[1], " and port:", t[2])
    
    return t[1], t[2], nil
end

local host, port, err = random_select(config.sys_fetch_upstreams())

if err then
    return ngx.log(ngx.WARN, "transport request failed, err = ", err)
end

local ok, err = balancer.set_current_peer(host, port)

if not ok then
    ngx.log(ngx.ERR, "faile to set the current peer: ", err)
    return ngx.exit(500)
end

