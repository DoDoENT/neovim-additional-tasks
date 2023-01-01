local Path = require('plenary.path')
local ProjectConfig = require( 'tasks.project_config' )
local scandir = require( 'plenary.scandir' )
local utils = require( 'tasks.utils' )

-- Parses build directory expression
-- @param module_config table: cmake_kits module config object
-- @return table
local function getBuildDirFromConfig( module_config )
    local build_dir = module_config.build_dir
    local buildType = module_config.build_type
    local buildKit = module_config.build_kit
    local projectName = vim.fn.fnamemodify( '$PWD', ':p:h:t' )
    local home = os.getenv( 'HOME' )
    build_dir = build_dir:gsub( '{cwd}', vim.loop.cwd() )
    build_dir = build_dir:gsub( '{build_type}', buildType:lower() )
    build_dir = build_dir:gsub( '{build_kit}', buildKit:lower() )
    build_dir = build_dir:gsub( '{project_name}', projectName )
    build_dir = build_dir:gsub( '{home}', home )
    return Path:new( build_dir )
end

-- Returns the currently active CMake build directory
-- @return table
local function getBuildDir()
    local project_config = ProjectConfig:new()
    return getBuildDirFromConfig( project_config[ 'cmake_kits' ] )
end

-- Returns the object defining all CMake kits.
-- @param module_config table: cmake_kits module config object
-- @return table
local function getCMakeKitsFromConfig( module_config )
    local cmake_kits_path = module_config.cmake_kits_file
    if cmake_kits_path and Path:new( cmake_kits_path ):exists() then
        return vim.json.decode( Path:new( cmake_kits_path ):read() )
    else
        return {
            default = {
                generator = 'Ninja'
            }
        }
    end
end

-- Returns currently available CMake kits
-- @return table
local function getCMakeKits()
    local project_config = ProjectConfig:new()
    return getCMakeKitsFromConfig( project_config[ 'cmake_kits' ] )
end

-- Returns object defining all possible CMake build types with their configuration variables
-- @param module_config table: cmake_kits module config object
-- @return table
local function getCMakeBuildTypesFromConfig( module_config )
    local cmake_build_types_path = module_config.cmake_build_types_file
    if cmake_build_types_path and Path:new( cmake_build_types_path ):exists() then
        return vim.json.decode( Path:new( cmake_build_types_path ):read() )
    else
        return {
            [ 'Debug'          ] = { build_type = 'Debug'         },
            [ 'Release'        ] = { build_type = 'Release'       },
            [ 'RelWithDebInfo' ] = { build_type = 'RelWithDebInfo'},
            [ 'MinSizeRel'     ] = { build_type = 'MinSizeRel'    },
        }
    end
end

-- Returns currently available CMake build types
-- @return table
local function getCMakeBuildTypes()
    local project_config = ProjectConfig:new()
    return getCMakeBuildTypesFromConfig( project_config[ 'cmake_kits' ] )
end

-- Calculates the reply directory for CMake File API
-- @param build_dir table: a Path object representing path to CMake binary directory
-- @return table: Path object representing path to CMake File API reply directory
local function getReplyDir( build_dir ) return build_dir / '.cmake' / 'api' / 'v1' / 'reply' end
--
--- Reads information about target.
---@param codemodel_target table
---@param reply_dir table
---@return table
local function getTargetInfo( codemodel_target, reply_dir ) return vim.json.decode( ( reply_dir / codemodel_target['jsonFile'] ):read() ) end

--- Reads targets information.
---@param reply_dir table
---@return table?
local function getCodemodelTargets( reply_dir )
    local found_files = scandir.scan_dir( reply_dir.filename, { search_pattern = 'codemodel*' } )
    if #found_files == 0 then
        utils.notify( 'Unable to find codemodel file', vim.log.levels.ERROR )
        return nil
    end
    local codemodel = Path:new( found_files[ 1 ] )
    local codemodel_json = vim.json.decode( codemodel:read() )
    return codemodel_json[ 'configurations' ][ 1 ][ 'targets' ]
end

--- Finds path to an executable.
---@param build_dir table
---@param name string
---@param reply_dir table
---@return unknown?
local function getExecutablePath( build_dir, name, reply_dir )
    for _, target in ipairs( getCodemodelTargets( reply_dir ) ) do
        if name == target[ 'name' ] then
            local target_info = getTargetInfo( target, reply_dir )
            if target_info[ 'type' ] ~= 'EXECUTABLE' then
                utils.notify( string.format( 'Specified target "%s" is not an executable', name ), vim.log.levels.ERROR )
                return nil
            end

            local target_path = Path:new( target_info[ 'artifacts' ][ 1 ][ 'path' ] )
            if not target_path:is_absolute() then
                target_path = build_dir / target_path
            end

            return target_path
        end
    end

    utils.notify( string.format( 'Unable to find target named "%s"', name ), vim.log.levels.ERROR )
    return nil
end

-- Returns the currently active CMake target and path to it's executable
-- @return string, string
local function getCurrentTargetAndExePath()
    local cmake_config = ProjectConfig:new()[ 'cmake_kits' ]
    local build_dir = getBuildDir()
    local executablePath = getExecutablePath( build_dir, cmake_config.target, getReplyDir( build_dir ) )
    return cmake_config.target, tostring( executablePath )
end

-- Returns currently active clangd command line parameters (including path to clangd binary)
-- @return table: first element is path to clangd binary, and other elements are clangd command line arguments
local function currentClangdArgs()
    local module_config = ProjectConfig:new()[ 'cmake_kits' ]
    local cmakeKits = getCMakeKitsFromConfig( module_config )
    local buildKit = cmakeKits[ module_config.build_kit ]
    local clangdArgs = module_config.clangd_cmdline and module_config.clangd_cmdline or { 'clangd' }
    -- this can happen when someone manually sets the build_kit
    if not buildKit then
        vim.notify( 'Unknown build kit ' .. module_config.build_kit .. ' set. Cannot prepare clangd parameters!', vim.log.levels.ERROR )
        return clangdArgs
    end
    table.insert( clangdArgs, "--compile-commands-dir=" .. tostring( getBuildDirFromConfig( module_config ) ) )
    if buildKit.query_driver then
        table.insert( clangdArgs, '--query-driver=' .. buildKit.query_driver )
    end
    return clangdArgs
end

return {
    getBuildDir = getBuildDir,
    getBuildDirFromConfig = getBuildDirFromConfig,
    getExecutablePath = getExecutablePath,
    getCurrentTargetAndExePath = getCurrentTargetAndExePath,
    getReplyDir = getReplyDir,
    getCodemodelTargets = getCodemodelTargets,
    getTargetInfo = getTargetInfo,
    getCMakeKits = getCMakeKits,
    getCMakeKitsFromConfig = getCMakeKitsFromConfig,
    getCMakeBuildTypes = getCMakeBuildTypes,
    getCMakeBuildTypesFromConfig = getCMakeBuildTypesFromConfig,
    currentClangdArgs = currentClangdArgs,
}
