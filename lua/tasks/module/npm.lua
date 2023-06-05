local Path = require( 'plenary.path' )

local function install( module_config, _ )
    local cwd = module_config.working_directory or vim.loop.cwd()
    return {
        cmd = 'npm',
        cwd = cwd,
        args = { 'install' }
    }
end

local function run( module_config, _ )
    local cwd = module_config.working_directory or vim.loop.cwd()
    return {
        cmd = 'npm',
        cwd = cwd,
        args = { 'run' }
    }
end

return {
    params = {
        "working_directory"
    },
    condition = function() return Path:new( 'package.json' ):exists() end,
    tasks = {
        install = install,
        run = run,
    }
}
