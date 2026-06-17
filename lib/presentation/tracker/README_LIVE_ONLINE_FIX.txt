Sportoteka Tracker Pro — Live online fix

Что изменено в этом пакете:

1) Дизайн Live-окна
- Добавлена верхняя тёмно-синяя панель в стиле промышленного веб-интерфейса, как на примере: Live Center, Analytics, Quality Control, Logistics, Process, Master Data, System.
- Live теперь визуально выглядит как отдельная операторская система, а не старый блок.

2) Онлайн-метрики
- Модель TrackerLiveSessionModel теперь читает не только speed_kmh, но и все варианты полей с сервера:
  distance_m / total_distance_m,
  meterage_per_min / meters_per_minute / m_per_min,
  load_score / player_load,
  hsr_distance_m / high_speed_distance_m,
  hir_distance_m,
  vhir_distance_m,
  sprint_distance_m,
  sprint_count,
  accel_count,
  decel_count,
  change_of_direction_count,
  fatigue_index,
  speed_drop_percent,
  metabolic_power_proxy.
- Командная таблица больше не ставит М/МИН, HSR и Sprint принудительно в 0.
- Правый блок аналитики показывает серверные данные даже если локально есть только одна GPS-точка.

3) Сохранение Live-точек
- При сохранении каждой точки Flutter теперь отправляет на сервер не только latitude/longitude, но и рассчитанные онлайн-показатели:
  скорость, дистанция, delta, max speed, avg speed, м/мин, нагрузка, fatigue, HIR/VHIR/Sprint, ускорения, торможения, смены направления, metabolic proxy, analysis_json.
- Также отправляются field_x_m / field_y_m по калибровке поля.

4) Поле и движение точки
- Точка теперь проецируется через реальную калибровку поля по 4 углам, а не просто по bounds GPS.
- Серверные координаты last_latitude/last_longitude тоже добавляются в RuntimeTrack, поэтому точка видна даже после polling состояния.

5) Bluetooth на macOS / DMG
- Поиск больше не отсекает устройства только по префиксам $ACT/$ATP/$GPS.
- На macOS показываются все видимые BLE-устройства с именем, NUS service или нормальным RSSI; трекеры всё равно поднимаются выше в списке.

Важно:
Если серверный PHP save_tracker_live_point.php пока сохраняет только скорость/координаты, то в текущем Live-окне данные будут считаться локально. Чтобы они появлялись после перезагрузки и на других устройствах, PHP должен принимать и сохранять новые поля из payload.
