local Path = require( 'plenary.path' )
local utils = require( 'tasks.utils' )

local function build_project( module_config, _ )
     return {
        cmd = 'zig',
        args = vim.list_extend({ 'build' }, utils.split_args(module_config.global_zig_args))
      }
end

local function debug_project( module_config, _ )
     return {
        cmd = 'zig',
        args = vim.list_extend({ 'build', 'run' }, utils.split_args(module_config.global_zig_args)),
        dap_name = module_config.dap_name,
      }
end

local function clean( _, _ )
    -- note: requires unix shell
     return {
        cmd = 'rm',
        args = { '-rf', 'zig-out' },
      }
end

local function run_file( module_config, _ )
    local currentSource = vim.fn.expand( '%' )
     return {
        cmd = 'zig',
        args = vim.list_extend({ 'run', currentSource }, utils.split_args(module_config.global_zig_args)),
      }
end

local function test( module_config, _ )
    local currentSource = vim.fn.expand( '%' )
     return {
        cmd = 'zig',
        args = vim.list_extend({ 'test', currentSource }, utils.split_args(module_config.global_zig_args)),
      }
end

local function debug( module_config, _ )
    local command = run_file( module_config, nil )
    if not command then
        return nil
    end

    command.dap_name = module_config.dap_name
    return command
end

return {
    params = {
        'dap_name',
        'global_zig_args'
    },
    condition = function() return Path:new( 'zig.build' ):exists() end,
    tasks = {
        build = build_project,
        debug = debug_project,
        clean = clean,
        run_file = run_file,
        debug_file = { run_file, debug },
        test_file = test,
    }
}
