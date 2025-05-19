<?php
// --- Headers ---
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: POST");
header("Access-Control-Max-Age: 3600");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

// Enable error reporting for debugging
error_reporting(E_ALL);
ini_set('display_errors', 1);

// --- Include Database Connection ---
$pdo = require_once __DIR__ . '/../../config/db_connect.php';

// --- Check Request Method ---
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405); // Method Not Allowed
    echo json_encode(["success" => false, "message" => "Method Not Allowed."]);
    exit;
}

// --- Get Posted Data ---
$data = json_decode(file_get_contents("php://input"));

// --- Basic Validation ---
// TODO: Add authentication to ensure only the specific patient can rate their appointment.
// For now, we assume patient_id is sent and validated against the appointment.

if (
    empty($data->rendezvous_id) ||
    empty($data->patient_id) ||    // TEMPORARY: Should come from authenticated patient token and validated
    empty($data->medecin_id) ||    // This can be fetched from rendezvous_id if needed, but good to have for double check
    !isset($data->note) || !is_numeric($data->note) // Note must be present and numeric
    // commentaire is optional
) {
    http_response_code(400); // Bad Request
    echo json_encode(["success" => false, "message" => "Données d'évaluation incomplètes ou invalides. rendezvous_id, patient_id, medecin_id, et note (numérique) sont requis."]);
    exit;
}

// Sanitize data
$rendezvous_id = filter_var($data->rendezvous_id, FILTER_SANITIZE_NUMBER_INT);
$patient_id_from_request = filter_var($data->patient_id, FILTER_SANITIZE_NUMBER_INT); // TEMPORARY
$medecin_id_from_request = filter_var($data->medecin_id, FILTER_SANITIZE_NUMBER_INT);
$note = filter_var($data->note, FILTER_SANITIZE_NUMBER_INT);
$commentaire = isset($data->commentaire) ? htmlspecialchars(strip_tags($data->commentaire)) : null;

// Validate note range (e.g., 1 to 5)
if ($note < 1 || $note > 5) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "La note doit être entre 1 et 5."]); // Rating must be between 1 and 5.
    exit;
}


// --- Insert Evaluation ---
try {
    // 1. Verify the appointment exists, is 'termine', and belongs to this patient and doctor
    $query_check_rdv = "SELECT id, patient_id, medecin_id, statut FROM rendezvous
                        WHERE id = :rendezvous_id
                        AND patient_id = :patient_id_req
                        AND medecin_id = :medecin_id_req
                        LIMIT 1";
    $stmt_check_rdv = $pdo->prepare($query_check_rdv);
    $stmt_check_rdv->bindParam(':rendezvous_id', $rendezvous_id, PDO::PARAM_INT);
    $stmt_check_rdv->bindParam(':patient_id_req', $patient_id_from_request, PDO::PARAM_INT); // TEMPORARY check
    $stmt_check_rdv->bindParam(':medecin_id_req', $medecin_id_from_request, PDO::PARAM_INT);
    $stmt_check_rdv->execute();

    $appointment = $stmt_check_rdv->fetch(PDO::FETCH_ASSOC);

    if (!$appointment) {
        http_response_code(404);
        echo json_encode(["success" => false, "message" => "Rendez-vous non trouvé ou ne correspond pas aux identifiants fournis."]); // Appointment not found or doesn't match provided IDs.
        exit;
    }

    // Optional: Check if the appointment status is 'termine' before allowing evaluation
    // if ($appointment['statut'] !== 'termine') {
    //     http_response_code(403); // Forbidden
    //     echo json_encode(["success" => false, "message" => "Ce rendez-vous ne peut pas encore être évalué."]); // This appointment cannot be rated yet.
    //     exit;
    // }

    // 2. Check if this appointment has already been evaluated (rendezvous_id is UNIQUE in evaluations table)
    // This will be caught by the database unique constraint, but we can check it here for a friendlier message.
    $query_check_eval = "SELECT id FROM evaluations WHERE rendezvous_id = :rendezvous_id LIMIT 1";
    $stmt_check_eval = $pdo->prepare($query_check_eval);
    $stmt_check_eval->bindParam(':rendezvous_id', $rendezvous_id, PDO::PARAM_INT);
    $stmt_check_eval->execute();

    if ($stmt_check_eval->rowCount() > 0) {
        http_response_code(409); // Conflict
        echo json_encode(["success" => false, "message" => "Ce rendez-vous a déjà été évalué."]); // This appointment has already been rated.
        exit;
    }


    // 3. Proceed to insert the evaluation
    $query_insert = "INSERT INTO evaluations (rendezvous_id, patient_id, medecin_id, note, commentaire, date_evaluation)
                     VALUES (:rendezvous_id, :patient_id, :medecin_id, :note, :commentaire, NOW())";
    $stmt_insert = $pdo->prepare($query_insert);

    $stmt_insert->bindParam(':rendezvous_id', $rendezvous_id, PDO::PARAM_INT);
    $stmt_insert->bindParam(':patient_id', $patient_id_from_request, PDO::PARAM_INT); // Use patient_id from request (should be authenticated user)
    $stmt_insert->bindParam(':medecin_id', $medecin_id_from_request, PDO::PARAM_INT); // Use medecin_id from request (linked to rendezvous)
    $stmt_insert->bindParam(':note', $note, PDO::PARAM_INT);
    $stmt_insert->bindParam(':commentaire', $commentaire);

    if ($stmt_insert->execute()) {
        http_response_code(201); // Created
        echo json_encode(["success" => true, "message" => "Évaluation ajoutée avec succès."]); // Evaluation added successfully.
    } else {
        http_response_code(500); // Internal Server Error
        echo json_encode(["success" => false, "message" => "Impossible d'ajouter l'évaluation."]); // Failed to add evaluation.
    }

} catch (PDOException $e) {
    // Check for unique constraint violation specifically (error code 23000 for MySQL)
    if ($e->getCode() == '23000') {
        http_response_code(409); // Conflict
        echo json_encode(["success" => false, "message" => "Ce rendez-vous a déjà été évalué (contrainte de base de données)."]); // This appointment has already been rated (DB constraint).
    } else {
        http_response_code(503); // Service Unavailable
        echo json_encode(["success" => false, "message" => "Erreur serveur: " . $e->getMessage()]);
    }
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Une erreur inattendue est survenue: " . $e->getMessage()]);
}