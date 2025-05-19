<?php
// --- Headers ---
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: POST, PUT"); // Allow POST or PUT
header("Access-Control-Max-Age: 3600");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

// Enable error reporting for debugging
error_reporting(E_ALL);
ini_set('display_errors', 1);

// --- Include Database Connection ---
$pdo = require_once __DIR__ . '/../../config/db_connect.php';

// --- Check Request Method ---
if ($_SERVER['REQUEST_METHOD'] !== 'POST' && $_SERVER['REQUEST_METHOD'] !== 'PUT') {
    http_response_code(405); // Method Not Allowed
    echo json_encode(["success" => false, "message" => "Method Not Allowed. Use POST or PUT."]);
    exit;
}

// --- Get Posted Data ---
$data = json_decode(file_get_contents("php://input"));

// --- Basic Validation ---
// TODO: Add authentication to ensure only the specific doctor can update their appointments.
// For now, we will assume medecin_id is sent for validation, but it should come from auth token.

if (
    empty($data->appointment_id) ||
    empty($data->new_status) ||
    empty($data->medecin_id) // TEMPORARY: For validation, should come from authenticated doctor token
) {
    http_response_code(400); // Bad Request
    echo json_encode(["success" => false, "message" => "Données incomplètes: appointment_id, new_status et medecin_id (temporaire) sont requis."]);
    exit;
}

// Sanitize data
$appointment_id = filter_var($data->appointment_id, FILTER_SANITIZE_NUMBER_INT);
$new_status = htmlspecialchars(strip_tags($data->new_status));
$medecin_id_from_request = filter_var($data->medecin_id, FILTER_SANITIZE_NUMBER_INT); // TEMPORARY


// Validate new_status (ensure it's one of the allowed values for a doctor to set)
$allowed_doctor_statuses = ['confirme', 'annule_medecin', 'termine']; // Doctor can confirm, cancel, or mark as finished
if (!in_array($new_status, $allowed_doctor_statuses)) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Statut invalide fourni par le médecin."]); // Invalid status provided by doctor.
    exit;
}

// --- Update Appointment Status ---
// First, verify the appointment exists and belongs to this doctor (TEMPORARY check)
// In a real app, the medecin_id check would be based on the authenticated user's ID from token.
try {
    $query_check = "SELECT id, medecin_id, statut FROM rendezvous WHERE id = :appointment_id AND medecin_id = :medecin_id_request LIMIT 1";
    $stmt_check = $pdo->prepare($query_check);
    $stmt_check->bindParam(':appointment_id', $appointment_id, PDO::PARAM_INT);
    $stmt_check->bindParam(':medecin_id_request', $medecin_id_from_request, PDO::PARAM_INT); // TEMPORARY
    $stmt_check->execute();

    $appointment = $stmt_check->fetch(PDO::FETCH_ASSOC);

    if (!$appointment) {
        http_response_code(404); // Not Found or Forbidden (if doctor ID mismatch)
        echo json_encode(["success" => false, "message" => "Rendez-vous non trouvé ou n'appartient pas à ce médecin."]); // Appointment not found or doesn't belong to this doctor.
        exit;
    }

    // Optional: Add logic to prevent updating status if already 'termine' or 'annule_xxx'
    // For example, if ($appointment['statut'] === 'termine' || $appointment['statut'] === 'annule_medecin' || $appointment['statut'] === 'annule_patient') { ... }


    // Proceed to update the status
    $query_update = "UPDATE rendezvous SET statut = :new_status WHERE id = :appointment_id";
    $stmt_update = $pdo->prepare($query_update);

    $stmt_update->bindParam(':new_status', $new_status);
    $stmt_update->bindParam(':appointment_id', $appointment_id, PDO::PARAM_INT);

    if ($stmt_update->execute()) {
        if ($stmt_update->rowCount() > 0) {
            http_response_code(200); // OK
            echo json_encode(["success" => true, "message" => "Statut du rendez-vous mis à jour avec succès."]); // Appointment status updated successfully.
        } else {
            // No rows affected, maybe status was already the same or ID was wrong (though checked above)
            http_response_code(200); // Still OK, but no change made
            echo json_encode(["success" => true, "message" => "Aucune modification apportée, le statut est peut-être déjà le même."]); // No change made, status might be the same.
        }
    } else {
        // Should not happen with exceptions enabled usually
        http_response_code(500); // Internal Server Error
        echo json_encode(["success" => false, "message" => "Impossible de mettre à jour le statut du rendez-vous."]); // Failed to update appointment status.
    }

} catch (PDOException $e) {
    http_response_code(503); // Service Unavailable
    echo json_encode(["success" => false, "message" => "Erreur serveur: " . $e->getMessage()]);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Une erreur inattendue est survenue: " . $e->getMessage()]);
}