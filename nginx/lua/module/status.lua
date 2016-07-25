-- -*- coding: utf-8 -*-

local lock   = require "lua.resty.lock"
local common = require "lua.module.common"
local up     = require "ngx.upstream"
-- local notify = require "lua.module.common"

local _M = {}

local KEY_STATUS_INIT = "status_init"

local KEY_START_TIME = "G_"

local KEY_TOTAL_COUNT = "total_count"
local KEY_TOTAL_COUNT_SUCCESS = "total_success_count"
local KEY_CURRENT_REQ = "current_count"

local KEY_TRAFFIC_READ = "traffic_read"
local KEY_TRAFFIC_WRITE = "traffic_write"

local KEY_ACCEPTED = "M_"
local KEY_ACTIVE   = "N_"
local KEY_IDLE     = "O_"

local NGX_LOAD_TIMESTAMP = 'ngx_load_time'
local NGX_RELOAD_GENERATION = 'ngx_reload_generation'

local KEY_TIME_TOTAL = "time_total"

local KEY_SERVER_ZONES = "server_zones"

local KEY_UPSTREAM_ZONES = "upstream_zones"
local KEY_UPSTREAM_SERVER_INFO = "upstream_server_info"

local UPSTREAM_TIME_SUM = 'upstream_time_sum'
local UPSTREAM_REQUEST_COUNT = 'upstream_request_count'

local KEY_UPSTREAM_CNT     = "upstream_cnt"
local KEY_UPSTREAM_SUC_CNT = "upstream_success_cnt"
local KEY_UPSTREAM_REP_LEN = "upstream_rep_len"
local KEY_UPSTREAM_REP_TIME= "upstream_rep_time"

local KEY_HTTP_PROCESSING = "http_processing_"
local KEY_HTTP_PROCESSING_EXPIRE = 1

-- maybe optimized, read from redis
function _M.init()

    local shared_status = ngx.shared.status

    local newval, err = shared_status:incr(NGX_RELOAD_GENERATION, 1)
    if not newval and err == "not found" then
         shared_status:add(NGX_RELOAD_GENERATION, 0)
    end

    shared_status:set( NGX_LOAD_TIMESTAMP, ngx.time()) -- set nginx reload/restart begin uptime

    local ok, err = shared_status:add( KEY_STATUS_INIT, true )
    if ok then --if nginx from stop to start
		shared_status:set( KEY_TOTAL_COUNT, 0 )
		shared_status:set( KEY_TOTAL_COUNT_SUCCESS, 0 )

        shared_status:set( TRAFFIC_READ, 0 )
		shared_status:set( TRAFFIC_WRITE, 0 )

        shared_status:set( KEY_TIME_TOTAL, 0 )
    end

end


local function calculate_responses( responses, status )
    -- body
    if not responses then
        responses = {
            ['1xx'] = 0,
            ['2xx'] = 0,
            ['3xx'] = 0,
            ['4xx'] = 0,
            ['5xx'] = 0
        }
    end

    if status < 100 or status > 500 or not status then
        ngx.log(ngx.DEBUG, "unreasonable status = ", status)
        return
    end

    if status >= 100 and status < 200 then
        responses['1xx'] = responses['1xx'] + 1 
    elseif status >= 200 and status < 300 then
        responses['2xx'] = responses['2xx'] + 1 
    elseif status >= 300 and status < 400 then
        responses['3xx'] = responses['3xx'] + 1 
    elseif status >= 400 and status < 500 then
        responses['4xx'] = responses['4xx'] + 1 
    elseif status > 500 then
        responses['5xx'] = responses['5xx'] + 1 
    end

    return responses
end


