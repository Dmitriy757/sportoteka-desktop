<?php
header('Content-Type: application/json; charset=utf-8');
require_once __DIR__ . '/../db.php';
require_once __DIR__ . '/tracker_math.php';

$data = tracker_json_input();
$id = isset($data['id']) ? (int)$data['id'] : 0;
$teamId = isset($data['team_id']) ? (int)$data['team_id'] : 0;

if ($id <= 0) tracker_fail('Не указан id поля');
if ($teamId <= 0) tracker_fail('Не указан team_id');

try {
    // Мягкое удаление: поле исчезает из списка, но запись остаётся в БД.
    // Благодаря этому старые тренировки/Live-сессии, где сохранён field_id,
    // не теряют историческую привязку и не ломаются внешние ключи.
    $columnCheck = $pdo->prepare(
        "SELECT 1
         FROM information_schema.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE()
           AND TABLE_NAME = 'tracker_fields'
           AND COLUMN_NAME = 'is_archived'
         LIMIT 1"
    );
    $columnCheck->execute();
    if (!$columnCheck->fetchColumn()) {
        $pdo->exec(
            "ALTER TABLE tracker_fields
             ADD COLUMN is_archived TINYINT(1) NOT NULL DEFAULT 0 AFTER is_default"
        );
    }

    $pdo->beginTransaction();

    $read = $pdo->prepare(
        "SELECT id, title, is_default
         FROM tracker_fields
         WHERE id = ? AND team_id = ? AND COALESCE(is_archived, 0) = 0
         LIMIT 1
         FOR UPDATE"
    );
    $read->execute([$id, $teamId]);
    $field = $read->fetch(PDO::FETCH_ASSOC);
    if (!$field) {
        throw new RuntimeException('Поле не найдено в выбранной команде');
    }

    $archive = $pdo->prepare(
        "UPDATE tracker_fields
         SET is_archived = 1, is_default = 0
         WHERE id = ? AND team_id = ?"
    );
    $archive->execute([$id, $teamId]);

    $newDefaultId = null;
    if ((int)$field['is_default'] === 1) {
        $next = $pdo->prepare(
            "SELECT id
             FROM tracker_fields
             WHERE team_id = ? AND COALESCE(is_archived, 0) = 0
             ORDER BY id DESC
             LIMIT 1"
        );
        $next->execute([$teamId]);
        $candidate = $next->fetchColumn();
        if ($candidate !== false) {
            $newDefaultId = (int)$candidate;
            $setDefault = $pdo->prepare(
                "UPDATE tracker_fields SET is_default = 1 WHERE id = ? AND team_id = ?"
            );
            $setDefault->execute([$newDefaultId, $teamId]);
        }
    }

    $pdo->commit();
    tracker_ok([
        'deleted_field_id' => $id,
        'field_id' => $id,
        'title' => $field['title'],
        'new_default_field_id' => $newDefaultId,
        'soft_deleted' => true,
    ]);
} catch (Throwable $e) {
    if ($pdo->inTransaction()) $pdo->rollBack();
    tracker_fail('Ошибка удаления поля', ['error' => $e->getMessage()]);
}
?>
