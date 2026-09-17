<?php
header('Content-Type: application/json; charset=utf-8');
require_once __DIR__ . '/../db.php';
require_once __DIR__ . '/tracker_math.php';
$data = tracker_json_input();
$id = isset($data['id']) ? (int)$data['id'] : 0;
$clubId = isset($data['club_id']) ? (int)$data['club_id'] : null;
$teamId = isset($data['team_id']) ? (int)$data['team_id'] : 0;
$title = trim((string)($data['title'] ?? 'Поле'));
$isDefault = !empty($data['is_default']) ? 1 : 0;
$lengthM = isset($data['length_m']) && is_numeric($data['length_m'])
  ? (float)$data['length_m'] : 105.0;
$widthM = isset($data['width_m']) && is_numeric($data['width_m'])
  ? (float)$data['width_m'] : 68.0;
if ($teamId <= 0) tracker_fail('Не указан team_id');
if ($title === '') $title = 'Поле';
if (!is_finite($lengthM) || $lengthM < 40 || $lengthM > 130) {
  tracker_fail('Длина поля должна быть от 40 до 130 м');
}
if (!is_finite($widthM) || $widthM < 20 || $widthM > 100) {
  tracker_fail('Ширина поля должна быть от 20 до 100 м');
}

$cornerKeys = [
  'corner_a_lat', 'corner_a_lng', 'corner_b_lat', 'corner_b_lng',
  'corner_c_lat', 'corner_c_lng', 'corner_d_lat', 'corner_d_lng',
];
$providedCorners = 0;
foreach ($cornerKeys as $key) {
  if (array_key_exists($key, $data) && $data[$key] !== null && $data[$key] !== '') {
    if (!is_numeric($data[$key]) || !is_finite((float)$data[$key])) {
      tracker_fail('Некорректная GPS-координата поля: ' . $key);
    }
    $providedCorners++;
  }
}
if ($providedCorners !== 0 && $providedCorners !== 8) {
  tracker_fail('Для калибровки нужны все 4 угла A/B/C/D');
}
if ($providedCorners === 8) {
  foreach (['a', 'b', 'c', 'd'] as $corner) {
    $lat = (float)$data['corner_' . $corner . '_lat'];
    $lng = (float)$data['corner_' . $corner . '_lng'];
    if ($lat < -90 || $lat > 90 || $lng < -180 || $lng > 180 ||
        (abs($lat) < 0.000001 && abs($lng) < 0.000001)) {
      tracker_fail('Угол ' . strtoupper($corner) . ' содержит недопустимую GPS-точку');
    }
  }
}
try {
  $pdo->beginTransaction();
  if ($isDefault) {
    $pdo->prepare("UPDATE tracker_fields SET is_default = 0 WHERE team_id = ?")->execute([$teamId]);
  }
  $payload = [
    ':club_id'=>$clubId, ':team_id'=>$teamId, ':title'=>$title,
    ':length_m'=>$lengthM, ':width_m'=>$widthM,
    ':a_lat'=>($data['corner_a_lat'] ?? null), ':a_lng'=>($data['corner_a_lng'] ?? null),
    ':b_lat'=>($data['corner_b_lat'] ?? null), ':b_lng'=>($data['corner_b_lng'] ?? null),
    ':c_lat'=>($data['corner_c_lat'] ?? null), ':c_lng'=>($data['corner_c_lng'] ?? null),
    ':d_lat'=>($data['corner_d_lat'] ?? null), ':d_lng'=>($data['corner_d_lng'] ?? null),
    ':is_default'=>$isDefault,
  ];
  if ($id > 0) {
    $payload[':id'] = $id;
    $payload[':where_team_id'] = $teamId;
    $stmt = $pdo->prepare("UPDATE tracker_fields SET club_id=:club_id, team_id=:team_id, title=:title, length_m=:length_m, width_m=:width_m, corner_a_lat=:a_lat, corner_a_lng=:a_lng, corner_b_lat=:b_lat, corner_b_lng=:b_lng, corner_c_lat=:c_lat, corner_c_lng=:c_lng, corner_d_lat=:d_lat, corner_d_lng=:d_lng, is_default=:is_default WHERE id=:id AND team_id=:where_team_id");
    $stmt->execute($payload);
    if ($stmt->rowCount() === 0) {
      $check = $pdo->prepare('SELECT id FROM tracker_fields WHERE id=? AND team_id=? LIMIT 1');
      $check->execute([$id, $teamId]);
      if (!$check->fetchColumn()) {
        throw new RuntimeException('Поле не найдено в выбранной команде');
      }
    }
    $fieldId = $id;
  } else {
    $stmt = $pdo->prepare("INSERT INTO tracker_fields (club_id,team_id,title,length_m,width_m,corner_a_lat,corner_a_lng,corner_b_lat,corner_b_lng,corner_c_lat,corner_c_lng,corner_d_lat,corner_d_lng,is_default) VALUES (:club_id,:team_id,:title,:length_m,:width_m,:a_lat,:a_lng,:b_lat,:b_lng,:c_lat,:c_lng,:d_lat,:d_lng,:is_default)");
    $stmt->execute($payload);
    $fieldId = (int)$pdo->lastInsertId();
  }
  $read = $pdo->prepare('SELECT * FROM tracker_fields WHERE id=? AND team_id=? LIMIT 1');
  $read->execute([$fieldId, $teamId]);
  $field = $read->fetch(PDO::FETCH_ASSOC) ?: null;
  $pdo->commit();
  tracker_ok(['field_id'=>$fieldId, 'field'=>$field]);
} catch (Throwable $e) { if ($pdo->inTransaction()) $pdo->rollBack(); tracker_fail('Ошибка сохранения поля', ['error'=>$e->getMessage()]); }
?>
