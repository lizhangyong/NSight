-- -*- coding: utf-8 -*-

local json = require "cjson"
local common = require "lua.module.common"


local _M = {}

local KEY_URI_STATUS = "X_"
local KEY_URI_SIZE = "Y_"
local KEY_URI_TIME = "Z_"
local KEY_URI_COUNT = "T_"
local KEY_REQ_HOST  = "HOST_"

function _M.clear()
    local summary = ngx.shared['summary']
    summary:flush_all()
end

function _M.log()
    local uri = ngx.var.uri

    local from, to, err = ngx.re.find(uri, "(/js|/css)", "jo")

    if from then return end

    local summary = ngx.shared['summary']

    local status_code = ngx.var.status;
    local key_host   = KEY_REQ_HOST
    local key_status = KEY_URI_STATUS..uri.."_"..status_code
    local key_size = KEY_URI_SIZE..uri
    local key_time = KEY_URI_TIME..uri
    local key_count = KEY_URI_COUNT..uri

    if summary:get( key_count ) == nil then
        summary:set( key_count, 0 )
    end

    if summary:get( key_status ) == nil then
        summary:set( key_status, 0 )
    end

    if summary:get( key_size ) == nil then
        summary:set( key_size, 0 )
    end

    if summary:get( key_time ) == nil then
        summary:set( key_time, 0 )
    end

    --log info with the url
    summary:incr( key_count, 1 )
    summary:incr( key_status, 1 )
    summary:incr( key_size, ngx.var.body_bytes_sent )
    summary:incr( key_time, ngx.var.request_time )
end

function _M.report()

    -- local dict = nil
    local report = {}
    local record_uri = nil
    local status = nil
    local size = nil
    local time = nil
    local count = nil
    local summary = ngx.shared['summary']

    local keys = summary:get_keys(0)
    local str_sub = string.sub


    for k, v in pairs( keys ) do
        record_uri = nil
        status = nil
        size = nil
        time = nil
        count = nil

        -- ngx.log(ngx.DEBUG, "k = ", k, "v = ", v)

        if v.find(v, KEY_URI_STATUS) == 1 then
            record_uri = str_sub( v, string.len(KEY_URI_STATUS) + 1, -5 )
            status = str_sub( v,-3 )
        elseif v.find(v, KEY_URI_SIZE) == 1 then
            record_uri = str_sub( v, string.len(KEY_URI_SIZE) + 1 )
            size = summary:get( v )
        elseif v.find(v, KEY_URI_TIME) == 1 then
            record_uri = str_sub( v, string.len(KEY_URI_TIME) + 1 )
            time = summary:get( v )
        elseif v.find(v, KEY_URI_COUNT) == 1 then
            record_uri = str_sub( v, string.len(KEY_URI_COUNT) + 1 )
            count = summary:get( v )
        end

        if record_uri ~= nil then
            if report[record_uri] == nil then
                report[record_uri] = {}
                report[record_uri]["status"] = {}
            end

            if status ~= nil then
                report[record_uri]["status"][status] = summary:get( v )
            elseif time ~= nil then
                report[record_uri]["time"] = time
            elseif
                size ~= nil then
                report[record_uri]["size"] = size
            elseif count ~= nil then
                report[record_uri]["count"] = count
            end
        end
    end

    for k, v in pairs( report ) do
        if v['time'] ~= nil and v['count'] ~= nil and v['size'] ~= nil then
            v["avg_time"] = string.format("%.3f", v["time"]/v["count"])
            v["avg_size"] =  string.format("%.2f", v["size"]/v["count"])
            v["size"] =  string.format("%.2f", v["size"])
        else
            report[k] = nil
        end
    end

    ngx.say(common.json_encode( report ))

    return ngx.exit(200)

end

return _M
