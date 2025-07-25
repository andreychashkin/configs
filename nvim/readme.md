# Заархивированная папка с конфигом для astrovim


установка релизной версии nvim
```bash
curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
sudo rm -rf /opt/nvim
sudo tar -C /opt -xzf nvim-linux-x86_64.tar.gz
```
- добавить в конфиг командной строки (~/.bashrc, ~/.zshrc, ...):
```bash
export PATH="$PATH:/opt/nvim-linux-x86_64/bin"
```
- разархивировать в конфиг nvim

- положить config.conf в .config/clangd/

- установить шрифт nert font в терминал
```bash
mkdir -p ~/.local/share/fonts
cp ~/Downloads/имя_шрифта.ttf ~/.local/share/fonts/
cp ~/Downloads/имя_шрифта.otf ~/.local/share/fonts/
fc-cache -fv
```

- установить bear для сборки 
```bash
sudo apt install bear

```

- собрать проект через bear
```bash
qmake6 VinteoAll.pro DEFINES+=TESTS CONFIG+=Tests DEFINES+=FOR_API_TEST
bear -- make -j 10 
```

### залочил gD и gd для перехода к декларации и определению методов переменных и тд (так же можно использовать ctrl + click как в qtcreator)
### установил абсолютную нумерацию строк
