.pragma library

// Curated apps. `p` is the package name, `a: true` marks an AUR package.
// Entries whose package is missing from the repositories of this machine
// (for example x86-only apps on ARM) are hidden automatically.
var categories = ["Browsers", "Development", "Media", "Graphics", "Office", "Communication", "Utilities", "Games", "AI"]

var apps = [
  { n: "Firefox", p: "firefox", c: "Browsers", d: "Fast, private and safe web browser" },
  { n: "Chromium", p: "chromium", c: "Browsers", d: "Open-source browser project behind Chrome" },
  { n: "Zen Browser", p: "zen-browser-bin", a: true, c: "Browsers", d: "Calm, privacy-focused Firefox-based browser" },
  { n: "Brave", p: "brave-bin", a: true, c: "Browsers", d: "Browser with built-in ad and tracker blocking" },
  { n: "qutebrowser", p: "qutebrowser", c: "Browsers", d: "Keyboard-driven, vim-like browser" },

  { n: "Neovim", p: "neovim", c: "Development", d: "Hyperextensible Vim-based text editor" },
  { n: "Zed", p: "zed", c: "Development", d: "High-performance multiplayer code editor" },
  { n: "Helix", p: "helix", c: "Development", d: "Modal editor with built-in language support" },
  { n: "VS Code", p: "visual-studio-code-bin", a: true, c: "Development", d: "Microsoft's code editor" },
  { n: "Lazygit", p: "lazygit", c: "Development", d: "Simple terminal UI for git commands" },
  { n: "GitHub CLI", p: "github-cli", c: "Development", d: "GitHub on the command line" },
  { n: "Docker", p: "docker", c: "Development", d: "Container runtime and tooling" },
  { n: "Podman", p: "podman", c: "Development", d: "Daemonless container engine" },
  { n: "DBeaver", p: "dbeaver", c: "Development", d: "Universal database tool" },
  { n: "Meld", p: "meld", c: "Development", d: "Visual diff and merge tool" },
  { n: "Godot", p: "godot", c: "Development", d: "Open-source 2D and 3D game engine" },

  { n: "VLC", p: "vlc", c: "Media", d: "Plays practically any media file" },
  { n: "mpv", p: "mpv", c: "Media", d: "Minimal, powerful video player" },
  { n: "OBS Studio", p: "obs-studio", c: "Media", d: "Streaming and screen recording" },
  { n: "Audacity", p: "audacity", c: "Media", d: "Record and edit audio" },
  { n: "Kdenlive", p: "kdenlive", c: "Media", d: "Non-linear video editor" },
  { n: "HandBrake", p: "handbrake", c: "Media", d: "Video transcoder" },
  { n: "Strawberry", p: "strawberry", c: "Media", d: "Music player and collection organizer" },
  { n: "EasyEffects", p: "easyeffects", c: "Media", d: "Audio effects for PipeWire" },

  { n: "GIMP", p: "gimp", c: "Graphics", d: "GNU image manipulation program" },
  { n: "Inkscape", p: "inkscape", c: "Graphics", d: "Professional vector graphics editor" },
  { n: "Krita", p: "krita", c: "Graphics", d: "Digital painting and illustration" },
  { n: "Blender", p: "blender", c: "Graphics", d: "3D creation suite" },
  { n: "Darktable", p: "darktable", c: "Graphics", d: "Photography workflow and RAW developer" },
  { n: "Pinta", p: "pinta", c: "Graphics", d: "Simple drawing and image editing" },

  { n: "LibreOffice", p: "libreoffice-fresh", c: "Office", d: "Full office suite" },
  { n: "Obsidian", p: "obsidian", c: "Office", d: "Knowledge base on local Markdown files" },
  { n: "Thunderbird", p: "thunderbird", c: "Office", d: "Email, calendar and news client" },
  { n: "Okular", p: "okular", c: "Office", d: "Universal document viewer" },
  { n: "Zathura", p: "zathura", c: "Office", d: "Minimal, keyboard-driven document viewer" },
  { n: "Calibre", p: "calibre", c: "Office", d: "E-book manager and converter" },
  { n: "Xournal++", p: "xournalpp", c: "Office", d: "Handwritten notes and PDF annotation" },

  { n: "Telegram", p: "telegram-desktop", c: "Communication", d: "Official Telegram desktop client" },
  { n: "Signal", p: "signal-desktop", c: "Communication", d: "Private messaging" },
  { n: "Element", p: "element-desktop", c: "Communication", d: "Matrix client" },
  { n: "Discord", p: "discord", c: "Communication", d: "Voice, video and text chat" },
  { n: "Slack", p: "slack-desktop", a: true, c: "Communication", d: "Team chat" },
  { n: "WeeChat", p: "weechat", c: "Communication", d: "Extensible IRC client for the terminal" },

  { n: "btop", p: "btop", c: "Utilities", d: "Resource monitor for the terminal" },
  { n: "KeePassXC", p: "keepassxc", c: "Utilities", d: "Offline password manager" },
  { n: "Bitwarden", p: "bitwarden", c: "Utilities", d: "Password manager" },
  { n: "qBittorrent", p: "qbittorrent", c: "Utilities", d: "BitTorrent client" },
  { n: "Syncthing", p: "syncthing", c: "Utilities", d: "Continuous file synchronization" },
  { n: "KDE Connect", p: "kdeconnect", c: "Utilities", d: "Connect your phone and desktop" },
  { n: "GParted", p: "gparted", c: "Utilities", d: "Partition editor" },
  { n: "FileZilla", p: "filezilla", c: "Utilities", d: "FTP and SFTP client" },
  { n: "Flameshot", p: "flameshot", c: "Utilities", d: "Screenshot tool with annotations" },

  { n: "Steam", p: "steam", c: "Games", d: "Valve's game platform" },
  { n: "Lutris", p: "lutris", c: "Games", d: "Open gaming platform" },
  { n: "RetroArch", p: "retroarch", c: "Games", d: "Frontend for emulators and game engines" },
  { n: "Prism Launcher", p: "prismlauncher", c: "Games", d: "Minecraft launcher with multiple instances" },
  { n: "SuperTuxKart", p: "supertuxkart", c: "Games", d: "Open-source kart racing" },
  { n: "OpenTTD", p: "openttd", c: "Games", d: "Transport tycoon simulation" },

  { n: "Ollama", p: "ollama", c: "AI", d: "Run large language models locally" },
  { n: "Claude Code", p: "claude-code", a: true, c: "AI", d: "Anthropic's coding agent for the terminal" }
]

// Starter packs for the Bundles tab. `apps` lists package names from the catalog
// above. Packages the repositories of this machine do not have are skipped.
var bundles = [
  { id: "dev", n: "Dev setup", apps: ["neovim", "helix", "lazygit", "github-cli", "docker", "meld", "btop"] },
  { id: "creative", n: "Creative", apps: ["gimp", "inkscape", "krita", "blender", "darktable", "kdenlive", "audacity"] },
  { id: "media", n: "Media center", apps: ["vlc", "mpv", "strawberry", "easyeffects", "obs-studio", "handbrake"] },
  { id: "office", n: "Office", apps: ["libreoffice-fresh", "obsidian", "thunderbird", "okular", "xournalpp", "calibre"] },
  { id: "privacy", n: "Privacy", apps: ["keepassxc", "signal-desktop", "syncthing", "bitwarden"] },
  { id: "gaming", n: "Gaming", apps: ["steam", "lutris", "retroarch", "prismlauncher", "supertuxkart", "openttd"] }
]
