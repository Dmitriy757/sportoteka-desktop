<?php
header('Content-Type: application/json; charset=utf-8');
require_once __DIR__ . '/../db.php';
require_once __DIR__ . '/tracker_math.php';

$teamId = isset($_GET['team_id']) ? (int)$_GET['team_id'] : 0;
if ($teamId <= 0) tracker_fail('Не указан team_id');

try {
    $columnCheck = $pdo->prepare(
        "SELECT 1
         FROM information_schema.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE()
           AND TABLE_NAME = 'tracker_fields'
           AND COLUMN_NAME = 'is_archived'
         LIMIT 1"
    );
    $columnCheck->execute();
    $hasArchiveColumn = (bool)$columnCheck->fetchColumn();

    $sql = $hasArchiveColumn
        ? "SELECT * FROM tracker_fields WHERE team_id = ? AND COALESCE(is_archived, 0) = 0 ORDER BY is_default DESC, id DESC"
        : "SELECT * FROM tracker_fields WHERE team_id = ? ORDER BY is_default DESC, id DESC";

    $stmt = $pdo->prepare($sql);
    $stmt->execute([$teamId]);
    tracker_ok(['fields' => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
} catch (Throwable $e) {
    tracker_fail('Ошибка загрузки полей', ['error' => $e->getMessage()]);
}
?>
