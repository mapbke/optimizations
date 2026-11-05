# CS2: проверяем FPS, frametime и мышь без самообмана

## Чистый A/B-тест
1. Перед каждой серией одинаковые сборка CS2, Windows, драйвер и карта.
2. Одинаковые разрешение (например, 2560×1440), частота монитора (например, 260 Hz), Reflex/G-SYNC/V-SYNC, FPS cap, настройки графики и фоновые программы.
3. Запишите Avg FPS, P1 FPS (= 1% low) и желательно p95/p99 frametime в CapFrameX или PresentMon. Три одинаковых прогона для режима BEFORE, три для AFTER.
4. Для честной проверки не используйте случайные FACEIT-матчи: разные сцены, дым и количество игроков дают разные FPS.
5. Для анализа Nvidia ReBAR сравните Auto/Enabled/Disabled, меняя только режим ReBAR, и перезапускайте CS2 между режимами.
6. Если 1% low упал или выросли нерегулярные пики frametime, откатите изменение даже при небольшом приросте Avg FPS.

## Сравнение CSV в пакете
Скопируйте benchmarks/before.example.csv в benchmarks/before.csv, а after.example.csv в benchmarks/after.csv и замените ИЛЛЮСТРАТИВНЫЕ числа своими измерениями. Формат: Run,AvgFPS,P1FPS,Notes. Три строки минимум. В START.cmd выберите 8 и введите пути к двум CSV. Сравнение использует медиану прогонов, не одну лучшую попытку.

## Плавность мыши
- В ПО Lamzu проверьте DPI, polling rate, заряд/кабель и отсутствие непреднамеренного переключения профилей.
- Избегайте USB-хабов и радиопомех от 2.4 GHz устройств. Проверьте напрямую на USB порту ПК, затем другой порт.
- Mouse 6/11 + отключенная EPP даёт привычную линейность в Windows; не является исправлением задержки USB или сенсора.
- Для CS2 с raw input некоторые системные настройки указателя не влияют на ввод.
- Не выставляйте 4K/8K polling «по умолчанию» ради маркетинга: тестируйте 1000/2000/4000 Hz и frametime/стабильность. Это не универсальное улучшение.

## Ручные проверки без рискованных REG-твиков
- Windows Settings → Gaming → Game Mode: включено, затем тест; Xbox Game Bar можно оставлять, захват регулируется отдельно.
- Settings → Display → Advanced Display: выбран максимальный фактически доступный герцовочный режим.
- Settings → System → Display → Graphics: для DX10/DX11 оконных игр есть «Optimizations for windowed games»; CS2 использует DX11 и Vulkan в зависимости от конфигурации.
- NVIDIA App: обновлённый драйвер, проверка ReBAR и настройки per game.
- Фиксируйте температуру и power/thermal limit: плохие 1% low могут быть вызваны железом или драйверами, а не «лишними процессами».

Ссылки:
https://support.microsoft.com/ru-ru/windows/hardware/display-graphics/optimizations-for-windowed-games-in-windows-11
https://www.nvidia.com/en-us/software/nvidia-app/release-highlights/
