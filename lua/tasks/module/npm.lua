local Job = require( 'plenary.job' )
local Path = require( 'plenary.path' )
local ProjectConfig = require( 'tasks.project_config' )
local utils = require( 'tasks.utils' )

local function install( module_config, _ )
    local cwd = module_config.working_directory and module_config.working_directory or vim.loop.cwd()
    return {
        cmd = 'npm',
        cwd = cwd,
        args = { 'install' }
    }
end

local function run( module_config, _ )
    local cwd = module_config.working_directory and module_config.working_directory or vim.loop.cwd()
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
