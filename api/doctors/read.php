<?php
// --- Headers ---
header("Access-Control-Allow-Origin: *"); // Allow access from any origin (adjust for production)
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET"); // Allow GET method
header("Access-Control-Max-Age: 3600");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

// Enable error reporting for debugging (Optional in production, but keep for now)
error_reporting(E_ALL); // Add this line
ini_set('display_errors', 1); // Add this line


// --- Include Database Connection ---
// Assumes db_connect.php returns the PDO object and has no premature output
$pdo = require_once __DIR__ . '/../../config/db_connect.php'; // Adjust path as needed


// --- Check Request Method ---
if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405); // Method Not Allowed
    echo json_encode(["success" => false, "message" => "Method Not Allowed"]);
    exit;
}

// --- Build Query ---
$query = "SELECT
            u.id AS user_id, u.nom, u.prenom, u.email, u.num_telephone,
            m.cin, m.description, m.is_approved,
            s.id AS specialite_id, s.nom_specialite,
            a.id AS address_id, a.ville, a.quartier, a.rue
          FROM users u
          INNER JOIN medecins m ON u.id = m.user_id
          INNER JOIN specialities s ON m.specialite_id = s.id
          LEFT JOIN addresses a ON m.address_id = a.id";

// --- Add Filters (Optional) ---
$where_clauses = [];
$params = [];

// Filter by Speciality ID
if (isset($_GET['speciality_id']) && !empty($_GET['speciality_id'])) {
    $speciality_id = filter_var($_GET['speciality_id'], FILTER_SANITIZE_NUMBER_INT);
    if ($speciality_id !== false) {
        $where_clauses[] = "s.id = :speciality_id";
        $params[':speciality_id'] = $speciality_id;
    }
}

// Filter by Search Keyword (basic example: search in name, specialty, city)
if (isset($_GET['search']) && !empty($_GET['search'])) {
    $search_term = "%" . htmlspecialchars(strip_tags($_GET['search'])) . "%";
    $where_clauses[] = "(u.nom LIKE :search OR u.prenom LIKE :search OR s.nom_specialite LIKE :search OR a.ville LIKE :search)";
    $params[':search'] = $search_term;
}

// Add WHERE clause if filters exist
if (!empty($where_clauses)) {
    $query .= " WHERE " . implode(" AND ", $where_clauses);
}

// --- Add Ordering ---
$query .= " ORDER BY u.nom ASC, u.prenom ASC"; // Order by last name, then first name

// --- Execute Query ---
try {
    $stmt = $pdo->prepare($query);

    // Bind parameters for filters
    // Pass by reference required for bindParam in foreach loop before PHP 8.0
    // If using PHP 8.0+, you can remove &
    foreach ($params as $param_name => &$param_value) {
        $stmt->bindParam($param_name, $param_value);
    }


    $stmt->execute();

    $num = $stmt->rowCount();

    if ($num > 0) {
        // Doctors found
        $doctors_arr = [];
        $doctors_arr["success"] = true;
        $doctors_arr["count"] = $num; // Optional: number of results
        $doctors_arr["data"] = [];

        while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
            // Extracting data for doctor item
            $doctor_item = [
                "user_id" => (int)$row['user_id'], // Cast to int for Flutter
                "nom" => $row['nom'],
                "prenom" => $row['prenom'],
                "email" => $row['email'], // Consider if email/phone should be public
                "num_telephone" => $row['num_telephone'],
                "cin" => $row['cin'], // Consider if CIN should be public
                "description" => $row['description'],
                "is_approved" => (bool)$row['is_approved'], // Cast to boolean
                // Assuming certificate_url and profile_picture_url might not exist or need mapping from CIN
                // "certificate_url" => $row['certificate_url'],
                // "profile_picture_url" => $row['profile_picture_url'],
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
                // Note: Availability Slots are NOT included here. Need separate endpoint or join.
            ];

            array_push($doctors_arr["data"], $doctor_item);
        }

        http_response_code(200); // OK
        echo json_encode($doctors_arr);

    } else {
        // No doctors found
        http_response_code(404); // Not Found
        echo json_encode([
            "success" => false,
            "message" => "Aucun médecin trouvé." // No doctors found.
        ]);
    }
} catch (PDOException $e) {
    // Handle database errors
    http_response_code(503); // Service Unavailable
    echo json_encode([
        "success" => false,
        "message" => "Erreur serveur: Impossible de récupérer la liste des médecins. " . $e->getMessage() // Server error: Unable to retrieve doctors list.
    ]);
    // Optional: Log the actual error $e->getMessage() on the server side
    // error_log("Get Doctors Error: " . $e->getMessage() . " Stack: " . $e->getTraceAsString());
}
