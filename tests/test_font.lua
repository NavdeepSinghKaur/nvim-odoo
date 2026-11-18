local H = dofile("tests/helpers.lua")
local eq = MiniTest.expect.equality
local T = MiniTest.new_set()

local STYLES = { "Regular", "Bold", "Italic", "BoldItalic" }

--- A fake machine: a font source folder, a fake Windows user folder and fake Windows tools
--- (powershell.exe, reg.exe, wslpath) that log what they were asked to do.
local function machine()
  local root = H.tmpdir()
  for _, style in ipairs(STYLES) do
    H.write(root .. "/src/JetBrainsMonoNerdFontMono-" .. style .. ".ttf", { "font" })
  end
  vim.fn.mkdir(root .. "/win/Microsoft/Windows/Fonts", "p")
  local bin = root .. "/bin"
  local function tool(name, body)
    H.write(bin .. "/" .. name, { "#!/usr/bin/env bash", body })
    vim.fn.setfperm(bin .. "/" .. name, "rwxr-xr-x")
  end
  tool("powershell.exe", "printf '%s\\r\\n' 'C:\\Users\\me\\AppData\\Local'")
  tool("reg.exe", 'echo "$@" >> "' .. root .. '/reg.log"')
  -- -u: Windows to Linux path (C:\Windows\Fonts has no fonts here); -w: the reverse
  tool(
    "wslpath",
    'case "$1" in -u) case "$2" in *Windows*) echo "'
      .. root
      .. '/sys" ;; *) echo "'
      .. root
      .. '/win" ;; esac ;;'
      .. ' -w) echo "C:\\\\fonts\\\\$(basename "$2")" ;; esac'
  )
  return root, bin
end

local function run(root, bin, wsl, ...)
  local env = {
    HOME = root .. "/home",
    PATH = bin .. ":" .. vim.env.PATH,
    ODOO_NVIM_FONT_SOURCE = root .. "/src",
    ODOO_NVIM_FORCE_WSL = wsl,
  }
  local result = vim.system({ "scripts/install-font.sh", ... }, { text = true, env = env }):wait()
  return result.code, result.stdout
end

T["WSL: installs for the Windows user and registers the fonts"] = function()
  local root, bin = machine()
  local code, out = run(root, bin, "1")
  eq(code, 0)
  eq(out:find("WSL detected", 1, true) ~= nil, true)
  for _, style in ipairs(STYLES) do
    eq(
      vim.uv.fs_stat(root .. "/win/Microsoft/Windows/Fonts/JetBrainsMonoNerdFontMono-" .. style .. ".ttf") ~= nil,
      true
    )
  end
  local log = table.concat(vim.fn.readfile(root .. "/reg.log"), "\n")
  eq(log:find("JetBrainsMono Nerd Font Mono Bold Italic (TrueType)", 1, true) ~= nil, true)
  eq(log:find("HKCU", 1, true) ~= nil, true)
end

T["WSL: does nothing when a Nerd Font is already on Windows"] = function()
  local root, bin = machine()
  H.write(root .. "/win/Microsoft/Windows/Fonts/JetBrainsMonoNerdFontMono-Regular.ttf", { "font" })
  local code, out = run(root, bin, "1")
  eq(code, 0)
  eq(out:find("already installed on Windows", 1, true) ~= nil, true)
  eq(vim.uv.fs_stat(root .. "/reg.log"), nil)
end

T["WSL: --dry-run changes nothing"] = function()
  local root, bin = machine()
  local code, out = run(root, bin, "1", "--dry-run")
  eq(code, 0)
  eq(out:find("would install", 1, true) ~= nil, true)
  eq(vim.uv.fs_stat(root .. "/reg.log"), nil)
end

T["Linux: copies the font into ~/.local/share/fonts and never calls Windows tools"] = function()
  local root, bin = machine()
  local code, out = run(root, bin, "0")
  eq(code, 0)
  eq(out:find("WSL detected", 1, true), nil)
  eq(
    vim.uv.fs_stat(root .. "/home/.local/share/fonts/JetBrainsMonoNerd/JetBrainsMonoNerdFontMono-Regular.ttf") ~= nil,
    true
  )
  eq(vim.uv.fs_stat(root .. "/reg.log"), nil)
end

T["download: installs the font and removes the download folder"] = function()
  local root, bin = machine()
  -- fake curl writes the zip; fake unzip unpacks the four styles into the -d folder
  H.write(bin .. "/curl", {
    "#!/usr/bin/env bash",
    'while [ $# -gt 0 ]; do [ "$1" = -o ] && echo zip > "$2"; shift; done',
  })
  H.write(bin .. "/unzip", {
    "#!/usr/bin/env bash",
    'd=""; while [ $# -gt 0 ]; do [ "$1" = -d ] && d="$2"; shift; done',
    'mkdir -p "$d"; for s in '
      .. table.concat(STYLES, " ")
      .. '; do echo f > "$d/JetBrainsMonoNerdFontMono-$s.ttf"; done',
  })
  H.write(bin .. "/fc-list", { "#!/usr/bin/env bash", "exit 0" }) -- no Nerd Font on this machine
  for _, name in ipairs({ "curl", "unzip", "fc-list" }) do
    vim.fn.setfperm(bin .. "/" .. name, "rwxr-xr-x")
  end
  vim.fn.mkdir(root .. "/tmp", "p")
  local env =
    { HOME = root .. "/home", PATH = bin .. ":" .. vim.env.PATH, TMPDIR = root .. "/tmp", ODOO_NVIM_FORCE_WSL = "0" }
  local result = vim.system({ "scripts/install-font.sh" }, { text = true, env = env }):wait()
  eq(result.code, 0)
  eq(
    vim.uv.fs_stat(root .. "/home/.local/share/fonts/JetBrainsMonoNerd/JetBrainsMonoNerdFontMono-BoldItalic.ttf") ~= nil,
    true
  )
  eq(vim.fn.readdir(root .. "/tmp"), {})
end

return T
