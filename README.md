neovim-additional-tasks
=========================

This plugin contains dditional tasks for [Shatur/neovim-tasks](https://github.com/Shatur/neovim-tasks). Following additional tasks are implemented:

- `npm` for managing NPM projects
- `cmake_kits` for advanced management of CMake-based projects, which has a lot more features than the `cmake` task provided in the original [Shatur/neovim-tasks](https://github.com/Shatur/neovim-tasks) plugin, such as support for build kits, customization of build types, integration with ctest, automatic reconfiguration of `clangd` LSP arguments, ...

Additinally, plugin also provides a lot of utility functions for CMake, available [here](https://github.com/DoDoENT/neovim-additional-tasks/blob/master/lua/tasks/cmake_kits_utils.lua), which can be used to expose some CMake state which is useful for configuring other plugins, for example CMake status bar with [nvim-lualine/lualine.nvim](https://github.com/nvim-lualine/lualine.nvim).

# Installation

Add following code to your packer configuration:

```lua
use {
    'DoDoENT/neovim-additional-tasks',
    requires = {
        { 'Shatur/neovim-tasks', requires = { 'nvim-lua/plenary.nvim' } },
        'neovim/nvim-lspconfig',
    }
}
```

Also, make sure that `clangd` LSP server is installed.

# Configuration

## CMake with kits

Use the following snippet to configure `neovim-tasks` plugin as, described in [plugin documentation](https://github.com/Shatur/neovim-tasks#configuration):

```lua
require('tasks').setup({
    default_params = { -- Default module parameters with which `.tasks.json` will be created.
        cmake_kits = {
            cmd = 'cmake', -- CMake executable to use, can be changed using `:Task set_module_param cmake cmd`.
            build_type = 'Release', -- default build type, can be changed using `:Task set_module_param cmake build_type`.
            build_kit = 'default',  -- default build kit, can be changed using `:Task set_module_param cmake build_kit`.
            dap_name = 'codelldb', -- DAP configuration name from `require('dap').configurations`. If there is no such configuration, a new one with this name as `type` will be created.
            build_dir = '{home}/builds/{project_name}/{build_kit}/{build_type}', -- placeholders will be automatically replaced: {home} with path to home directory, {project_name} with name of the current working directory, {build_kit} with currently active build kit and {build_type} with currently active build type
            cmake_kits_file = vim.api.nvim_get_runtime_file( 'cmake_kits.json', false )[ 1 ], -- set path to JSON file containing cmake kits
            cmake_build_types_file = vim.api.nvim_get_runtime_file( 'cmake_build_types.json', false )[ 1 ], -- set path to JSON file containing cmake kits
            clangd_cmdline = { 'clangd', '--background-index', '--clang-tidy', '--header-insertion=never', '--offset-encoding=utf-8', '--pch-storage=memory', '--cross-file-rename', '-j=4' }, -- command line for invoking clangd - this array will be extended with --compile-commands-dir and --query-driver after each cmake configure with parameters inferred from build_kit, build_type and build_dir
        }
    }
})
```

### CMake build types

You can define your custom build types in a JSON file, path to which needs to be specified in the `default_params` object as described above. An example JSON file with CMake build types looks like this:

```json
{
    "debug" : {
        "build_type" : "Debug",
        "cmake_usr_args" : {
            "MY_TREAT_WARNINGS_AS_ERRORS": "OFF"
        }
    },
    "dev-release": {
        "build_type" : "RelWithDebInfo",
        "cmake_usr_args": {
            "MY_TREAT_WARNINGS_AS_ERRORS": "ON"
        }
    },
    "release": {
        "build_type" : "Release",
        "cmake_usr_args": {
            "MY_TREAT_WARNINGS_AS_ERRORS": "ON"
        }
    }
}
```

The structure of the JSON is in the form:

```json
{
    "build_type_name": {
        "build_type": "this will be passed to -DCMAKE_BUILD_TYPE",
        "cmake_usr_args": { // optional, will be passed to cmake configure whenever build_type_name is active
            "cmake_variable1": "value1",
            "cmake_variable2": "value2",
            ...
        }
    },
    ...
}
```

This allows for custom cmake user arguments for each build type that will always be applied, regardless of currently selected CMake kit.

### Cmake build kits

You can define your custom build kits (or toolchains) in a JSON file, path to which needs to be specified in the `default_params` object as described above. An example JSON file with CMake kits looks like this:

```json
{
    "xcode-clang": {
        "compilers": {
            "C": "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/cc",
            "CXX": "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/c++"
        },
        "query_driver" : "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang++",
        "generator": "Xcode",
        "build_type_aware": false
    },
    "clang": {
        "compilers": {
            "C": "/usr/bin/clang",
            "CXX": "/usr/bin/clang++"
        },
        "query_driver" : "/usr/bin/clang++",
        "generator": "Ninja"
    },
    "clang-xcode-13.4.1": {
        "compilers": {
            "C": "/usr/bin/clang",
            "CXX": "/usr/bin/clang++"
        },
        "query_driver" : "/usr/bin/clang++",
        "environment_variables": {
            "DEVELOPER_DIR": "/Applications/xcode-versions/Xcode-13.4.1.app/Contents/Developer"
        },
        "generator": "Ninja"
    },
    "emscripten-3.1.17": {
        "toolchain_file": "~/.conan/data/emsdk_installer/3.1.17/microblink/stable/package/3c9d8fb1b383ce27cf8b0942dcbdbb6add8cbee9/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake",
        "environment_variables": {
            "EM_CONFIG": "/Users/dodo/.conan/data/emsdk_installer/3.1.17/microblink/stable/package/3c9d8fb1b383ce27cf8b0942dcbdbb6add8cbee9/.emscripten",
            "EM_CACHE": "/Users/dodo/.conan/data/emsdk_installer/3.1.17/microblink/stable/package/3c9d8fb1b383ce27cf8b0942dcbdbb6add8cbee9/.emscripten_cache"
        },
        "cmake_usr_args": {
            "MY_EMSCRIPTEN_EMRUN_BROWSER": "chrome",
            "MY_EMSCRIPTEN_EMRUN_SILENCE_TIMEOUT": "300",
            "MY_EMSCRIPTEN_EMRUN_SERVE_AFTER_CLOSE": "ON",
            "MY_EMSCRIPTEN_EMRUN_BROWSER_ARGS": "--remote-debugging-port=9622"
        },
        "query_driver" : "~/.conan/data/emsdk_installer/3.1.17/microblink/stable/package/3c9d8fb1b383ce27cf8b0942dcbdbb6add8cbee9/upstream/emscripten/em++",
        "generator": "Ninja"
    }
}
```

The structure of the JSON is in the form:

```json
{
    "build_kit_name": {
        "compilers": { // optional, if provided it will pass -DCMAKE_C_COMPILER and -DCMAKE_CXX_COMPILER to cmake during configuration, not needed when toolchain_file is provided or default compiler is used
            "C": "/path/to/c/compiler/to/be/used",
            "CXX": "/path/to/c++/compiler/to/be/used",
        },
        "toolchain_file": "/path/to/cmake/toolchain/file", // also optional, if provided, this will be passed to -DCMAKE_TOOLCHAIN_FILE
        "environment_variables": { // optional, if provided, given environment variables will be set for every invocation of any cmake task
            "VAR1": "value1",
            "VAR2": "value2",
            ...
        },
        "cmake_usr_args": { // optional, will be passed to cmake configure whenever build_kit_name is active
            "cmake_variable1": "value1",
            "cmake_variable2": "value2",
            ...
        },
        "query_driver": "/path/to/query_driver/compiler", // optional, if provied, it will be passed as --query-driver` parameter to clangd when build_kit_name is active
        "generator": "cmake-generator", // will be passed as -G option to cmake. If not provided, Ninja will be used. Keep in mind that not all generators support creating compile_commands.json file, which is needed for clangd to work. However, you can still use those generators for quickly creating CMake build directories (e.g. for Xcode)
        "build_type_aware": true|false, // optional, indicates whether generator is aware of CMAKE_BUILD_TYPE. For example, IDE generators need to have this set to false to prevent invoking cmake with -DCMAKE_BUILD_TYPE=active_build_type
    },
    ...
}
```

### Tasks

CMake with Kits task module will generate following tasks:

- `configure` - invokes cmake with parameters for currently active `build_kit` and `build_type`
- `build` - builds the currenly selected target
- `build_all` - builds all targets
- `run` - builds and then runs the currently selected target
- `debug` - builds and then starts `npm-dap` debug session for the currently selected target
- `clean` - cleans the build directory
- `ctest` - invokes `ctest`
- `purge` - deletes the cmake binary directory (unix only)
- `reconfigure` - equivalent to `purge` + `configure`


### CMake with Kits example

#### Example mappings

Here is convenient Lua code for configuring mapping for tasks generated by this plugin:

```lua
vim.keymap.set( "n", "<leader>cc", ':bo sp term://ccmake ' .. tostring( require( 'tasks.cmake_kits_utils' ).getBuildDir() ) .. '<cr>', { silent = true } )
vim.keymap.set( "n", "<leader>cC", [[:Task start cmake_kits configure<cr>]], { silent = true } )
vim.keymap.set( "n", "<leader>cP", [[:Task start cmake_kits reconfigure<cr>]], { silent = true } )
vim.keymap.set( "n", "<leader>cT", [[:Task start cmake_kits ctest<cr>]], { silent = true } )
vim.keymap.set( "n", "<leader>cv", [[:Task set_module_param cmake_kits build_type<cr>]], { silent = true } )
vim.keymap.set( "n", "<leader>ck", [[:Task set_module_param cmake_kits build_kit<cr>]], { silent = true } )
vim.keymap.set( "n", "<leader>cK", [[:Task start cmake_kits clean<cr>]], { silent = true } )
vim.keymap.set( "n", "<leader>ct", [[:Task set_module_param cmake_kits target<cr>]], { silent = true } )
vim.keymap.set( "n", "<C-c>", [[:Task cancel<cr>]], { silent = true } )
vim.keymap.set( "n", "<leader>cr", [[:Task start cmake_kits run<cr>]], { silent = true } )
vim.keymap.set( "n", "<F7>", [[:Task start cmake_kits debug<cr>]], { silent = true } )
vim.keymap.set( "n", "<leader>cb", [[:Task start cmake_kits build<cr>]], { silent = true } )
vim.keymap.set( "n", "<leader>cB", [[:Task start cmake_kits build_all<cr>]], { silent = true } )
```

#### Correct LSP `clangd` config on NeoVim startup

In order to correctly boot the `clangd` LSP on NeoVim startup, you can configure LSP to immediately use correct `clangd` arguments with following code:

```lua
require( 'lspconfig' )[ 'clangd' ].setup({
    cmd = require( 'tasks.cmake_kits_utils' ).currentClangdArgs(),
})
```

#### Active CMake kit, target and build type in [lualine](https://github.com/nvim-lualine/lualine.nvim) status

```lua
local Path = require('plenary.path')
local lualine = require( 'lualine' )
local ProjectConfig = require( 'tasks.project_config' )

local function cmakeStatus()
    local cmake_config = ProjectConfig:new()[ 'cmake_kits' ]
    local cmakelists_dir = cmake_config.source_dir and cmake_config.source_dir or vim.loop.cwd()
    if ( Path:new( cmakelists_dir ) / 'CMakeLists.txt' ):exists() then
        local cmakeBuildType = cmake_config.build_type
        local cmakeKit = cmake_config.build_kit
        local cmakeTarget = cmake_config.target and cmake_config.target or 'all'

        if cmakeBuildType and cmakeKit and cmakeTarget then
            return 'CMake variant: ' .. cmakeBuildType .. ' kit: ' .. cmakeKit .. ' target: ' .. cmakeTarget
        else
            return ''
        end
    else
        return ''
    end
end

lualine.setup({
    sections = {
        lualine_c = { { 'filename', path = 1 } },
        lualine_x = { 'encoding', 'fileformat', 'filetype', cmakeStatus }
    }
})
```


## NPM

Use the following snippet to configure `neovim-tasks` plugin as, described in [plugin documentation](https://github.com/Shatur/neovim-tasks#configuration):

```lua
require('tasks').setup({
    default_params = {
        npm = {
            working_directory = vim.loop.cwd() -- working directory in which NPM will be invoked
        },
    }
})
```

NPM task module will create `install` and `run` task subcommands.

### NPM Example

For example, imagine that your `package.json` contains lines like these:

```json
{
    "scripts": {
        "clean": "rimraf build dist",
        "lint": "eslint --ext ts -c .eslintrc.json src",
        "start": "NODE_PATH=$(pwd)/node_modules node $(pwd)/../core/scripts/https-serve.js dist",
        "rollup": "rollup -c rollup.config.js && cd dist && ln -sf ../test-data",
    }
}
```

You can map then those commands with code like this:

```lua
vim.keymap.set( "n", "<leader>ni", [[:Task start npm install<cr>]] )
vim.keymap.set( "n", "<leader>nl", [[:Task start npm run lint<cr>]] )
vim.keymap.set( "n", "<leader>nr", [[:Task start npm run rollup<cr>]] )
vim.keymap.set( "n", "<leader>ns", [[:Task start npm run clean<cr>]] )
vim.keymap.set( "n", "<leader>ns", [[:Task start npm run start<cr>]] )
```

