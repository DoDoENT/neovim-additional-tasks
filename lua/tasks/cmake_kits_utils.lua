local Path = require('plenary.path')
local ProjectConfig = require( 'tasks.project_config' )
local scandir = require( 'plenary.scandir' )
local utils = require( 'tasks.utils' )
local cmake_presets = require( 'tasks.cmake_presets' )

-- Returns true if presets should be used
-- @param module_config table: cmake_kits module config object or None - if not given, a global default will be used
-- @return boolean
local function shouldUsePresets( module_config )
    module_config = module_config or ProjectConfig:new()[ 'cmake_kits' ]
    if module_config.ignore_presets then
        return false
    else
        return cmake_presets.check()
    end
end


-- Parses build directory expression
-- @param module_config table: cmake_kits module config object
-- @return table
local function getBuildDirFromConfig( module_config )
    if shouldUsePresets( module_config ) and module_config.configure_preset then
        local currentPreset = cmake_presets.get_preset_by_name( module_config.configure_preset, 'configurePresets' )
        local buildDirForPreset = cmake_presets.get_build_dir( currentPreset )
        return Path:new( buildDirForPreset )
    else
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
    local cmakeConfig = ProjectConfig:new()[ 'cmake_kits' ]
    local buildDir = getBuildDirFromConfig( cmakeConfig )
    local executablePath = getExecutablePath( buildDir, cmakeConfig.target, getReplyDir( buildDir ) )
    return cmakeConfig.target, tostring( executablePath )
end

-- Returns currently active clangd command line parameters (including path to clangd binary)
-- @return table: first element is path to clangd binary, and other elements are clangd command line arguments
local function currentClangdArgs()
    local module_config = ProjectConfig:new()[ 'cmake_kits' ]
    local clangdArgs = module_config.clangd_cmdline and module_config.clangd_cmdline or { 'clangd' }

    table.insert( clangdArgs, "--compile-commands-dir=" .. tostring( getBuildDirFromConfig( module_config ) ) )

    if shouldUsePresets( module_config ) and module_config.configure_preset then
        -- TODO: detect query-driver from preset toolchain
    else
        local cmakeKits = getCMakeKitsFromConfig( module_config )
        local buildKit = cmakeKits[ module_config.build_kit ]
        -- this can happen when someone manually sets the build_kit
        if not buildKit then
            vim.notify( 'Unknown build kit ' .. module_config.build_kit .. ' set. Cannot prepare clangd parameters!', vim.log.levels.ERROR )
            return clangdArgs
        end
        if buildKit.query_driver then
            table.insert( clangdArgs, '--query-driver=' .. buildKit.query_driver )
        end
    end
    return clangdArgs
end

-- update query driver clangd flag and restart LSP
local function reconfigureClangd()
    local clangdArgs = currentClangdArgs()
    require( 'lspconfig' )[ 'clangd' ].setup({
        cmd = clangdArgs,
    })
    vim.api.nvim_command( 'LspRestart clangd' )
end

-- Returns only build presets that match currently active configure preset
-- @param module_config current module config or none (in that case global default will be used)
-- @return table: compatible build presets
local function getCompatibleBuildPresets( module_config )
    module_config = module_config or ProjectConfig:new()[ 'cmake_kits' ]
    if not module_config.configure_preset then
        utils.notify( 'Configure preset not selected.', vim.log.levels.ERROR )
        return nil
    end

    local buildPresets = cmake_presets.parse_name_mapped( 'buildPresets' )
    local compatiblePresets = {}

    for presetName, preset in pairs( buildPresets ) do
        if preset.configurePreset == module_config.configure_preset then
            compatiblePresets[ presetName ] = preset
        end
    end

    return compatiblePresets
end

local function autoselectBuildPresetForSameBuildType( projectConfig )
    projectConfig = projectConfig or ProjectConfig:new()
    local cmakeConfig = projectConfig[ 'cmake_kits' ]
    if not cmakeConfig.configure_preset or not cmakeConfig.build_preset then
        return
    end

    -- first detect build type of currently active build preset
    local currentBuildPreset = cmake_presets.get_preset_by_name( cmakeConfig.build_preset, 'buildPresets' )
    if not currentBuildPreset then
        return
    end
    local buildType = currentBuildPreset.configuration
    local compatibleBuildPresets = getCompatibleBuildPresets( cmakeConfig )
    if not compatibleBuildPresets then
        return
    end
    for presetName, preset in pairs( compatibleBuildPresets ) do
        if preset.configuration == buildType then
            cmakeConfig[ 'build_preset' ] = presetName
            projectConfig:write()
            return
        end
    end
end

local function autoselectConfigurePresetFromCurrentBuildPreset( projectConfig )
    projectConfig = projectConfig or ProjectConfig:new()
    local cmakeConfig = projectConfig[ 'cmake_kits' ]

    if not cmakeConfig.build_preset then
        return
    end

    local currentBuildPreset = cmake_presets.get_preset_by_name( cmakeConfig.build_preset, 'buildPresets' )
    if not currentBuildPreset then
        return
    end

    cmakeConfig[ 'configure_preset' ] = currentBuildPreset.configurePreset
    projectConfig:write()
end

return {
    autoselectBuildPresetForSameBuildType = autoselectBuildPresetForSameBuildType,
    autoselectConfigurePresetFromCurrentBuildPreset = autoselectConfigurePresetFromCurrentBuildPreset,
    currentClangdArgs = currentClangdArgs,
    getBuildDir = getBuildDir,
    getBuildDirFromConfig = getBuildDirFromConfig,
    getCMakeBuildTypes = getCMakeBuildTypes,
    getCMakeBuildTypesFromConfig = getCMakeBuildTypesFromConfig,
    getCMakeKits = getCMakeKits,
    getCMakeKitsFromConfig = getCMakeKitsFromConfig,
    getCodemodelTargets = getCodemodelTargets,
    getCompatibleBuildPresets = getCompatibleBuildPresets,
    getCurrentTargetAndExePath = getCurrentTargetAndExePath,
    getExecutablePath = getExecutablePath,
    getReplyDir = getReplyDir,
    getTargetInfo = getTargetInfo,
    reconfigureClangd = reconfigureClangd,
    shouldUsePresets = shouldUsePresets,
}
