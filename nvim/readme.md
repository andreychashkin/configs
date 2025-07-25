# Заархивированная папка с конфигом для astrovim

- поменял только тему оформления
- разархивировать в конфиг nvim
- положить config.conf в .config/clangd/
- установить шрифт nert font в терминал

1. Создай папку для шрифтов (если ещё нет):

mkdir -p ~/.local/share/fonts

2. Скопируй туда шрифт:

cp ~/Downloads/имя_шрифта.ttf ~/.local/share/fonts/

Или если .otf:

cp ~/Downloads/имя_шрифта.otf ~/.local/share/fonts/

3. Обнови кэш шрифтов:

fc-cache -fv
