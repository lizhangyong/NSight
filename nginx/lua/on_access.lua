-- -*- coding: utf-8 -*-
-- -- @Date    : 2016-03-28 15:40
-- -- @Author  : Aifei (aifei@openresty.org)
-- -- @Link    :
-- -- @Disc    : record nginx infomation

local filter   = require "lua.module.filter"
local router   = require "lua.module.router"

-- if redis server can't be access, erro maybe occur in error.log
-- filter:run()

router:run()
