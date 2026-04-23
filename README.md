# Dotfiles: i3 + Polybar + Rofi + Kitty + Zsh

Минималистичное рабочее окружение на базе **i3wm** с панелью **Polybar**, лаунчером **Rofi**, терминалом **Kitty**, шеллом **Zsh** и логин-менеджером **greetd + tuigreet**.

## Быстрая установка (Debian/Ubuntu)

```bash
bash <(curl -sL https://raw.githubusercontent.com/automatorn/dotfiles/main/install.sh)
```

Или вручную:

```bash
git clone https://github.com/automatorn/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

После установки перезагрузи систему. greetd автоматически запустится на **TTY2**, а TTY1 останется доступной консолью (fallback).

## Структура репозитория

```
.config/
├── i3/              # Оконный менеджер i3 (хоткеи, автозапуск, правила окон)
├── polybar/         # Верхняя панель (модули, скрипты, цвета)
├── rofi/            # Лаунчер приложений и цветовая схема
├── kitty/           # Конфигурация терминала Kitty
├── fastfetch/       # Конфиг fastfetch (вывод при старте терминала)
└── wallpapers/      # Обои рабочего стола
zsh/
└── .zshrc           # Конфиг Zsh (Oh My Zsh + плагины)
.xinitrc             # Точка входа в X11-сессию (exec i3)
packages.txt         # Список пакетов для apt
install.sh           # Автоматический установщик
```

## Как работает вход в систему

### greetd + tuigreet

Вместо тяжёлого LightDM используется минималистичный **greetd** с текстовым greeter **tuigreet**:

- Работает на **TTY2** (`Ctrl+Alt+F2`).
- **TTY1** остаётся свободной консолью (`Ctrl+Alt+F1`) — если что-то сломается, можно зайти оттуда.
- Сразу после ввода пароля запускается **i3** через `startx` и `~/.xinitrc`.
- `tuigreet` помнит последнее введённое имя пользователя (`--remember`).

### `.xinitrc`

Файл `~/.xinitrc` содержит одну команду:

```bash
#!/bin/sh
exec i3
```

Это точка входа в графическую сессию. `tuigreet` вызывает `startx`, а тот выполняет `~/.xinitrc`, который запускает i3.

### Перезагрузка / выключение из tuigreet

- **F2** — перезагрузка системы
- **F3** — выключение системы

Также после входа в i3 можно использовать команды `reboot` и `poweroff` без `sudo` — права настроены через polkit.

## i3 (`~/.config/i3/config`)

### Переменные

```i3
set $super Mod4   # Клавиша Windows/Super
set $alt Mod1     # Клавиша Alt
```

### Автозапуск

- `feh` — установка обоев из `~/.config/wallpapers/`
- `setxkbmap` — раскладка `us/ru`, переключение `Alt+Shift`
- `picom` — композитор (vsync, без эффектов для производительности)
- `xrandr` — настройка разрешения монитора `HDMI-2` на `1920x1080`
- `nmcli` — перезагрузка NetworkManager и включение Wi-Fi
- `polybar` — запуск верхней панели (`exec_always`, перезапускается при reload i3)

### Хоткеи

| Комбинация | Действие |
|------------|----------|
| `Super + Enter` | Открыть терминал (`kitty`) |
| `Super + Space` | Открыть лаунчер (`rofi`) |
| `Super + Shift + S` | Скриншот области (`maim -s`) в буфер обмена |
| `Super + L` | Блокировка экрана (`i3lock-fancy`) |
| `Super + E` | Файловый менеджер (`thunar`) |
| `Super + W` | Браузер (`yandex-browser`) |
| `Super + T` | Telegram (Flatpak) |
| `Super + Q` | Закрыть активное окно |
| `Super + H / V` | Разделить окно горизонтально / вертикально |
| `Super + F` | Полноэкранный режим |
| `Alt + Space` | Переключить окно в плавающий режим |
| `Super + Shift + Space` | Переключить фокус между тайловыми и плавающими окнами |
| `Super + ←↓↑→` | Переместить фокус |
| `Super + Shift + ←↓↑→` | Переместить окно |
| `Alt + Tab` | Следующий рабочий стол |
| `Alt + Shift + Tab` | Предыдущий рабочий стол |
| `Super + Ctrl + → / ←` | Следующий / предыдущий рабочий стол |
| `Super + 1..0` | Перейти на рабочий стол 1–10 |
| `Super + Shift + 1..0` | Переместить окно на рабочий стол 1–10 |
| `Super + Backspace` | Перезапустить i3 |
| `Super + Shift + E` | Выйти из i3 (с подтверждением) |
| `Super + R` | Режим изменения размера окна (стрелками, Enter — выход) |
| `XF86AudioRaiseVolume` | Громкость +5% |
| `XF86AudioLowerVolume` | Громкость -5% |
| `XF86AudioMute` | Отключить звук |
| `XF86MonBrightnessUp` | Яркость +5% |
| `XF86MonBrightnessDown` | Яркость -5% |

### Оформление окон

- Рамка у всех окон: `3px`
- Умное скрытие краёв (`hide_edge_borders smart`)
- Внутренние отступы (`gaps inner 10`)
- Внешние отступы (`gaps outer 5`)

### Цвета рамок

| Состояние | Цвет рамки / фона / текста |
|-----------|---------------------------|
| Активное | `#ededed` / `#181818` / `#ededed` |
| Неактивное | `#181818` / `#181818` / `#ededed` |
| Срочное | `#ff7f7f` / `#181818` / `#ededed` |

