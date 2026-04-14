# Дотфайлы: i3 + Polybar + Rofi

Этот репозиторий содержит конфиги для минималистичного рабочего окружения на базе **i3wm** с панелью **Polybar**, лаунчером **Rofi**, терминалом **Kitty** и шеллом **Zsh**.

---

## Быстрая установка (Debian/Ubuntu)

На чистой системе без оконного окружения выполни:

```bash
bash <(curl -sL https://raw.githubusercontent.com/GITHUB_USER/dotfiles/main/install.sh)
```

> **Важно:** замени `GITHUB_USER/dotfiles` на свой репозиторий перед запуском.

Или вручную:

```bash
git clone https://github.com/GITHUB_USER/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

Список устанавливаемых пакетов находится в файле [`packages.txt`](packages.txt). Редактируй его, чтобы добавить или убрать пакеты.

---

## Структура репозитория

```
.config/
├── i3/                        # Конфиг i3 (оконный менеджер)
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

Главный конфиг оконного менеджера. Отвечает за хоткеи, автозапуск, внешний вид окон и рабочие столы.

### Переменные

```i3
set $super Mod4     # Клавиша Windows/Super
set $alt Mod1       # Клавиша Alt
```

Все хоткеи завязаны на `$super` (Win) и `$alt` (Alt).

### Автозапуск

```i3
exec --no-startup-id feh --bg-fill ~/.config/wallpapers/wallpapers.jpg
exec --no-startup-id /usr/libexec/pipewire-launcher
exec --no-startup-id setxkbmap -layout us,ru -option 'grp:ctrl_alt_toggle'
```

- `exec` — выполняет команду **один раз** при старте i3.
- `exec_always` — выполняет команду **каждый раз** при перезапуске i3 (полезно для polybar).
- `--no-startup-id` — убирает анимацию загрузки курсора при запуске.

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
| `Super + H/V` | Разделить окна горизонтально/вертикально |
| `Super + F` | Полноэкранный режим |
| `Alt + Пробел` | Переключить окно в плавающий режим |
| `Super + Shift + Пробел` | Переключить фокус между тайловыми и плавающими окнами |
| `Super + 1..0` | Перейти на рабочий стол 1–10 |
| `Super + Shift + 1..0` | Переместить окно на рабочий стол 1–10 |
| `Super + Ctrl + ←/→` | Переключиться на предыдущий/следующий рабочий стол |
| `Super + Backspace` | Перезапустить i3 |
| `Super + Shift + E` | Выйти из i3 |
| `Super + R` | Режим изменения размера окна (стрелками) |
| `XF86AudioRaiseVolume` | Громкость +5% |
| `XF86AudioLowerVolume` | Громкость -5% |
| `XF86AudioMute` | Mute |
| `XF86MonBrightnessUp/Down` | Яркость ±5% |

### Важно: ключевое слово `exec`

Если вы добавляете свой хоткей для запуска программы, **перед командой обязательно пишите `exec`**:

```i3
# ✅ Правильно:
bindsym $super+w exec yandex-browser

# ❌ Неправильно (будет ошибка в логах i3):
bindsym $super+w yandex-browser
```

### Внешний вид окон

```i3
client.focused #ededed #181818 #ededed #ededed #ededed
```

Формат: `client.focused <border> <background> <text> <indicator> <child_border>`

Также заданы цвета для неактивных (`focused_inactive`), не сфокусированных (`unfocused`), срочных (`urgent`) окон.

### Правила для окон

```i3
for_window [class=".*"] border pixel 3   # Рамка в 3 пикселя для всех окон
hide_edge_borders smart                  # Скрывать рамки при одном окне
gaps inner 0                             # Внутренние отступы между окнами
```

---

## Polybar (`~/.config/polybar/`)

### `launch.sh`

Скрипт, который:
1. Убивает все запущенные процессы `polybar`.
2. Ждёт их завершения.
3. Запускает бар с именем `alexdenkk`.

Вызывается в i3 через:
```i3
exec_always --no-startup-id ~/.config/polybar/launch.sh
```

### `config.ini`

#### Цвета (`[colors]`)

Здесь задаются цвета, которые потом используются в модулях:

```ini
background = #181818
foreground = #ededed
primary = #ededed
alert = #ededed
disabled = #ededed

color1 = #ededed
color2 = #6d89a7
color3 = #485571
color4 = #8abe8a
color5 = #ffb99c
color6 = #ff7f7f
```

#### Бар (`[bar/alexdenkk]`)

Основные настройки панели:

```ini
width = 100%
height = 24pt
background = ${colors.background}
foreground = ${colors.foreground}

modules-left = xworkspaces xwindow
modules-right = tray xkeyboard battery pulseaudio memory wlan date
```

- `modules-left` — модули слева.
- `modules-right` — модули справа.

