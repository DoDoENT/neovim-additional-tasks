local Path = require( 'plenary.path' )
local utils = require( 'tasks.utils' )

local function build( module_config, _ )
     return {
        cmd = 'zig',
        args = vim.list_extend({ 'build', '--verbose' }, utils.split_args(module_config.global_zig_args)),
        ignore_stdout = true,
      }
end

local function clean( _, _ )
    -- note: requires unix shell
     return {
        cmd = 'rm',
        args = { '-rf', 'zig-out' },
        ignore_stdout = true,
      }
end

return {
    params = {
        'dap_name',
        'global_zig_args'
    },
    condition = function() return Path:new( 'zig.build' ):exists() end,
    tasks = {
        build = build,
        clean = clean
    }
}
