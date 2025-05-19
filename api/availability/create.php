<?php
// --- Headers ---
header("Access-Control-Allow-Origin: *"); // Allow access from any origin (adjust for production)
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: POST"); // Allow POST method
header("Access-Control-Max-Age: 3600");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

// --- Include Database Connection ---
$pdo = require_once __DIR__ . '/../../config/db_connect.php'; // Adjust path as needed

// --- Check Request Method ---
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405); // Method Not Allowed
    echo json_encode(["success" => false, "message" => "Method Not Allowed."]);
    exit;
}

// --- Get Posted Data ---
$data = json_decode(file_get_contents("php://input"));

// --- Basic Validation ---
// Temporarily require medecin_id in the request body for testing.
// In a real app, GET doctor_id from the authenticated user's session/token.
if (
    empty($data->medecin_id) || // TEMPORARY: Should come from auth
    empty($data->jour_semaine) ||
    empty($data->heure_debut) ||
    empty($data->heure_fin)
) {
    http_response_code(400); // Bad Request
    echo json_encode(["success" => false, "message" => "Données d'horaire incomplètes."]); // Incomplete availability data.
    exit;
}

// --- Sanitize and Validate Data ---
$medecin_id = filter_var($data->medecin_id, FILTER_SANITIZE_NUMBER_INT); // TEMPORARY
$jour_semaine = htmlspecialchars(strip_tags($data->jour_semaine));
$heure_debut = htmlspecialchars(strip_tags($data->heure_debut));
$heure_fin = htmlspecialchars(strip_tags($data->heure_fin));

// Validate medecin_id (basic check)
if ($medecin_id === false) {
     http_response_code(400);
     echo json_encode(["success" => false, "message" => "Identifiant du médecin (medecin_id) invalide."]);
     exit;
}

// Validate day of week
$allowed_days = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
if (!in_array($jour_semaine, $allowed_days)) {
    http_response_code(400); // Bad Request
    echo json_encode(["success" => false, "message" => "Jour de la semaine invalide."]); // Invalid day of week.
    exit;
}

// Validate time format and order (simple string comparison assuming HH:MM:SS)
// A more robust check would parse time, but string comparison works for this format
if (strtotime($heure_debut) === false || strtotime($heure_fin) === false || $heure_debut >= $heure_fin) {
     http_response_code(400); // Bad Request
     echo json_encode(["success" => false, "message" => "Format d'heure invalide ou heure de début >= heure de fin."]); // Invalid time format or start time >= end time.
     exit;
}


// --- Insert into Database ---
$query = "INSERT INTO horaires_travail (medecin_id, jour_semaine, heure_debut, heure_fin)
          VALUES (:medecin_id, :jour_semaine, :heure_debut, :heure_fin)";

try {
    $stmt = $pdo->prepare($query);

    // Bind parameters
    $stmt->bindParam(':medecin_id', $medecin_id);
    $stmt->bindParam(':jour_semaine', $jour_semaine);
    $stmt->bindParam(':heure_debut', $heure_debut);
    $stmt->bindParam(':heure_fin', $heure_fin);

    // Execute query
    if ($stmt->execute()) {
        // Get the ID of the newly inserted record
        $new_availability_id = $pdo->lastInsertId();

        http_response_code(201); // Created
        echo json_encode([
            "success" => true,
            "message" => "Horaire ajouté avec succès.", // Availability added successfully.
            "id" => $new_availability_id // Return the new ID
        ]);
    } else {
        // Should not happen with exceptions enabled, but good fallback
         http_response_code(500); // Internal Server Error
         echo json_encode(["success" => false, "message" => "Impossible d'ajouter l'horaire."]); // Failed to add availability.
    }

} catch (PDOException $e) {
    // Handle database errors (e.g., duplicate entry if unique constraint added later)
    http_response_code(503); // Service Unavailable
    echo json_encode([
        "success" => false,
        "message" => "Erreur serveur: Impossible d'ajouter l'horaire. " . $e->getMessage() // Server error: Failed to add availability.
    ]);
    // Optional: Log the actual error $e->getMessage() on the server side
}

?>