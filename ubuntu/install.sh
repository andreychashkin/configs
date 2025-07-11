#!/bin/bash
if [ "$#" -eq 0 ]
then
  echo "Передай арументов к запуску Имя Пользователя"
  exit 1
else
  apt install -y curl
  curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh" | sudo bash
  apt install -y adb mc snapd npm python3-pip python3-virtualenv
  apt install -y gitlab-runner openssh-server ssh
  apt install -y qtcreator
  apt install -y xclip
  apt install -y zsh
  snap install android-studio --classic
  snap install helix --classic
  apt install -y openjdk-17-jdk
  npm install -g appium
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  chsh -s $(which zsh)
  appium driver install uiautomator2
  touch /appium_env
  echo "
  ANDROID_HOME=/home/$1/Android/Sdk
  ANDROID_SDK_ROOT=/home/$1/Android/Sdk
  JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
  PATH=$PATH:/home/$1/Android/Sdk/platform-tools" >> /appium_env
  touch /etc/systemd/system/start_appium.service
  echo "
  [Unit]
  Description=Appium server start
  [Service]
  EnvironmentFile=/appium_env
  ExecStart=appium server -p 4723 -a 127.0.0.1 -pa /wd/hub
  [Install]
  WantedBy=multi-user.target" >> /etc/systemd/system/start_appium.service
  systemctl daemon-reload
  systemctl enable start_appium.service
  systemctl start start_appium.service
  systemctl enable ssh
  mkdir /home/$1/.config/helix
  touch /home/$1/.config/helix/config.toml /home/$1/.config/helix/config.toml
  echo "
theme = 'gruvbox'

[editor]
mouse = false
clipboard-provider = 'x-clip'

[editor.cursor-shape]
insert = 'bar'
normal = 'block'
select = 'underline'

[editor.file-picker]
hidden = false

[keys.insert.j]
k = 'normal_mode' 
" >> /home/$1/.config/helix/config.toml
  echo "
# [[language]]
# name = 'python'
# language-servers = [ 'pyright' ]

[[language]]
name = 'python'
language-servers = ['pylsp', 'ruff']

formatter = { command = 'black', args = ['--quiet', '-'] }
auto-format = true

[language-server.pylsp.config.pylsp.plugins]
flake8 = {enabled = false}
autopep8 = {enabled = false}
mccabe = {enabled = false}
pycodestyle = {enabled = false}
pyflakes = {enabled = false}
pylint = {enabled = false}
yapf = {enabled = false}
ruff = { enabled = true, lineLength = 120}" >> /home/$1/.config/helix/languages.toml
  rm /home/$1/.zshrc
  touch /home/$1/.zshrc
  echo "
# меняем патч для zsh
export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:/usr/local/sbin:/usr/sbin:/sbin:/snap/bin:$PATH                                           
# сокращаем частые команды
alias ..='cd ..'                                                                                                                                
alias l='ls -la'                                                                                                                                
alias c='clear'                                                                                                                                 
#zsh
export ZSH="$HOME/.oh-my-zsh"                                                                                                                   
ZSH_THEME="arrow"                                                                                                                               
# плагины
plugins=(git)                                                                                                                                   
# zsh
source $ZSH/oh-my-zsh.sh" >> /home/$1/.zshrc
fi
