This settings directory actually lives on macOS at:

    ~/Library/Application Support/Code/User

To back up the config, periodically copy the file to ~/dotfiles/vscode-user:

    cp -R ~/Library/Application\ Support/Code/User ~/dotfiles/vscode-user

Installed extensions:

    code --list-extensions | sort | pbcopy

EditorConfig.EditorConfig
PKief.material-icon-theme
PeterJausovec.vscode-docker
alefragnani.Bookmarks
angelo-breuer.clock
dbankier.vscode-quick-select
eamodio.gitlens
geeebe.duplicate
ginfuru.ginfuru-better-solarized-dark-theme
ms-python.python
mtxr.sqltools
streetsidesoftware.code-spell-checker
