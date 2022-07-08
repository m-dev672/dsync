#!/usr/bin/env lua

function parse(str)
    local result = {}

    for line in string.gmatch(str, '([^\n]+)') do
        if string.sub(line, #line - 7) == '.dsync:' then
            sskip = true
        elseif string.sub(line, #line) == ':' then
            directory = string.sub(line, 0, #line - 1)
            if string.sub(directory, #directory) ~= '/' then
                directory = directory..'/'
            end
            sskip = false
            skip = true
        elseif sskip == true or skip == true then
            skip = false
        else
            i = 0
            info = {}
            path = directory

            for item in string.gmatch(line, '([^%s]+)') do
                if i == 0 then
                    info['type'] = string.sub(item, 1, 1)
                elseif i == 4 then
                    info['size'] = item
                elseif i == 5 then
                    info['ts_m'] = item
                elseif i == 6 then
                    info['ts_d'] = item
                elseif i == 7 then
                    info['ts_t'] = item
                elseif i >= 8 then
                    path = path..item
                end
                i = i + 1
            end

            if info['type'] == "l" then
                i = 0
                for e in string.gmatch(path, '([^>]+)') do
                    if i == 0 then
                        path = string.sub(e, 1, #e - 1)
                    elseif i == 1 then
                        info['target'] = e
                    end
                    i = i + 1
                end
            end

            result[path] = info
        end
    end

    return result
end

if #arg < 2 then
    print('Too few argments')
    os.exit(1)
elseif #arg > 3 then
    print('Too much argments')
    os.exit(1)
end

if string.sub(arg[#arg - 1], #arg[#arg - 1]) ~= '/' then
    arg[#arg - 1] = arg[#arg - 1]..'/'
end

if string.sub(arg[#arg], #arg[#arg]) ~= '/' then
    arg[#arg] = arg[#arg]..'/'
end

i = 0
for e in string.gmatch(arg[#arg], '([^:]+)') do
    if i == 0 then
        remote_host = e
    elseif i == 1 then
        remote_path = e
    end
    i = i + 1
end

handle = io.popen('echo "'..arg[#arg]..'" | md5sum')
hash = string.sub(handle:read('*all'), 1, 32)
handle:close()

if os.execute('if [ -f "'..arg[#arg - 1]..'.dsync" ]; then exit 0; else exit 1; fi') then
    print('Please delete '..arg[#arg - 1]..'.dsync and restart.')
    os.exit(1)
elseif os.execute('if [ -d "'..arg[#arg - 1]..'.dsync" ]; then exit 0; else exit 1; fi') then
else
    os.execute('mkdir '..arg[#arg - 1]..'.dsync')
end

handle = io.popen('ls -RAl '..arg[#arg - 1])
result = handle:read('*all')
handle:close()

r2 = parse(result)

if os.execute('if [ -d "'..arg[#arg - 1]..'.dsync/'..hash..'" ]; then exit 0; else exit 1; fi') then
    print('Please delete '..arg[#arg - 1]..'.dsync/'..hash..'/ and restart.')
    os.exit(1)
elseif os.execute('if [ -f "'..arg[#arg - 1]..'.dsync/'..hash..'" ]; then exit 0; else exit 1; fi') then
    f = io.open(arg[#arg - 1]..'.dsync/'..hash, "r")
    local result = ""
    for line in f:lines() do
        result = result..line.."\n"
    end
    f:close()

    r1 = parse(result)

    changes = {}

    for path, info in pairs(r2) do
        if r1[path] == nil or 
           r1[path]["size"] ~= info["size"] or
           r1[path]["ts_m"] ~= info["ts_m"] or
           r1[path]["ts_d"] ~= info["ts_d"] or
           r1[path]["ts_t"] ~= info["ts_t"] then
            if info["type"] == "d" then
                if #arg == 3 then
                    os.execute("ssh "..arg[1].." "..remote_host.." mkdir -p "..remote_path..string.sub(path, #arg[2] + 1))
                else
                    os.execute("ssh "..remote_host.." mkdir -p "..remote_path..string.sub(path, #arg[1] + 1))
                end
            elseif info["type"] == "-" then
                if #arg == 3 then
                    os.execute("scp -p "..string.gsub(arg[1], "-p", "-P").." "..path.." "..arg[3]..string.sub(path, #arg[2] + 1))
                else
                    os.execute("scp -p "..path.." "..arg[2]..string.sub(path, #arg[1] + 1))
                end
            elseif info["type"] == "l" then
                if #arg == 3 then
                    os.execute("ssh "..arg[1].." "..remote_host.." ln -s "..remote_path..string.sub(info['target'], #arg[2] + 1).." "..remote_path..string.sub(path, #arg[2] + 1))
                else
                    os.execute("ssh "..remote_host.." ln -s "..remote_path..string.sub(info['target'], #arg[1] + 1).." "..remote_path..string.sub(path, #arg[1] + 1))
                end
            end
        end
    end

    for path, info in pairs(r1) do
        if r2[path] == nil then
            if #arg == 3 then
                os.execute("ssh "..arg[1].." "..remote_host.." rm -rf "..remote_path..string.sub(path, #arg[2] + 1))
            else
                os.execute("ssh "..remote_host.." rm -rf "..remote_path..string.sub(path, #arg[1] + 1))
            end
        end
    end
else
    if #arg == 3 then
        os.execute("scp -rp "..string.gsub(arg[1], "-p", "-P").." "..arg[2].." "..arg[3])
    else
        os.execute("scp -rp "..arg[1].." "..arg[2])
    end
end

f = io.open(arg[#arg - 1]..'.dsync/'..hash, "w")
f:write(result)