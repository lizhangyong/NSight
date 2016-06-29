-- -*- coding: utf-8 -*-
-- -- @Date    : 2016-03-28 15:40
-- -- @Author  : Aifei (aifei@openresty.org)
-- -- @Link    : 
-- -- @Disc    : record nginx infomation 

local summary = require "lua.module.summary"
local status  = require "lua.module.status"
-- local upstream  = require "lua.module.upstream"

summary.log()
status.log()
-- upstream.log()