local function server_statistics_responses( key, zone, status, notify_call)
    -- body
    local lock = lock:new("locks")
    local shared_status = ngx.shared.status
    local elapsed, err = lock:lock("_lock_" .. key)

    --count http requests per second
    local http_processing_count = shared_status:get(KEY_HTTP_PROCESSING .. zone)
    if not http_processing_count then
        shared_status:set( KEY_HTTP_PROCESSING .. zone, 1, KEY_HTTP_PROCESSING_EXPIRE)
    else
        shared_status:incr( KEY_HTTP_PROCESSING .. zone, 1 )
    end

    http_processing_count = ( http_processing_count or 0 ) + 1

    local json_zone = common.json_decode(shared_status:get(key)) or {}
    if nil == json_zone[zone] then
        json_zone[zone] = {
            processing = http_processing_count;
            requests   = 1,
            responses  = calculate_responses(nil, tonumber(status)),
            discarded  = 0,
            received   = ngx.var.request_length,
            sent       = ngx.var.bytes_sent 
        }
    else
        -- ngx.log(ngx.DEBUG, common.json_encode(json_server_zone))
        local t = json_zone[zone]
        json_zone[zone] = {
            processing = http_processing_count,
            requests   = t.requests + 1,
            responses  = calculate_responses(t.responses, tonumber(status)),
            discarded  = 0,
            received   = t.received + ngx.var.request_length,
            sent       = t.sent + ngx.var.bytes_sent
        }
    end

    -- set back to cache
    shared_status:set( key, common.json_encode(json_zone) )

    lock:unlock()

end


local function upstream_statistics_responses( key, zone, status, notify_call)
    -- body
    local lock = lock:new("locks")
    local shared_status = ngx.shared.status
    local elapsed, err = lock:lock("_lock_" .. key)
    local json_zone = common.json_decode(shared_status:get(key)) or {}

    if nil == json_zone[zone] then
        json_zone[zone] = {
            requests   = 1,
            responses  = calculate_responses(nil, tonumber(status)),
            discarded  = 0,
            received   = ngx.var.request_length,
            sent       = ngx.var.bytes_sent 
        }
    else
        -- ngx.log(ngx.DEBUG, common.json_encode(json_server_zone))
        local t = json_zone[zone]
        json_zone[zone] = {
            requests   = t.requests + 1,
            responses  = calculate_responses(t.responses, tonumber(status)),
            discarded  = 0,
            received   = t.received + ngx.var.request_length,
            sent       = t.sent + ngx.var.bytes_sent
        }
    end

    -- set back to cache
    shared_status:set( key, common.json_encode(json_zone) )

    lock:unlock()

end

--add global count info
function _M.log()
    local host    = ngx.var.host
    local up_addr = ngx.var.upstream_addr
    local shared_status = ngx.shared.status

    -- requests
    shared_status:incr( KEY_TOTAL_COUNT, 1 )

    if tonumber(ngx.var.status) < 400 then
        shared_status:incr( KEY_TOTAL_COUNT_SUCCESS, 1 )
    end

    if nil == shared_status:get(KEY_CURRENT_REQ) then
        shared_status:set(KEY_CURRENT_REQ, 1, 1)
    else
        shared_status:incr(KEY_CURRENT_REQ, 1) 
    end

    if ngx.var.remote_addr ~= ngx.var.server_addr then
        if nil == shared_status:get(KEY_TRAFFIC_READ) then
            shared_status:set(KEY_TRAFFIC_READ, tonumber(ngx.var.request_length), 1)
        else
            shared_status:incr( KEY_TRAFFIC_READ, tonumber(ngx.var.request_length)) 
        end

        if nil == shared_status:get(KEY_TRAFFIC_WRITE) then
            shared_status:set(KEY_TRAFFIC_WRITE, tonumber(ngx.var.bytes_sent), 1)
        else
            shared_status:incr( KEY_TRAFFIC_WRITE, tonumber(ngx.var.bytes_sent)) 
        end
    end

    shared_status:incr( KEY_TIME_TOTAL, ngx.var.request_time )

    -- server zone
    if true then
    -- if ngx.var.remote_addr ~= ngx.var.server_addr then -- expcept local request
        server_statistics_responses(KEY_SERVER_ZONES, ngx.var.host, ngx.var.status)
    end
    
    -- upstream zone
    -- ngx.log(ngx.DEBUG, "upstream addr = ", ngx.var.upstream_addr)
    if ngx.var.upstream_addr then -- expcept local request
        upstream_statistics_responses(KEY_UPSTREAM_SERVER_INFO, ngx.var.upstream_addr, ngx.var.upstream_status)
    end

