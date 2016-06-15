-- -*- coding: utf-8 -*-
-- -- @Date    : 2016-03-28 15:40
-- -- @Author  : Aifei (aifei@openresty.org)
-- -- @Link    : 
-- -- @Disc    : record nginx infomation 

-- local status = require "lua.module.status"
local config = require "lua.module.config"
local status = require "lua.module.status"

config.init()

status.init()