## Polybar (`~/.config/polybar/`)

### Модули

| Модуль | Что показывает | Действие по клику |
|--------|----------------|-------------------|
| `xworkspaces` | Рабочие столы i3 | — |
| `xwindow` | Заголовок активного окна (до 60 символов) | — |
| `xkeyboard` | Текущая раскладка (`US` / `RU`) | — |
| `battery` | Заряд батареи / статус зарядки | — |
| `pulseaudio` | Громкость или `MUTED` | — |
| `memory` | Использование RAM в процентах | — |
| `bluetooth` | Имя подключённого устройства или `BT` | ЛКМ — `bluetoothctl` |
| `network` | `ETH`, `WIFI <SSID>` или `disconnect network` | ЛКМ — `nmtui` |
| `date` | Текущее время (`%H:%M`) | — |
| `tray` | Системный трей | — |

> Модуль `battery` автоматически скрывается, если батарея не обнаружена.

## Kitty (`~/.config/kitty/kitty.conf`)

- **Шрифт:** JetBrainsMono Nerd Font, размер `11.0`
- **Курсор:** beam (вертикальная черта), мигание `0.8s`
- **Тема:** Catppuccin Mocha
- **Табы:** powerline, slanted-стиль, внизу окна
- **Клавиши:**
  - `Ctrl+Shift+T` — новая вкладка
  - `Ctrl+Shift+W` — закрыть вкладку
  - `Ctrl+Tab` — следующая вкладка
  - `Ctrl+Shift+Tab` — предыдущая вкладка

## Zsh (`~/.zshrc`)

- **Фреймворк:** Oh My Zsh
- **Тема:** `agnoster`
- **Плагины:** `git`, `zsh-autosuggestions`
- **Автозапуск:** `fastfetch` при открытии терминала

## Полезные команды

```bash
# Перезапустить i3 (равнозначно Super + Backspace)
i3-msg restart

# Перечитать конфиг i3 без перезапуска
i3-msg reload

# Перезапустить polybar
~/.config/polybar/launch.sh

# Проверить конфиг i3 на ошибки
i3 -C -c ~/.config/i3/config

# Подключить Bluetooth-устройство
bluetoothctl
# → power on, agent on, scan on, pair MAC, trust MAC, connect MAC
```

## Частые изменения

### Сменить обои

Замени файл в `~/dotfiles/.config/wallpapers/` и обнови путь в `~/.config/i3/config`:

```i3
exec_always --no-startup-id feh --bg-fill ~/dotfiles/.config/wallpapers/новое_имя.jpg
```

### Изменить модуль polybar

В `~/.config/polybar/config.ini` в секции `[bar/automatorn]`:

```ini
modules-right = tray xkeyboard battery pulseaudio memory bluetooth network date
```

### Добавить свой хоткей в i3

Пример:

```i3
bindsym $super+d exec discord
```

## Примечания

### Flatpak Telegram и доступ к файлам

Telegram устанавливается через Flatpak с ограниченным доступом к файловой системе. `install.sh` автоматически выдаёт приложению доступ ко всей домашней директории через `flatpak override --filesystem=home`, чтобы можно было прикреплять файлы из любой папки.
