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

local function getNpmRunSubcommands()
    local module_config = ProjectConfig:new()[ 'npm' ]
    local cwd = module_config.working_directory and module_config.working_directory or vim.loop.cwd()

    local job = Job:new({
        command = 'npm',
        args = { 'run', '--list', '--json' },
        enabled_recording = true,
        cwd = cwd,
    })
    job:sync()

    if job.code ~= 0 or job.signal ~= 0 then
        utils.notify( 'Unable to get list of available cargo subcommands', vim.log.levels.ERROR )
        return {}
    end

    local npm_run_subcommands = {}
    local string_result = ''
    for _, line in ipairs( job:result() ) do
        string_result = string_result .. line
    end
    local run_subcommands = vim.json.decode( string_result )

    for subcommand, _ in pairs( run_subcommands ) do
        npm_run_subcommands[ 'run-' .. subcommand ] = function( _, _ )
            return {
                cmd = 'npm',
                args = { 'run', subcommand },
                cwd = cwd,
                -- TODO: add errorformat here if needed
            }
        end
    end

    return npm_run_subcommands
end

return {
    params = {
        "working_directory"
    },
    condition = function() return Path:new( 'package.json' ):exists() end,
    tasks = vim.tbl_extend( 'force', getNpmRunSubcommands(), { install = install } )
}
