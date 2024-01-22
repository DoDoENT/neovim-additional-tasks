local Path = require( 'plenary.path' )

local function getSupportedProfiles()
    -- obtain list of profiles visible to conan
    local allProfiles = vim.fn.systemlist( 'conan profile list' )
    local profileList = {}
    -- filter only android and emscripten profiles, as they don't depend on local environment variables
    for _, profile in ipairs( allProfiles ) do
        if not string.find( profile, 'base' ) then
            if string.find( profile, 'android' ) or string.find( profile, 'emscripten' ) or ( string.find( profile, 'ninja' ) and not string.find( profile, 'generic' ) ) then
                table.insert( profileList, profile )
            end
        end
    end
    -- add iOS profiles on Mac
    if vim.fn.has( 'macunix' ) then
        table.insert( profileList, 'ios-device' )
        table.insert( profileList, 'ios-simulator' )
        table.insert( profileList, 'mac-catalyst' )
        table.insert( profileList, 'automatic-xcode' )
    end
    -- additionally, add automatic profile
    table.insert( profileList, 'automatic' )
    return profileList
end

local function getInstallDir( module_config )
    if module_config.install_dir then
        local home = os.getenv( 'HOME' )
        local install_dir = module_config.install_dir
        local profile = module_config.profile or 'automatic'
        local projectName = vim.fn.fnamemodify( '$PWD', ':p:h:t' )
        install_dir = install_dir:gsub( '{cwd}', vim.loop.cwd() )
        install_dir = install_dir:gsub( '{profile}', profile:lower() )
        install_dir = install_dir:gsub( '{project_name}', projectName )
        install_dir = install_dir:gsub( '{home}', home )
        return Path:new( install_dir )
    else
        return Path:new( vim.loop.cwd() )
    end
end

-- requires "conan project" custom command
local function project( module_config, _ )
    local cwd = module_config.working_directory or vim.loop.cwd()
    local buildDir = getInstallDir( module_config )
    local generator = 'ninja'
    local profile = module_config.profile or 'automatic'
    if vim.fn.has( 'macunix' ) then
        if profile == 'automatic-xcode' or profile == 'mac-catalyst' or string.find( profile, 'ios' ) then
            generator = 'ide'
        end
    end
    local args = { 'project', generator, '--install-only', '--build=missing', '--output-folder', buildDir.filename, '--host-generator', 'ninja', '--lockfile-partial' }
    local isAutomaticProfile = not not string.find( profile, 'automatic' )
    if vim.fn.has( 'macunix' ) then
        if profile == 'ios-device' then
            table.insert( args, '--ios=device' )
            isAutomaticProfile = true
        elseif profile == 'ios-simulator' then
            table.insert( args, '--ios=simulator' )
            isAutomaticProfile = true
        elseif profile == 'mac-catalyst' then
            table.insert( args, '--ios=maccatalyst' )
            isAutomaticProfile = true
        end
    end
    if not isAutomaticProfile then
        table.insert( args, '--profile=' .. profile )
    end
    return {
        cmd = 'conan',
        cwd = cwd,
        args = args,
    }
end

-- requires "conan project" custom command
local function updateLock( module_config, _ )
    local cwd = module_config.working_directory or vim.loop.cwd()
    return {
        cmd = 'conan',
        cwd = cwd,
        args = { 'project', 'lock' },
    }
end

return {
    params = {
        "working_directory",
        "install_dir",
        profile = getSupportedProfiles,
    },
    condition = function() return Path:new( 'conanfile.py' ):exists() or Path:new( 'conanfile.txt' ):exists() end,
    tasks = {
        project = project,
        lock = updateLock,
    }
}

