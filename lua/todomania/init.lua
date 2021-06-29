local T = {}
local buf, win
local todos = {}

-- local has_devicons, devicons = pcall(require, 'nvim-web-devicons')
local Job = require'plenary.job'

T.get_todos = function ()
    local on_output = function (_, line, _)
        print(line)
    end

    local cwd = vim.api.nvim_exec("!pwd", true)
    print(cwd)

    Job:new({
        command = 'rg',

        args = {'--color=never', "--no-heading",  "--with-filename","--column","--smart-case", "TODO"},

        -- cwd = '~/.config/nvim/',
        cwd = cwd,

        on_stderr = on_output,

        on_exit = function (j, _)
            local final_results = {}

            for _, value in ipairs(j['_stdout_results']) do
                local result = {}
                if value:find("[x]", 1, true) or value:find("[X]", 1, true) then
                    result["done"] = true
                elseif value:find("[]", 1, true) then
                    result["done"] = false
                else
                    goto continue
                end

                local flag = 0
                local filename = ""
                local remain_string = ""
                for c in value:gmatch"." do
                    if flag ==0 and c == ':' then
                        flag = 1
                        goto continue
                    end

                    if flag == 0 then
                        filename = filename..c
                    else
                        remain_string = remain_string..c
                    end
                    ::continue::
                end

                -- local content = string.match(remain_string, "[TODO:][A-Z0-9a-z].*[]]")
                local start_idx, _ = remain_string:find("TODO")
                local _, end_idx = remain_string:find("]")
                local content = string.sub(remain_string, start_idx, end_idx)
                -- print(remain_string)
                -- print(start_idx, ":", end_idx)
                -- print(content)

                local words = {}
                for w in (":"..remain_string):gmatch("([^:]*):") do
                    table.insert(words, w)
                end

                local line_number = words[2]
                local offset = words[3]

                result["file_name"] = filename
                result["line_number"] = line_number
                result["content"] = content
                result["offset"] = offset

                table.insert(final_results, result)
                ::continue::
            end

            print(vim.inspect(final_results))
            todos = final_results
            -- return final_results
        end
    }):sync()

    return todos
end

T.center = function(str)
  local width = vim.api.nvim_win_get_width(0)
  local shift = math.floor(width / 2) - math.floor(string.len(str) / 2)
  return string.rep(' ', shift) .. str
end

T.create_floating_buffer = function ()
    buf = vim.api.nvim_create_buf(false, true)
    local border_buf = vim.api.nvim_create_buf(false, true)

    vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
    vim.api.nvim_buf_set_option(buf, "filetype", "todos")

    local width = vim.api.nvim_get_option("columns")
    local height = vim.api.nvim_get_option("lines")

    local window_height = math.ceil(height * 0.4 - 4)
    local window_width = math.ceil(width * 0.8 - 4)
    local row = math.ceil((height - window_height) / 2 - 1)
    local col = math.ceil((width - window_width) / 2 - 1)

    local border_opts = {
        style = "minimal",
        relative = "editor",
        width = window_width + 2,
        height = window_height + 2,
        row = row - 1,
        col = col - 1
    }

    local opts = {
        style = "minimal",
        relative = "editor",
        width = window_width,
        height = window_height,
        row = row,
        col = col
    }

    local border_lines = { '╔' .. string.rep('═', window_width) .. '╗' }
    local middle_line = '║' .. string.rep(' ', window_width) .. '║'
    for _=1, window_height do
      table.insert(border_lines, middle_line)
    end
    table.insert(border_lines, '╚' .. string.rep('═', window_width) .. '╝')
    vim.api.nvim_buf_set_lines(border_buf, 0, -1, false, border_lines)

    local _ = vim.api.nvim_open_win(border_buf, true, border_opts)
    win = vim.api.nvim_open_win(buf, true, opts)
    vim.api.nvim_command('au BufWipeout <buffer> exe "silent bwipeout!"'..border_buf)

    vim.api.nvim_win_set_option(win, 'cursorline', true)

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { T.center('TODOs') })
    vim.api.nvim_buf_add_highlight(buf, -1, 'TodoHeader', 0, 0, -1)
end

T.populate_buffer = function ()

    -- if not devicons.has_loaded() then
      -- devicons.setup()
    -- end

    vim.api.nvim_buf_set_option(buf, 'modifiable', true)

    local todoStr = ""
    for _, val in ipairs(todos) do
        -- todoStr = todoStr .. val["file_name"] .. " : " .. val["content"] .. "\n"
        -- if has_devicons then
            -- local icon, icon_highlight = devicons.get_icon()
        -- end
        todoStr = todoStr .. val["content"] .. "\n"
    end

    vim.api.nvim_buf_set_lines(buf, 3, -1, false, vim.split(todoStr, "\n"))

    vim.api.nvim_buf_add_highlight(buf, -1, 'TodoSubHeader', 1, 0, -1)

    vim.api.nvim_buf_set_option(buf, 'modifiable', false)
end

T.close_window = function ()
 vim.api.nvim_win_close(win, true)
end

T.open_todo = function ()
    local selected_todo = vim.api.nvim_get_current_line()
    -- print(selected_todo)
    -- local line_number = tonumber(vim.api.nvim_exec('echo line(".")', true))
    -- print(line_number .. " : " .. str)
    T.close_window()
    -- print(line_number, line)

    for _, val in ipairs(todos) do
        -- print(val["content"] .. " : " .. selected_todo)
        if selected_todo == val["content"] then
            vim.api.nvim_command('edit ' .. val ["file_name"])
            break
        end
    end

    -- print(todos[line_number]["file_name"] .. ":" .. todos[line_number]["content"])
    -- vim.api.nvim_command('edit ' .. todos[line_number]["file_name"])
end

T.set_mappings = function ()
    local mappings = {
        ['<cr>'] = 'open_todo()',
        q = 'close_window()'
    }

    for k, v in pairs(mappings) do
        vim.api.nvim_buf_set_keymap(buf, 'n', k, ':lua require("todomania").'..v..'<cr>', {
            nowait = true, noremap = true, silent = true
        })
    end

    local other_chars = {
        'a', 'b', 'c', 'd', 'e', 'f', 'g', 'i', 'n', 'o', 'p', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z'
    }
    for _,v in ipairs(other_chars) do
      vim.api.nvim_buf_set_keymap(buf, 'n', v, '', { nowait = true, noremap = true, silent = true })
      vim.api.nvim_buf_set_keymap(buf, 'n', v:upper(), '', { nowait = true, noremap = true, silent = true })
      vim.api.nvim_buf_set_keymap(buf, 'n',  '<c-'..v..'>', '', { nowait = true, noremap = true, silent = true })
    end
end

-- vim.api.nvim_set_keymap('n', '<Space>td', '<cmd>lua require('todomania').play()', {})
-- vim.api.nvim_buf_set_keymap('n', '<Space>td', '<Cmd>lua require"todomania".play()', {noremap = true, silent = true})

-- TODO: Remove it [] something

T.init = function ()
    T.get_todos()
    T.create_floating_buffer()
    T.set_mappings()
    T.populate_buffer()
    vim.api.nvim_win_set_cursor(win, {4, 0})
end

return T