end


local function get_nginx_info( report )
    -- local ngx_lua_version = ngx.config.ngx_lua_version --例如 0.9.2 就对应返回值 9002; 1.4.3 就对应返回值 1004003
    report.nginx_version = ngx.var.nginx_version
    -- report.ngx_lua_version = math.floor(ngx_lua_version / 1000000) .. '.' .. math.floor(ngx_lua_version / 1000) ..'.' .. math.floor(ngx_lua_version % 1000)
    report.address = ngx.var.server_addr .. ":" .. ngx.var.server_port
    report.worker_count = ngx.worker.count()
    -- report.load_timestamp = ngx.shared.status:get(NGX_LOAD_TIMESTAMP)
    report.timestamp = ngx.time()
    report.generation = ngx.shared.status:get(NGX_RELOAD_GENERATION)
    return report
end


local function get_connections_info()
    local report = {}
    report.current = tonumber(ngx.var.connections_active) --包括读、写和空闲连接数
    report.active = ngx.var.connections_reading + ngx.var.connections_writing
    report.idle = tonumber(ngx.var.connections_waiting)
    report.writing = tonumber(ngx.var.connections_writing)
    report.reading = tonumber(ngx.var.connections_reading)
    return report
end


local function get_requests_info()
    local report = {}
    report.total = ngx.shared.status:get(KEY_TOTAL_COUNT) or 0
    report.success = ngx.shared.status:get(KEY_TOTAL_COUNT_SUCCESS) or 0
    report.current = ngx.shared.status:get(KEY_CURRENT_REQ) or 0
    return report
end


local function get_serverzones_info()
    local report = {}
    local shared_status = ngx.shared.status
    local zones = shared_status:get(KEY_SERVER_ZONES)

    report = zones and #common.json_decode(zones).list or 0

    return report
end

local function fetch_upstream_info(t, upstreams, backup)
    local shared_status = ngx.shared.status
    local json_upstream_info = common.json_decode(shared_status:get(KEY_UPSTREAM_ZONES)) or {}
    local json_upstream_server_info = common.json_decode(shared_status:get(KEY_UPSTREAM_SERVER_INFO)) or {}

    for index, value in pairs(upstreams) do
        value.backup    = backup
        if not json_upstream_server_info[value.name] then
            value.requests  = 0
            value.responses = {}
        else
            value.requests  = json_upstream_server_info[value.name].requests or 0
            value.responses = json_upstream_server_info[value.name].responses or {}
        end
        value.sent     = json_upstream_info.sent or 0
        value.received = json_upstream_info.received or 0
        table.insert(t, value)
    end
end

local function get_upstreams_info()
    -- upstream
    local upstreams = up.get_upstreams()

    local upstream = {}
    for _, u in ipairs(upstreams) do
        local t = {}
        
        fetch_upstream_info(t, up.get_primary_peers(u), false)
        fetch_upstream_info(t, up.get_backup_peers(u), true)

        upstream[u] = {peers = t}

    end

    return upstream
end


local function get_server_zones()
    -- body
    local shared_status = ngx.shared.status

    local server_zone = shared_status:get( KEY_SERVER_ZONES )

    return common.json_decode(server_zone)
end


function _M.report()
    local report = {}
    -- Version of the provided data set. The current version is 1
    -- report.version = 1 

    ngx.header.content_type = "application/json"
    ngx.header.charset = "utf-8"

    report = get_nginx_info(report)
    report.connections = get_connections_info() or {}
    report.requests = get_requests_info() or {}
    report.upstreams = get_upstreams_info() or {}
    report.server_zones = get_server_zones() or {}

    ngx.say(common.json_encode(report))
end


return _M
