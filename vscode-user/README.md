This settings directory actually lives on macOS at:

    ~/Library/Application\ Support/Code/User

To back up the config, periodically copy the file to ~/dotfiles/vscode-user:

    ~/dotfiles/vscode-user
    rm -fR globalStorage/ workspaceStorage/
    cp -R ~/Library/Application\ Support/Code/User/* .

Installed extensions (run command then paste below):

    code --list-extensions | sort | pbcopy

EditorConfig.EditorConfig
GitHub.vscode-pull-request-github
JinoAntony.vscode-case-shifter
PKief.material-icon-theme
VisualStudioExptTeam.vscodeintellicode
adashen.vscode-tomcat
alefragnani.Bookmarks
angelo-breuer.clock
bierner.github-markdown-preview
brunnerh.insert-unicode
bungcip.better-toml
christian-kohler.npm-intellisense
dbaeumer.vscode-eslint
dbankier.vscode-quick-select
eamodio.gitlens
esbenp.prettier-vscode
felipecaputo.git-project-manager
ginfuru.ginfuru-better-solarized-dark-theme
humao.rest-client
iocave.customize-ui
iocave.monkey-patch
jetmartin.bats
johnpapa.vscode-peacock
karigari.chat
lextudio.restructuredtext
mhutchie.git-graph
mishkinf.goto-next-previous-member
mishkinf.vscode-edits-history
ms-azuretools.vscode-docker
ms-python.python
ms-python.vscode-pylance
ms-vscode-remote.remote-containers
ms-vscode-remote.remote-ssh
ms-vscode-remote.remote-ssh-edit
ms-vscode-remote.remote-wsl
ms-vscode-remote.vscode-remote-extensionpack
ms-vsliveshare.vsliveshare
ms-vsliveshare.vsliveshare-audio
ms-vsliveshare.vsliveshare-pack
mtxr.sqltools
mtxr.sqltools-driver-mysql
mtxr.sqltools-driver-pg
redhat.java
redhat.vscode-xml
shamanu4.django-intellisense
stkb.rewrap
streetsidesoftware.code-spell-checker
sysoev.vscode-open-in-github
tehnix.vscode-tidymarkdown
usernamehw.errorlens
vscjava.vscode-java-debug
vscjava.vscode-java-dependency
vscjava.vscode-java-pack
vscjava.vscode-java-test
vscjava.vscode-maven
yzhang.markdown-all-in-one