#### Модули

| Модуль | Что показывает |
|--------|----------------|
| `xworkspaces` | Номера рабочих столов (активный подсвечен) |
| `xwindow` | Заголовок активного окна (макс. 60 символов) |
| `xkeyboard` | Текущая раскладка клавиатуры (US / RU) |
| `battery` | Уровень заряда батареи (`BAT1`) и статус зарядки (`ACAD`) |
| `pulseaudio` | Громкость / Mute |
| `memory` | Использование ОЗУ в процентах |
| `wlan` | Имя Wi-Fi сети (ESSID) или `WIFI disconnected` |
| `date` | Текущее время (`%H:%M`), при клике — полная дата |
| `tray` | Системный трей (иконки приложений) |

#### Как убрать/добавить модуль

Например, чтобы убрать батарею, измените `modules-right`:

```ini
modules-right = tray xkeyboard pulseaudio memory wlan date
```

#### Как поменять цвет модуля

В секции модуля обычно есть `label-...-background` и `label-...-foreground`:

```ini
label-volume-background = ${colors.color3}
label-volume-foreground = ${colors.background}
```

---

## Rofi (`~/.config/rofi/`)

### `colors.rasi`

Переменные цветов, которые используются в `config.rasi`:

```css
* {
  al:  #181818;   /* альфа/прозрачный фон (здесь просто #181818) */
  bg:  #181818;   /* фон окна */
  se:  #ededed;   /* цвет выделения (selection) */
  fg:  #ededed;   /* цвет текста */
  ac:  #ededed;   /* акцент */
  br:  #ededed;   /* рамка */
}
```

### `config.rasi`

#### Общие настройки

```css
configuration {
  font: "Roboto mono 12";
  show-icons: true;
  icon-theme: "Papirus";
  display-drun: ">";
  columns: 2;
  lines: 5;
}
```

- `show-icons: true` — показывать иконки приложений.
- `icon-theme: "Papirus"` — тема иконок.
- `columns: 2` — количество колонок в списке.
- `lines: 5` — количество строк.

#### Геометрия окна

```css
window {
  height: 45.3%;
  width: 40%;
  location: center;
  border: 2px;
  border-color: @br;
  border-radius: 0px;
}
```

#### Строка поиска

```css
inputbar {
  children: [ prompt, entry ];
  background-color: @bg;
}

entry {
  placeholder: "Search";
}
```

#### Элементы списка

```css
element-icon {
  size: 28px;
}

element selected {
  border: 3px;
  border-color: @se;
}
```

---

## Частые изменения (шпаргалка)

### Поменять обои

В `~/.config/i3/config` измените путь:

```i3
exec --no-startup-id feh --bg-fill ~/.config/wallpapers/новое_имя.jpg
```

### Изменить размер rofi

В `~/.config/rofi/config.rasi`:

```css
window {
  width: 50%;      /* ширина окна */
  height: 60%;     /* высота окна */
}

listview {
  columns: 3;      /* количество колонок */
  lines: 8;        /* количество строк */
}
```

### Добавить/убрать модуль в polybar

В `~/.config/polybar/config.ini` в секции `[bar/alexdenkk]`:

```ini
modules-right = tray xkeyboard pulseaudio memory wlan date
```

### Поменять хоткей в i3

В `~/.config/i3/config`:

```i3
bindsym $super+d exec discord
```

### Поменять цвета

- **i3**: править строки `client.focused ...` в `~/.config/i3/config`.
- **polybar**: править секцию `[colors]` в `~/.config/polybar/config.ini`.
- **rofi**: править `~/.config/rofi/colors.rasi`.

---

## Зависимости

Для корректной работы всех конфигов должны быть установлены:

- `i3-wm` (или `i3-gaps`) — оконный менеджер
- `polybar` — панель
- `rofi` — лаунчер приложений
- `kitty` — терминал
- `feh` — установка обоев
- `pipewire` (или `pulseaudio`) — звук
- `brightnessctl` — управление яркостью
- `pactl` — управление громкостью (из `pulseaudio-utils`)
- `setxkbmap` — переключение раскладки (из `setxkbmap` / `xorg-setxkbmap`)
- `flameshot` — скриншоты
- `i3lock-fancy` — блокировка экрана
- `yandex-browser` — браузер (можно заменить на любой другой)
- `flatpak` + `org.telegram.desktop` — Telegram
- `papirus-icon-theme` — тема иконок для rofi

---

## Полезные команды

```bash
# Перезапустить i3 (сохраняет сессию)
$mod+BackSpace

# Перечитать конфиг i3 без перезапуска
i3-msg reload

# Перезапустить polybar вручную
~/.config/polybar/launch.sh

# Проверить конфиг i3 на ошибки
i3 -C -c ~/.config/i3/config
```
