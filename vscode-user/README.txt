This settings directory actually lives on macOS at:

    ~/Library/Application Support/Code/User

To back up the config, periodically copy the file to ~/dotfiles/vscode-user:

    cp -R ~/Library/Application\ Support/Code/User/* ~/dotfiles/vscode-user

Installed extensions:

    code --list-extensions | sort | pbcopy

AlanWalk.markdown-toc
DavidAnson.vscode-markdownlint
EditorConfig.EditorConfig
GitHub.vscode-pull-request-github
PKief.material-icon-theme
VisualStudioExptTeam.vscodeintellicode
alefragnani.Bookmarks
angelo-breuer.clock
bierner.github-markdown-preview
bierner.markdown-checkbox
bierner.markdown-emoji
bierner.markdown-preview-github-styles
bierner.markdown-yaml-preamble
bungcip.better-toml
dbankier.vscode-quick-select
eamodio.gitlens
geeebe.duplicate
ginfuru.ginfuru-better-solarized-dark-theme
johnpapa.vscode-peacock
karigari.chat
mishkinf.goto-next-previous-member
mishkinf.vscode-edits-history
ms-azuretools.vscode-docker
ms-python.python
ms-vscode-remote.remote-containers
ms-vscode-remote.remote-ssh
ms-vscode-remote.remote-ssh-edit
ms-vscode-remote.remote-ssh-explorer
ms-vscode-remote.remote-wsl
ms-vscode-remote.vscode-remote-extensionpack
ms-vsliveshare.vsliveshare
ms-vsliveshare.vsliveshare-audio
ms-vsliveshare.vsliveshare-pack
mtxr.sqltools
streetsidesoftware.code-spell-checker
sysoev.vscode-open-in-github
