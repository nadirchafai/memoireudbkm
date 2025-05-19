<?php
// Ensure error reporting is set once at the beginning
error_reporting(E_ALL);
ini_set('display_errors', 1);

$db_host = "localhost";
$db_name = "db_appointments";
$db_user = "root";
$db_pass = "";
$charset = 'utf8mb4';

$dsn = "mysql:host=$db_host;dbname=$db_name;charset=$charset";

$options = [
    PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION, // Throw exceptions on errors
    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,       // Fetch results as associative arrays
    PDO::ATTR_EMULATE_PREPARES   => false,                  // Use real prepared statements
];

try {
     $pdo = new PDO($dsn, $db_user, $db_pass, $options);
     // --- THIS IS THE CRUCIAL LINE ---
     return $pdo; // <-- Return the PDO object on successful connection
     // ---------------------------------
} catch (\PDOException $e) {
     // If connection fails, set error status, output JSON error, and exit
     http_response_code(500); // Internal Server Error
     echo json_encode([
        "success" => false,
        "message" => "Database connection failed: " . $e->getMessage()
     ]);
     exit; // Stop script execution entirely
}