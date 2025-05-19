<?php
// --- Headers ---
header("Access-Control-Allow-Origin: *"); // Allow access from any origin (adjust for production)
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET"); // Allow GET method
header("Access-Control-Max-Age: 3600");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

// --- Include Database Connection ---
$pdo = require_once __DIR__ . '/../../config/db_connect.php'; // Adjust path as needed

// --- Check Request Method ---
if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405); // Method Not Allowed
    echo json_encode(["success" => false, "message" => "Method Not Allowed"]);
    exit;
}

// --- Get Doctor ID from Query Parameters ---
if (!isset($_GET['medecin_id']) || empty($_GET['medecin_id'])) {
    http_response_code(400); // Bad Request
    echo json_encode(["success" => false, "message" => "Identifiant du médecin (medecin_id) requis."]); // Doctor ID required.
    exit;
}

$medecin_id = filter_var($_GET['medecin_id'], FILTER_SANITIZE_NUMBER_INT);

if ($medecin_id === false) {
    http_response_code(400); // Bad Request
    echo json_encode(["success" => false, "message" => "Identifiant du médecin (medecin_id) invalide."]); // Invalid Doctor ID.
    exit;
}

// --- Build Query to Get Availability ---
// We fetch all general working hours for this doctor
$query = "SELECT
            id, medecin_id, jour_semaine, heure_debut, heure_fin
          FROM horaires_travail
          WHERE medecin_id = :medecin_id
          ORDER BY FIELD(jour_semaine, 'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'), heure_debut ASC"; // Order by day of week then start time

// --- Execute Query ---
try {
    $stmt = $pdo->prepare($query);
    $stmt->bindParam(':medecin_id', $medecin_id);
    $stmt->execute();

    $num = $stmt->rowCount();

    if ($num > 0) {
        // Availability found
        $availability_arr = [];
        $availability_arr["success"] = true;
        $availability_arr["count"] = $num;
        $availability_arr["data"] = [];

        while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
            $availability_item = [
                "id" => (int)$row['id'],
                "medecin_id" => (int)$row['medecin_id'],
                "jour_semaine" => $row['jour_semaine'],
                "heure_debut" => $row['heure_debut'], // TIME format (HH:MM:SS)
                "heure_fin" => $row['heure_fin']      // TIME format (HH:MM:SS)
            ];

            array_push($availability_arr["data"], $availability_item);
        }

        http_response_code(200); // OK
        echo json_encode($availability_arr);

    } else {
        // No availability found for this doctor
        http_response_code(404); // Not Found
        echo json_encode([
            "success" => false,
            "message" => "Aucune disponibilité trouvée pour ce médecin." // No availability found for this doctor.
        ]);
    }

} catch (PDOException $e) {
    // Handle database errors
    http_response_code(503); // Service Unavailable
    echo json_encode([
        "success" => false,
        "message" => "Erreur serveur: Impossible de récupérer les disponibilités. " . $e->getMessage() // Server error: Unable to retrieve availability.
    ]);
    // Optional: Log the actual error $e->getMessage() on the server side
}

?>