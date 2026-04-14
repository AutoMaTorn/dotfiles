# Дотфайлы: i3 + Polybar + Rofi + Kitty + Zsh

Полностью автоматизированное минималистичное рабочее окружение на базе **i3wm** с панелью **Polybar**, лаунчером **Rofi**, терминалом **Kitty** и шеллом **Zsh**.

---

## Быстрая установка (Debian/Ubuntu)

На чистой системе без оконного окружения выполни:

```bash
bash <(curl -sL https://raw.githubusercontent.com/automatorn/dotfiles/main/install.sh)
```

Или вручную:

```bash
git clone https://github.com/automatorn/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

> **Примечание:** установщик также поставит `Discord`, `Yandex Browser`, `Spotify`, `Telegram`, `v2rayN` и настроит `Flatpak`.

---

## Структура репозитория

```
.config/
├── i3/                        # Конфиг i3 (оконный менеджер)
│   └── scripts/               # Скрипты автозапуска и утилиты
├── polybar/                   # Настройки панели polybar
├── rofi/                      # Лаунчер и цветовая схема
├── kitty/                     # Конфиг терминала
├── fastfetch/                 # Конфиг fastfetch
└── wallpapers/                # Обои рабочего стола
zsh/
└── .zshrc                     # Конфиг Zsh
packages.txt                   # Список пакетов для apt
install.sh                     # Bootstrap установщик
```

---

## i3 (`~/.config/i3/config`)

### Переменные

```i3
set $super Mod4     # Клавиша Windows/Super
set $alt Mod1       # Клавиша Alt
```

### Хоткеи

| Комбинация | Действие |
|------------|----------|
| `Super + Enter` | Открыть терминал (`kitty`) |
| `Super + Пробел` | Открыть лаунчер (`rofi`) |
| `Super + Shift + S` | Скриншот (`flameshot gui`) |
| `Super + L` | Блокировка экрана (`i3lock-fancy`) |
| `Super + W` | Браузер (`yandex-browser`) |
| `Super + T` | Telegram (Flatpak) |
| `Super + Q` | Закрыть активное окно |
| `Super + Ctrl + Q` | Свернуть окно в scratchpad (минимизация) |
| `Alt + Tab` | Следующий рабочий стол |
| `Alt + Shift + Tab` | Предыдущий рабочий стол |
| `Super + Ctrl + Tab` | Вернуться на предыдущий стол (`back_and_forth`) |
| `Super + H/V` | Разделить окна горизонтально/вертикально |
| `Super + F` | Полноэкранный режим |
| `Alt + Пробел` | Переключить окно в плавающий режим |
| `Super + Shift + Пробел` | Переключить фокус между тайловыми и плавающими окнами |
| `Super + 1..0` | Перейти на рабочий стол 1–10 |
| `Super + Shift + 1..0` | Переместить окно на рабочий стол 1–10 |
| `Super + Ctrl + ←/→` | Переключиться на предыдущий/следующий рабочий стол |
| `Super + Ctrl + Shift + ←/→` | Переместить окно на соседний рабочий стол |
| `Super + Backspace` | Перезапустить i3 |
| `Super + Shift + E` | Выйти из i3 |
| `Super + R` | Режим изменения размера окна (стрелками) |
| `XF86AudioRaiseVolume` | Громкость +5% |
| `XF86AudioLowerVolume` | Громкость -5% |
| `XF86AudioMute` | Mute |
| `XF86MonBrightnessUp/Down` | Яркость ±5% |

### Автозапуск

- `feh` — обои
- `pipewire-launcher` — звук
- `setxkbmap` — раскладка `us/ru`, переключение `Alt+Shift`
- `polybar` — панель (через `exec_always`)

---

## Polybar (`~/.config/polybar/`)

### Модули

| Модуль | Что показывает | Клик ЛКМ |
|--------|----------------|----------|
| `xworkspaces` | Рабочие столы | — |
| `xwindow` | Заголовок окна | — |
| `xkeyboard` | Раскладка US / RU | — |
| `pulseaudio` | Громкость / Mute | — |
| `memory` | RAM в процентах | — |
| `bluetooth` | Имя подключенного устройства или `BT` | `blueman-manager` |
| `network` | `ETH`, `WIFI` или `disconnect network` | `nmtui` |
| `date` | Время | — |
| `tray` | Системный трей | — |

> **Примечание:** модуль `battery` отключён автоматически polybar, если батарея не найдена.

---

## Kitty (`~/.config/kitty/`)

- Шрифт: **JetBrainsMono Nerd Font**
- Тема: **Catppuccin Mocha**
- Курсор: beam (вертикальная черта)
- Табы в стиле powerline

---

## Zsh (`~/.zshrc`)

- Фреймворк: **Oh My Zsh**
- Плагины: `zsh-autosuggestions`, `zsh-syntax-highlighting`
- Fastfetch запускается автоматически при открытии терминала (если настроено в `.zshrc`)

---

## packages.txt

Файл содержит список пакетов, которые `install.sh` установит через `apt`. Редактируй его перед запуском скрипта, чтобы добавить или убрать пакеты.

```bash
nano ~/dotfiles/packages.txt
```

Затем перезапусти установщик:
```bash
cd ~/dotfiles
./install.sh
```

---

## Частые изменения

### Поменять обои

Замени файл в `~/.config/wallpapers/` и укажи новое имя в `~/.config/i3/config`:

```i3
exec_always --no-startup-id feh --bg-fill ~/.config/wallpapers/новое_имя.jpg
```

### Добавить/убрать модуль в polybar

В `~/.config/polybar/config.ini` в секции `[bar/automatorn]`:

```ini
modules-right = tray xkeyboard pulseaudio memory bluetooth network date
```

### Поменять хоткей в i3

```i3
bindsym $super+d exec discord
```

### Поменять цвета

- **i3**: `~/.config/i3/config` → строки `client.focused ...`
- **polybar**: `~/.config/polybar/config.ini` → `[colors]`
- **rofi**: `~/.config/rofi/colors.rasi`
- **kitty**: `~/.config/kitty/kitty.conf`

---

## Полезные команды

```bash
# Перезапустить i3
Super + Backspace

# Перечитать конфиг i3 без перезапуска
i3-msg reload

# Перезапустить polybar
~/.config/polybar/launch.sh

# Проверить конфиг i3 на ошибки
i3 -C -c ~/.config/i3/config

# Подключить Bluetooth-наушники
bluetoothctl
# → power on, agent on, scan on, pair MAC, trust MAC, connect MAC
```
