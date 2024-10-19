#!/bin/bash
if [ "$#" -eq 0 ]
then
  echo "Передай арументов к запуску Имя Пользователя"
  exit 1
else
  apt install -y curl
  curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh" | sudo bash
  apt install -y adb mc snapd npm neovim python3-pip python3-virtualenv
  apt install -y gitlab-runner openssh-server ssh
  snap install android-studio --classic
  apt install -y openjdk-17-jdk
  npm install -g appium
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
  git clone https://github.com/andreychashkin/configs.git
  cp configs/nvim/nvim.zip /home/$1/.config/
  unzip /home/$1/.config/nvim.zip /home/$1/.config/
fi
