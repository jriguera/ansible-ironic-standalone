-- -*- coding: utf-8 -*-
local JSON = require "JSON"
JSON.strictTypes = true
JSON.decodeNumbersAsObjects = true
JSON.noKeyConversion = true

local registry_base_uri = "/metadata/"
local request_base_uri = "/registry/"


-- functions
local function bad_request(msg)
    local logmsg = string.format("Sending BAD_REQUEST to client (status=%d): %s", ngx.HTTP_BAD_REQUEST, msg)
    ngx.log(ngx.NOTICE, logmsg)
    ngx.status = ngx.HTTP_BAD_REQUEST
    ngx.say(msg)
    ngx.exit(ngx.HTTP_OK)
end


local function do_not_found(id)
    ngx.log(ngx.NOTICE, "Sending NOT_FOUND to client (status=%d): %s", ngx.HTTP_NOT_FOUND, id)
    ngx.status = ngx.HTTP_NOT_FOUND
    msg = string.format("Id '%s' not found", id)
    ngx.say(msg)
    ngx.exit(ngx.HTTP_OK)
end


local function do_not_allowed(msg)
    local logmsg = string.format("Sending NOT_ALLOWED to client (status=%d): %s", ngx.HTTP_NOT_ALLOWED, msg)
    ngx.log(ngx.NOTICE, logmsg)
    ngx.status = ngx.HTTP_NOT_ALLOWED
    ngx.say(msg)
    ngx.exit(ngx.HTTP_OK)
end


local function do_conflict(id)
    local logmsg = string.format("Sending CONFLICT to client (status=%d): %s", ngx.HTTP_CONFLICT, msg)
    ngx.log(ngx.NOTICE, logmsg)
    ngx.status = ngx.HTTP_CONFLICT
    msg = string.format("Id '%s' already exists", id)
    ngx.say(msg)
    ngx.exit(ngx.HTTP_OK)
end


local function check(id)
    local logmsg = string.format("Checking if id=%s exists", id)
    ngx.log(ngx.NOTICE, logmsg)
    local res = ngx.location.capture(registry_base_uri .. id .. "/", { method = ngx.HTTP_HEAD })
    if res.status == 200 then
        logmsg = string.format("Found id=%s in %s (status=%s).", id, registry_base_uri, res.status)
        ngx.log(ngx.NOTICE, logmsg)
        return true
    else
        logmsg = string.format("Not found id=%s in %s (status=%s).", id, registry_base_uri, res.status)
        ngx.log(ngx.NOTICE, logmsg)
        return false
    end
end


local function do_head(id)
    local logmsg = string.format("Registry  HEAD for id=%s", id)
    ngx.log(ngx.NOTICE, logmsg)
    if check(id) then
        ngx.status = ngx.HTTP_OK
    else
        ngx.status = ngx.HTTP_NOT_FOUND
    end
    ngx.exit(ngx.HTTP_OK)
end


local function do_post(id)
    -- Creates ID (but no settings)
    local logmsg = string.format("Registry POST for id=%s", id)
    ngx.log(ngx.NOTICE, logmsg)
    if not check(id) then
        local res = ngx.location.capture(registry_base_uri .. id .. "/", { method = ngx.HTTP_MKCOL })
        logmsg = string.format("Registry POST for id=%s. Done (status=%s)", id, res.status)
        ngx.log(ngx.NOTICE, logmsg)
        ngx.status = res.status
        ngx.say(res.body)
        ngx.exit(ngx.HTTP_OK)
    else
        -- 409 Conflict
        do_conflict(id)
    end
end


local function do_delete(id, param)
    -- Delete ID and/or settings
    local logmsg = string.format("Registry DELETE for id=%s, params='%s'", id, param)
    ngx.log(ngx.NOTICE, logmsg)
    if check(id) then
        local resource = '/'
        if param ~= '' then
            resource = resource .. param
        end
        local res = ngx.location.capture(registry_base_uri .. id .. resource, { method = ngx.HTTP_DELETE })
        logmsg = string.format("Registry DELETE for id=%s '%s' (status=%s)", id, resource, res.status)
        ngx.log(ngx.NOTICE, logmsg)
        ngx.status = res.status
        ngx.say(res.body)
        ngx.exit(ngx.HTTP_OK)
    else
        -- 404 Id not found
        do_not_found(id)
    end
end


local function do_get(id, param)
    -- Get settings. No file, returns error json
    local logmsg = string.format("Registry GET for id=%s, params='%s'", id, param)
    ngx.log(ngx.NOTICE, logmsg)
    if check(id) and (param == "settings") then
        -- Get the settings from the metadata service
        local settings_value
        local status_value
        local res = ngx.location.capture(registry_base_uri .. id .. "/settings")
        if res.status == 200 then
            status_value = "ok"
            -- Content has to be a string, not JSON
            -- settings_value = JSON:decode(res.body)
            settings_value = res.body
        else
            status_value = "error"
            settings_value = {}
        end
        local output = { settings = settings_value, status = status_value }
        -- local result = JSON:encode_pretty(output)
        local result = JSON:encode(output, nil, { pretty = true, indent = "  ", null = nil })
        logmsg = string.format("Registry GET for id=%s. Done (status=%s)", id, res.status)
        ngx.log(ngx.NOTICE, logmsg)
        ngx.status = res.status
        ngx.say(result)
        ngx.exit(ngx.HTTP_OK)
    else
        -- 404 Id not found
        do_not_found(id)
    end
end


local function do_put(id, param)
    -- Put/Update settings
    local logmsg = string.format("Registry PUT for id=%s, params='%s'", id, param)
    ngx.log(ngx.NOTICE, logmsg)
    local exists = check(id)
    -- To make it compatible with
    -- https://github.com/cloudfoundry/bosh/blob/master/bosh_cpi/lib/bosh/cpi/registry_client.rb
    -- it has to accept put
    if ((not exists) and (param == "settings")) then
        local res = ngx.location.capture(registry_base_uri .. id .. "/", { method = ngx.HTTP_MKCOL })
        logmsg = string.format("Registry POST for id=%s. Done (status=%s)", id, res.status)
        ngx.log(ngx.NOTICE, logmsg)
    end
    if (param == "settings") then
        -- Internal Redirect with the content to metadata
        logmsg = string.format("Redirecting PUT: %s", registry_base_uri .. id .. "/settings")
        ngx.log(ngx.NOTICE, logmsg)
        ngx.exec(registry_base_uri .. id .. "/settings")
    else
        -- 404 Id not found
        do_not_found(id)
    end
end


-- Get the ID of the request
local method_name = ngx.req.get_method()
local regex = "^" .. request_base_uri .. "instances/([\\w-]+)/?(.*)?"
local params, err = ngx.re.match(ngx.var.uri, regex)
if params then
    -- Check request method type
    local id = params[1]
    local param = params[2]
    if method_name == "GET" then
        -- Get settings
        if param == '' then
            param = 'settings'
        end
        do_get(id, param)
    elseif method_name == "DELETE" then
        -- Delete ID and/or settings
        do_delete(id, param)
    elseif method_name == "PUT" then
        -- Update settings
        if param == '' then
            param = 'settings'
        end
        do_put(id, param)
    elseif method_name == "HEAD" then
        -- Check if it exists
        do_head(id)
    elseif method_name == "POST" then
        -- Create id
        do_post(id)
    else
        do_not_allowed("Method not allowed. Please, see bosh documentation")
    end
else
    bad_request("Error parsing URI")
end

