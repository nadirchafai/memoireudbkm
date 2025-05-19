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
// Temporarily require patient_id and medecin_id in request body for testing.
// In a real app, patient_id should come from authenticated user, medecin_id/date from request.
if (
    empty($data->patient_id) || // TEMPORARY: Should come from auth
    empty($data->medecin_id) ||
    empty($data->date_rendezvous)
    // notes_patient is optional
) {
    http_response_code(400); // Bad Request
    echo json_encode(["success" => false, "message" => "Données de rendez-vous incomplètes."]); // Incomplete appointment data.
    exit;
}

// --- Sanitize and Validate Data ---
$patient_id = filter_var($data->patient_id, FILTER_SANITIZE_NUMBER_INT); // TEMPORARY
$medecin_id = filter_var($data->medecin_id, FILTER_SANITIZE_NUMBER_INT);
$date_rendezvous_str = htmlspecialchars(strip_tags($data->date_rendezvous));
$notes_patient = isset($data->notes_patient) ? htmlspecialchars(strip_tags($data->notes_patient)) : null;

// Validate IDs (basic check)
if ($patient_id === false || $medecin_id === false) {
     http_response_code(400);
     echo json_encode(["success" => false, "message" => "Identifiants patient ou médecin invalides."]); // Invalid patient or doctor ID.
     exit;
}

// Validate date_rendezvous format and if it's in the future
// Assuming DATETIME format like "YYYY-MM-DD HH:MM:SS"
$date_rendezvous = DateTime::createFromFormat('Y-m-d H:i:s', $date_rendezvous_str);
$now = new DateTime();

if ($date_rendezvous === false || $date_rendezvous < $now) {
    http_response_code(400); // Bad Request
    echo json_encode(["success" => false, "message" => "Date ou format de rendez-vous invalide ou passé."]); // Invalid or past appointment date/format.
    exit;
}

// Convert DateTime object back to string for database (optional, PDO can handle DateTime)
$date_rendezvous_db = $date_rendezvous->format('Y-m-d H:i:s');


// --- Check if Patient and Doctor exist ---
try {
    $query_check_users = "SELECT id, role FROM users WHERE id IN (:patient_id, :medecin_id)";
    $stmt_check_users = $pdo->prepare($query_check_users);
    $stmt_check_users->bindParam(':patient_id', $patient_id);
    $stmt_check_users->bindParam(':medecin_id', $medecin_id);
    $stmt_check_users->execute();

    $found_users = $stmt_check_users->fetchAll(PDO::FETCH_ASSOC);

    $patient_found = false;
    $medecin_found = false;
    foreach ($found_users as $user) {
        if ($user['id'] == $patient_id && $user['role'] === 'patient') {
            $patient_found = true;
        }
        if ($user['id'] == $medecin_id && $user['role'] === 'medecin') {
            $medecin_found = true;
        }
    }

    if (!$patient_found || !$medecin_found) {
         http_response_code(404); // Not Found
         echo json_encode(["success" => false, "message" => "Patient ou Médecin non trouvé."]); // Patient or Doctor not found.
         exit;
    }

} catch (PDOException $e) {
    http_response_code(503); // Service Unavailable
    echo json_encode(["success" => false, "message" => "Erreur serveur lors de la vérification des utilisateurs."]);
    exit;
}


// --- Check for Appointment Conflict ---
// This is a basic check: does any existing appointment for this doctor overlap with the requested time?
// Assuming appointments have a fixed duration (e.g., 30 mins, adjust logic if needed)
// For simplicity now, let's assume the requested date_rendezvous is the START time and conflicts if *any* existing appointment's start time is the same.
// A more robust check would verify if the *requested slot* overlaps with any *existing slot*.
// Let's start with checking for an exact match or very close proximity (e.g., within a few minutes) for simplicity.
// A better approach is to define appointment duration and check for overlap intervals.

// Basic check: is there an existing appointment at the exact requested time for this doctor?
$query_check_conflict = "SELECT id FROM rendezvous
                         WHERE medecin_id = :medecin_id AND date_rendezvous = :date_rendezvous
                         LIMIT 1"; // Basic exact time check
                         
