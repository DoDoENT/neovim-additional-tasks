local Path = require( 'plenary.path' )
local utils = require( 'tasks.utils' )

local build_type_map = {
    Debug = 'off',
    ReleaseSafe = 'safe',
    ReleaseSmall = 'small',
    ReleaseFast = 'fast',
}

local function build( module_config, _ )
    local build_target = module_config.build_step
    local build_type = build_type_map[module_config.build_type]
    return {
        cmd = 'zig',
        args = { 'build', build_target, '--release=' .. build_type }
      }
end

local function clean( _, _ )
    -- note: requires unix shell
     return {
        cmd = 'rm',
        args = { '-rf', 'zig-out' },
     }
end

local function clean_cache( _, _ )
    -- note: requires unix shell
     return {
        cmd = 'rm',
        args = { '-rf', '.zig-cache' },
     }
end

local function run_file( module_config, _ )
    local currentSource = vim.fn.expand( '%' )
     return {
        cmd = 'zig',
        args = { 'run', '-O' .. module_config.build_type, currentSource, '--' }
      }
end

local function build_test_file(module_config, _)
    local currentSource = vim.fn.expand('%')
    local srcFilename = vim.fn.fnamemodify(currentSource, ':t:r')
    return {
        cmd = 'zig',
        args = { 'test', currentSource, '-femit-bin=.zig-cache/test-' .. srcFilename, '--test-no-exec', '-O' .. module_config.build_type },
    }
end

local function debug_test_file(module_config, _)
    local currentSource = vim.fn.expand('%')
    local srcFilename = vim.fn.fnamemodify(currentSource, ':t:r')
    return {
        cmd = '.zig-cache/test-' .. srcFilename,
        dap_name = module_config.dap_name
    }

end

local function test( module_config, _ )
    local currentSource = vim.fn.expand( '%' )
     return {
        cmd = 'zig',
        args = vim.list_extend({ 'test', currentSource }, utils.split_args(module_config.global_zig_args)),
      }
end

local function build_file_as_exe( module_config, _ )
    local currentSource = vim.fn.expand('%')
    local srcFilename = vim.fn.fnamemodify(currentSource, ':t:r')
     return {
        cmd = 'zig',
        args = { 'build-exe', currentSource, '-femit-bin=.zig-cache/run-' .. srcFilename, '-O' .. module_config.build_type },
      }
end

local function debug_file( module_config, _ )
    local currentSource = vim.fn.expand('%')
    local srcFilename = vim.fn.fnamemodify(currentSource, ':t:r')
     return {
        cmd = '.zig-cache/run-' .. srcFilename,
        dap_name = module_config.dap_name,
      }
end

local function get_build_steps()
    local allSteps = vim.fn.systemlist( 'zig build --list-steps' )
    local stepNames = {}
    for _, step in ipairs( allSteps ) do
        local firstWord = string.gmatch( step, "%w+" )()
        table.insert( stepNames, firstWord )
    end
    return stepNames
end

return {
    params = {
        'dap_name',
        build_type = { 'Debug', 'ReleaseSafe', 'ReleaseFast', 'ReleaseSmall' },
        build_step = get_build_steps,
    },
    condition = function() return Path:new( 'zig.build' ):exists() end,
    tasks = {
        build = build,
        clean = clean,
        clean_cache = clean_cache,
        clean_all = { clean, clean_cache },
        run_file = run_file,
        debug_file = { build_file_as_exe, debug_file },
        test_file = test,
        debug_test_file = { build_test_file, debug_test_file },
    }
}
