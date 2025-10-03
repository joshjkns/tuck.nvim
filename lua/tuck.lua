-- tuck.nvim, the easiest way to surround selected text with a character, or swap to a different one.

local M = {}

local surround_pairs = {
  ['{'] = '}',
  ['('] = ')',
  ['['] = ']',
  ['<'] = '>',
  ['"'] = '"',
  ["'"] = "'",
  ['`'] = '`',
}

local function get_pair(left)
  return surround_pairs[left]
end

local function is_valid_surround(char)
  return surround_pairs[char] ~= nil
end

local function surround_visual(bufnr, line1, line2, left, right, mode)
  local lines = vim.api.nvim_buf_get_lines(bufnr, line1, line2 + 1, false)
  if #lines == 0 then return end

  if mode == 'line' then
    if #lines == 1 then
      lines[1] = left .. lines[1] .. right
    else
      lines[1] = left .. lines[1]
      lines[#lines] = lines[#lines] .. right
    end
  else
    local col1 = vim.fn.col("'<")
    local col2 = vim.fn.col("'>")
    if line1 == line2 then
      lines[1] = lines[1]:sub(1, col1 - 1) .. left .. lines[1]:sub(col1, col2) .. right .. lines[1]:sub(col2 + 1)
    else
      lines[1] = lines[1]:sub(1, col1 - 1) .. left .. lines[1]:sub(col1)
      lines[#lines] = lines[#lines]:sub(1, col2) .. right .. lines[#lines]:sub(col2 + 1)
    end
  end
  vim.api.nvim_buf_set_lines(bufnr, line1, line2 + 1, false, lines)
end

local function unsurround_visual(bufnr, line1, line2, left, right, mode)
  local lines = vim.api.nvim_buf_get_lines(bufnr, line1, line2 + 1, false)
  if #lines == 0 then return end

  if mode == 'line' then
    if #lines == 1 then
      if lines[1]:sub(1, 1) == left and lines[1]:sub(-1) == right then
        lines[1] = lines[1]:sub(2, -2)
        vim.api.nvim_buf_set_lines(bufnr, line1, line2 + 1, false, lines)
        return true
      end
    else
      if lines[1]:sub(1, 1) == left and lines[#lines]:sub(-1) == right then
        lines[1] = lines[1]:sub(2)
        lines[#lines] = lines[#lines]:sub(1, -2)
        vim.api.nvim_buf_set_lines(bufnr, line1, line2 + 1, false, lines)
        return true
      end
    end
  else
    local col1 = vim.fn.col("'<")
    local col2 = vim.fn.col("'>")
    if line1 == line2 then
      local first_char = lines[1]:sub(col1, col1)
      local last_char = lines[1]:sub(col2, col2)
      if first_char == left and last_char == right then
        lines[1] = lines[1]:sub(1, col1 - 1) .. lines[1]:sub(col1 + 1, col2 - 1) .. lines[1]:sub(col2 + 1)
        vim.api.nvim_buf_set_lines(bufnr, line1, line2 + 1, false, lines)
        return true
      end
    else
      local first_char = lines[1]:sub(col1, col1)
      local last_char = lines[#lines]:sub(col2, col2)
      if first_char == left and last_char == right then
        lines[1] = lines[1]:sub(1, col1 - 1) .. lines[1]:sub(col1 + 1)
        lines[#lines] = lines[#lines]:sub(1, col2 - 1) .. lines[#lines]:sub(col2 + 1)
        vim.api.nvim_buf_set_lines(bufnr, line1, line2 + 1, false, lines)
        return true
      end
    end
  end
  return false
end

local function swap_surround_visual(bufnr, line1, line2, old_left, old_right, new_left, new_right, mode)
  local lines = vim.api.nvim_buf_get_lines(bufnr, line1, line2 + 1, false)
  if #lines == 0 then return end

  if mode == 'line' then
    if #lines == 1 then
      if lines[1]:sub(1, 1) == old_left and lines[1]:sub(-1) == old_right then
        lines[1] = new_left .. lines[1]:sub(2, -2) .. new_right
        vim.api.nvim_buf_set_lines(bufnr, line1, line2 + 1, false, lines)
        return true
      end
    else
      if lines[1]:sub(1, 1) == old_left and lines[#lines]:sub(-1) == old_right then
        lines[1] = new_left .. lines[1]:sub(2)
        lines[#lines] = lines[#lines]:sub(1, -2) .. new_right
        vim.api.nvim_buf_set_lines(bufnr, line1, line2 + 1, false, lines)
        return true
      end
    end
  else
    local col1 = vim.fn.col("'<")
    local col2 = vim.fn.col("'>")
    if line1 == line2 then
      local first_char = lines[1]:sub(col1, col1)
      local last_char = lines[1]:sub(col2, col2)
      if first_char == old_left and last_char == old_right then
        lines[1] = lines[1]:sub(1, col1 - 1) .. new_left .. lines[1]:sub(col1 + 1, col2 - 1) .. new_right .. lines[1]:sub(col2 + 1)
        vim.api.nvim_buf_set_lines(bufnr, line1, line2 + 1, false, lines)
        return true
      end
    else
      local first_char = lines[1]:sub(col1, col1)
      local last_char = lines[#lines]:sub(col2, col2)
      if first_char == old_left and last_char == old_right then
        lines[1] = lines[1]:sub(1, col1 - 1) .. new_left .. lines[1]:sub(col1 + 1)
        lines[#lines] = lines[#lines]:sub(1, col2 - 1) .. new_right .. lines[#lines]:sub(col2 + 1)
        vim.api.nvim_buf_set_lines(bufnr, line1, line2 + 1, false, lines)
        return true
      end
    end
  end
  return false
end

-- :Tuck ('tucks' a string - adds a character surrounding the selected string)
function M.tuck_cmd(opts)
  local bufnr = vim.api.nvim_get_current_buf()
  
  local has_range = opts.range > 0
  
  if has_range then
    local vmode = vim.fn.visualmode()
    local line1 = opts.line1 - 1
    local line2 = opts.line2 - 1
    local left = opts.fargs[1]
    
    if left ~= "-s" and not is_valid_surround(left) then
      vim.notify("Invalid surround character: " .. left .. ". Valid options: { ( [ < \" ' `", vim.log.levels.ERROR)
      return
    end
    
    local right = get_pair(left)
    
    if vmode == 'V' then
      if left == "-s" then
        local new_left = opts.fargs[2]
        if not is_valid_surround(new_left) then
          vim.notify("Invalid surround character: " .. new_left .. ". Valid options: { ( [ < \" ' `", vim.log.levels.ERROR)
          return
        end
        local new_right = get_pair(new_left)
        for old_left, old_right in pairs(surround_pairs) do
          if swap_surround_visual(bufnr, line1, line2, old_left, old_right, new_left, new_right, 'line') then
            break
          end
        end
      else
        surround_visual(bufnr, line1, line2, left, right, 'line')
      end
    else
      if left == "-s" then
        local new_left = opts.fargs[2]
        if not is_valid_surround(new_left) then
          vim.notify("Invalid surround character: " .. new_left .. ". Valid options: { ( [ < \" ' `", vim.log.levels.ERROR)
          return
        end
        local new_right = get_pair(new_left)
        for old_left, old_right in pairs(surround_pairs) do
          if swap_surround_visual(bufnr, line1, line2, old_left, old_right, new_left, new_right, 'char') then
            break
          end
        end
      else
        surround_visual(bufnr, line1, line2, left, right, 'char')
      end
    end
  else
    local line = vim.api.nvim_get_current_line()
    local word = vim.fn.expand("<cword>")
    local s, e = line:find(word, 1, true)
    if s and e then
      local left = opts.fargs[1]
      
      if left ~= "-s" and not is_valid_surround(left) then
        vim.notify("Invalid surround character: " .. left .. ". Valid options: { ( [ < \" ' `", vim.log.levels.ERROR)
        return
      end
      
      local right = get_pair(left)
      if left == "-s" then
        local new_left = opts.fargs[2]
        if not is_valid_surround(new_left) then
          vim.notify("Invalid surround character: " .. new_left .. ". Valid options: { ( [ < \" ' `", vim.log.levels.ERROR)
          return
        end
        local new_right = get_pair(new_left)
        local old_left = line:sub(s - 1, s - 1)
        local old_right = line:sub(e + 1, e + 1)
        for ol, orr in pairs(surround_pairs) do
          if old_left == ol and old_right == orr then
            local new_line = line:sub(1, s - 2) .. new_left .. word .. new_right .. line:sub(e + 2)
            vim.api.nvim_set_current_line(new_line)
            return
          end
        end
      else
        local new_line = line:sub(1, s - 1) .. left .. word .. right .. line:sub(e + 1)
        vim.api.nvim_set_current_line(new_line)
      end
    end
  end
end

-- :Untuck  ('untucks' a string - removes the surrounding characters)
function M.untuck_cmd(opts)
  local bufnr = vim.api.nvim_get_current_buf()
  local has_range = opts.range > 0
  
  if has_range then
    local vmode = vim.fn.visualmode()
    local line1 = opts.line1 - 1
    local line2 = opts.line2 - 1
    
    if vmode == 'V' then
      for left, right in pairs(surround_pairs) do
        if unsurround_visual(bufnr, line1, line2, left, right, 'line') then
          break
        end
      end
    else
      for left, right in pairs(surround_pairs) do
        if unsurround_visual(bufnr, line1, line2, left, right, 'char') then
          break
        end
      end
    end
  else
    local line = vim.api.nvim_get_current_line()
    local word = vim.fn.expand("<cword>")
    local s, e = line:find(word, 1, true)
    if s and e then
      local left = line:sub(s - 1, s - 1)
      local right = line:sub(e + 1, e + 1)
      for ol, orr in pairs(surround_pairs) do
        if left == ol and right == orr then
          local new_line = line:sub(1, s - 2) .. word .. line:sub(e + 2)
          vim.api.nvim_set_current_line(new_line)
          return
        end
      end
    end
  end
end

vim.api.nvim_create_user_command("Tuck", M.tuck_cmd, { nargs = "+", range = true })
vim.api.nvim_create_user_command("Untuck", M.untuck_cmd, { range = true })

return M