// Advanced check (conceptual - requires known duration, e.g., 30 minutes):
// $appointment_duration = '30 MINUTE'; // Define duration
// $query_check_conflict = "SELECT id FROM rendezvous
//                          WHERE medecin_id = :medecin_id
//                          AND (
//                              (date_rendezvous <= :requested_start_time AND date_add(date_rendezvous, INTERVAL $appointment_duration) > :requested_start_time) OR -- existing starts before and ends after requested start
//                              (date_rendezvous < date_add(:requested_start_time, INTERVAL $appointment_duration) AND date_add(date_rendezvous, INTERVAL $appointment_duration) >= date_add(:requested_start_time, INTERVAL $appointment_duration)) OR -- existing starts before requested end and ends after requested end
//                              (date_rendezvous >= :requested_start_time AND date_add(date_rendezvous, INTERVAL $appointment_duration) <= date_add(:requested_start_time, INTERVAL $appointment_duration)) -- existing is completely within requested
//                              OR (date_rendezvous <= :requested_start_time AND date_add(date_rendezvous, INTERVAL $appointment_duration) >= date_add(:requested_start_time, INTERVAL $appointment_duration)) -- requested is completely within existing
//                          )";
// Note: The advanced check logic is complex and needs careful implementation.

try {
    $stmt_check_conflict = $pdo->prepare($query_check_conflict);
    $stmt_check_conflict->bindParam(':medecin_id', $medecin_id);
    $stmt_check_conflict->bindParam(':date_rendezvous', $date_rendezvous_db); // Use formatted string
    $stmt_check_conflict->execute();

    if ($stmt_check_conflict->rowCount() > 0) {
        // Conflict found
        http_response_code(409); // Conflict
        echo json_encode(["success" => false, "message" => "L'heure demandée non disponible."]); // Requested time not available.
        exit;
    }
} catch (PDOException $e) {
    http_response_code(503); // Service Unavailable
    echo json_encode(["success" => false, "message" => "Erreur serveur lors de la vérification du conflit d'horaire."]);
    exit;
}

// --- Check against general working hours (Optional but recommended) ---
// This check verifies if the requested slot START TIME falls within any of the doctor's defined working hours for that specific day of the week.
// You need to determine the day of the week from $date_rendezvous.
// You'll need to fetch the doctor's working hours for that day and check if the requested time is within any of the time ranges.
// This adds more complexity and can be implemented after the basic conflict check works.


// --- Insert Appointment using Transaction ---
// Use transaction to ensure atomicity
$pdo->beginTransaction();

try {
    $query_insert = "INSERT INTO rendezvous (patient_id, medecin_id, date_rendezvous, statut, notes_patient)
                     VALUES (:patient_id, :medecin_id, :date_rendezvous, 'demande', :notes_patient)";

    $stmt_insert = $pdo->prepare($query_insert);

    $stmt_insert->bindParam(':patient_id', $patient_id);
    $stmt_insert->bindParam(':medecin_id', $medecin_id);
    $stmt_insert->bindParam(':date_rendezvous', $date_rendezvous_db);
    $stmt_insert->bindParam(':notes_patient', $notes_patient);

    if ($stmt_insert->execute()) {
        $new_appointment_id = $pdo->lastInsertId();
        $pdo->commit(); // Commit transaction

        http_response_code(201); // Created
        echo json_encode([
            "success" => true,
            "message" => "Rendez-vous demandé avec succès.", // Appointment requested successfully.
            "id" => $new_appointment_id
        ]);
    } else {
         throw new Exception("Impossible d'insérer le rendez-vous."); // Should not happen with exceptions
    }

} catch (Exception $e) {
    // Roll back transaction on error
    $pdo->rollBack();

    http_response_code(503); // Service Unavailable or relevant error code
    echo json_encode(["success" => false, "message" => "Erreur lors de la prise de rendez-vous: " . $e->getMessage()]); // Error booking appointment.
}

?>