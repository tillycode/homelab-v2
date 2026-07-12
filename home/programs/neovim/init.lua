vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.ignorecase = true
vim.opt.smartcase = true

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Set clipboard after startup so nvim doesn't block on the clipboard provider
vim.schedule(function()
  vim.opt.clipboard = "unnamedplus"
end)

vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")

if vim.g.vscode then
  local vscode = require("vscode")
  local function action(name)
    return function()
      vscode.action(name)
    end
  end
  vim.keymap.set({ "n", "x" }, "gA", action("editor.action.goToReferences"))
  vim.keymap.set({ "n", "x" }, "gI", action("editor.action.goToImplementation"))
  vim.keymap.set({ "n", "x" }, "gH", action("editor.showTypeHierarchy"))
  vim.keymap.set("n", "zM", action("editor.foldAll"))
  vim.keymap.set("n", "zR", action("editor.unfoldAll"))
  vim.keymap.set("n", "zc", action("editor.fold"))
  vim.keymap.set("n", "zC", action("editor.foldRecursively"))
  vim.keymap.set("n", "zo", action("editor.unfold"))
  vim.keymap.set("n", "zO", action("editor.unfoldRecursively"))
  vim.keymap.set("n", "za", action("editor.toggleFold"))
  vim.notify = vscode.notify
  vim.g.miniindentscope_disable = true
end

vim.api.nvim_create_autocmd("TextYankPost", {
  desc = "Highlight when yanking (copying) text",
  group = vim.api.nvim_create_augroup("highlight-yank", { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})

require("mini.ai").setup()
require("mini.surround").setup({
  mappings = {
    add = "",
    delete = "ds",
    find = "",
    find_left = "",
    highlight = "",
    replace = "cs",
    update_n_lines = "",
  },
})
require("mini.indentscope").setup()

vim.keymap.set({ "n", "o", "x" }, "<Leader>w", function()
  require("spider").motion("w")
end)
vim.keymap.set({ "n", "o", "x" }, "<Leader>e", function()
  require("spider").motion("e")
end)
vim.keymap.set({ "n", "o", "x" }, "<Leader>b", function()
  require("spider").motion("b")
end)
