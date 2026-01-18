<?php
require_once 'backend/config/database.php';

$database = new Database();
$db = $database->getConnection();

$query = "
SELECT conname, pg_get_constraintdef(c.oid) as def 
FROM pg_constraint c 
WHERE conrelid = 'asignaciones_conductor'::regclass 
AND contype = 'c'
";

$stmt = $db->query($query);
$constraints = $stmt->fetchAll(PDO::FETCH_ASSOC);

echo "Restricciones CHECK en asignaciones_conductor:\n";
print_r($constraints);
