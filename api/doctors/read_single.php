<?php
// --- Headers ---
header("Access-Control-Allow-Origin: *"); // Allow access from any origin (adjust for production)
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET"); // Allow GET method
header("Access-Control-Max-Age: 3600");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

// Enable error reporting for debugging
error_reporting(E_ALL);
ini_set('display_errors', 1);

// --- Include Database Connection ---
$pdo = require_once __DIR__ . '/../../config/db_connect.php'; // Adjust path as needed

// --- Check Request Method ---
if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405); // Method Not Allowed
    echo json_encode(["success" => false, "message" => "Method Not Allowed."]);
    exit;
}

// --- Get Doctor User ID from Query Parameters ---
if (!isset($_GET['user_id']) || empty($_GET['user_id'])) {
    http_response_code(400); // Bad Request
    echo json_encode(["success" => false, "message" => "Identifiant utilisateur du médecin (user_id) requis."]); // Doctor user ID required.
    exit;
}

$user_id = filter_var($_GET['user_id'], FILTER_SANITIZE_NUMBER_INT);

if ($user_id === false) {
    http_response_code(400); // Bad Request
    echo json_encode(["success" => false, "message" => "Identifiant utilisateur du médecin (user_id) invalide."]); // Invalid Doctor user ID.
    exit;
}

// --- Build Query to Get Single Doctor Details ---
// Select data from users, medecins, specialities, and addresses
$query = "SELECT
            u.id AS user_id, u.nom, u.prenom, u.email, u.num_telephone,
            m.cin, m.description, m.is_approved, -- cin is kept
            s.id AS specialite_id, s.nom_specialite,
            a.id AS address_id, a.ville, a.quartier, a.rue
          FROM users u
          INNER JOIN medecins m ON u.id = m.user_id
          INNER JOIN specialities s ON m.specialite_id = s.id
          LEFT JOIN addresses a ON m.address_id = a.id
          WHERE u.id = :user_id -- Filter by the specific user ID
          LIMIT 1"; // Expecting only one result

// --- Execute Query ---
try {
    $stmt = $pdo->prepare($query);
    $stmt->bindParam(':user_id', $user_id);
    $stmt->execute();

    $num = $stmt->rowCount();

    if ($num > 0) {
        // Doctor found
        $row = $stmt->fetch(PDO::FETCH_ASSOC); // Fetch the single row

        // Structure the data for the single doctor
        $doctor_data = [
            "user_id" => (int)$row['user_id'],
            "nom" => $row['nom'],
            "prenom" => $row['prenom'],
            "email" => $row['email'],
            "num_telephone" => $row['num_telephone'],
            // "cin" is included if needed separately, but we are mapping its value to certificate_url
            "description" => $row['description'],
            "is_approved" => (bool)$row['is_approved'], // Cast to boolean
            // Based on "cin هو certificate_url", we map the cin value to the certificate_url key
            "certificate_url" => $row['cin'], // <-- Taking value from 'cin' and naming it 'certificate_url'
            // "profile_picture_url" is removed as the column doesn't exist
            "speciality" => [
                "id" => (int)$row['specialite_id'],
                "nom_specialite" => $row['nom_specialite']
            ],
            "address" => $row['address_id'] ? [ // Include address only if it exists
                "id" => (int)$row['address_id'],
                "ville" => $row['ville'],
                "quartier" => $row['quartier'],
                "rue" => $row['rue']
            ] : null, // Set to null if no address
            // Availability Slots are NOT included here - need a separate call to availability/read.php
        ];

        http_response_code(200); // OK
        echo json_encode(["success" => true, "data" => $doctor_data]); // Return single object

    } else {
        // No doctor found with this ID
        http_response_code(404); // Not Found
        echo json_encode([
            "success" => false,
            "message" => "Médecin non trouvé cet identifiant." // Doctor not found with this ID.
        ]);
    }

} catch (PDOException $e) {
    // Handle database errors
    http_response_code(503); // Service Unavailable
    echo json_encode([
        "success" => false,
        "message" => "Erreur serveur: Impossible de récupérer les détails du médecin. " . $e->getMessage() // Server error: Unable to retrieve doctor details.
    ]);
    // Log the actual error on the server side
    error_log("Get Single Doctor Error: " . $e->getMessage() . " Stack: " . $e->getTraceAsString());
}