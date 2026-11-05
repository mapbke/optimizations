# NVIDIA Resizable BAR — эксперимент по ролику Astro

Видео: https://www.youtube.com/watch?v=w6vzk06WDmo
Название, доступное на странице видео: «НОВАЯ Настройка NVIDIA Resize BAR (+20% FPS!)».
Полную расшифровку ролика получить не удалось; ниже — сведения, проверенные по документации NVIDIA, а не утверждения о конкретных тестах автора.

## Что нового
С NVIDIA App 11.0.9 появился переключатель **per game**:
NVIDIA App → Graphics → Program Settings → выберите CS2 → Driver Settings → Resizable BAR.
Если пункта нет — проверьте версию NVIDIA App и драйвера. На аппаратном уровне ReBAR также должен поддерживаться CPU, BIOS, GPU и конфигурацией загрузки.

## Как проверить
1. Откройте NVIDIA Control Panel → System Information; проверьте «Resizable BAR: Yes».
2. В NVIDIA App выберите CS2; сначала оставьте «Auto/Default», сохраните графические настройки.
3. Снимите три одинаковых прогона (Avg FPS, 1% low, график frametime).
4. Измените *только одну* переменную — ReBAR для CS2 на Enabled. Перезапустите игру.
5. Повторите три прогона. Если доступно Disabled — сравните также его.
6. Оставьте режим с лучшим стабильным 1% low / frametime, а не с лучшим единичным пиком FPS. Если различие в шуме измерений — оставьте Auto.

## Почему не «+20% всем»
Resizable BAR меняет доступ CPU к VRAM. Отдельные проекты выигрывают, другие — нет либо становятся медленнее. NVIDIA использует игровые профили, потому что универсального ускорения нет. Дополнительные 20% в заголовке видео не являются прогнозом для RTX 4060 Ti или CS2.

## Что не делаем
- Не применяем Nvidia Profile Inspector к неизвестным ID и не импортируем чужие .nip.
- Не трогаем VBIOS и параметры BAR напрямую через случайные утилиты.
- Не включаем ReBAR глобально для всех игр.

Источники:
https://www.nvidia.com/en-us/software/nvidia-app/release-highlights/
https://www.nvidia.com/en-us/geforce/news/geforce-rtx-30-series-resizable-bar-support/
https://support.faceit.com/hc/en-us/articles/23117181142556-Windows-Security-Requirements-FAQ
