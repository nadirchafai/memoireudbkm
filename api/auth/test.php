<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);
echo "Test file works!";
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    echo " This was a POST request.";
    $data = json_decode(file_get_contents("php://input"));
     if ($data) {
        echo " Received data: " . json_encode($data);
     }
} else {
    echo " This was NOT a POST request.";
}