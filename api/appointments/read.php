<?php
// --- Headers ---
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET");
header("Access-Control-Max-Age: 3600");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

// Enable error reporting for debugging
error_reporting(E_ALL);
ini_set('display_errors', 1);

// --- Include Database Connection ---
$pdo = require_once __DIR__ . '/../../config/db_connect.php';

// --- Check Request Method ---
if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode(["success" => false, "message" => "Method Not Allowed."]);
    exit;
}

// --- Get User ID from Query Parameters ---
if (!isset($_GET['user_id']) || empty($_GET['user_id'])) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Identifiant utilisateur (user_id) requis."]);
    exit;
}

$user_id = filter_var($_GET['user_id'], FILTER_SANITIZE_NUMBER_INT);

if ($user_id === false) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Identifiant utilisateur (user_id) invalide."]);
    exit;
}

// --- Get User Role ---
try {
    $query_user_role = "SELECT role FROM users WHERE id = :user_id LIMIT 1";
    $stmt_user_role = $pdo->prepare($query_user_role);
    $stmt_user_role->bindParam(':user_id', $user_id, PDO::PARAM_INT);
    $stmt_user_role->execute();

    if ($stmt_user_role->rowCount() == 0) {
        http_response_code(404);
        echo json_encode(["success" => false, "message" => "Utilisateur non trouvé."]);
        exit;
    }

    $user_role = $stmt_user_role->fetchColumn();

    if ($user_role !== 'patient' && $user_role !== 'medecin') {
         http_response_code(403);
         echo json_encode(["success" => false, "message" => "Accès refusé pour ce rôle d'utilisateur."]);
         exit;
    }

} catch (PDOException $e) {
    http_response_code(503);
    echo json_encode(["success" => false, "message" => "Erreur serveur lors de la vérification du rôle: " . $e->getMessage()]);
    exit;
}


// --- Build Query to Get Appointments based on Role ---
$query = "";
$select_fields = "r.id, r.date_rendezvous, r.statut, r.notes_patient"; // Common fields

if ($user_role === 'patient') {
    // Query for Patient: Get appointments with doctor details
    $query = "SELECT $select_fields,
                m.user_id AS medecin_user_id, u_medecin.nom AS medecin_nom, u_medecin.prenom AS medecin_prenom,
                s.id AS specialite_id, s.nom_specialite
              FROM rendezvous r
              INNER JOIN users u_medecin ON r.medecin_id = u_medecin.id
              INNER JOIN medecins m ON u_medecin.id = m.user_id
              INNER JOIN specialities s ON m.specialite_id = s.id
              WHERE r.patient_id = :user_id
              ORDER BY r.date_rendezvous DESC";

} elseif ($user_role === 'medecin') {
    // Query for Doctor: Get appointments with patient details
     $query = "SELECT $select_fields,
                p.user_id AS patient_user_id, u_patient.nom AS patient_nom, u_patient.prenom AS patient_prenom, u_patient.num_telephone AS patient_num_telephone
              FROM rendezvous r
              INNER JOIN users u_patient ON r.patient_id = u_patient.id
              INNER JOIN patients p ON u_patient.id = p.user_id
              WHERE r.medecin_id = :user_id
              ORDER BY r.date_rendezvous DESC";
}

// --- Execute Query ---
try {
    $stmt = $pdo->prepare($query);
    $stmt->bindParam(':user_id', $user_id, PDO::PARAM_INT);
    $stmt->execute();

    $num = $stmt->rowCount();

    if ($num > 0) {
        $appointments_arr = [];
        $appointments_arr["success"] = true;
        $appointments_arr["count"] = $num;
        $appointments_arr["data"] = [];

        while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
            $appointment_item = [
                "id" => (int)$row['id'],
                "date_rendezvous" => $row['date_rendezvous'],
                "statut" => $row['statut'],
                "notes_patient" => $row['notes_patient'],
            ];

            if ($user_role === 'patient' && isset($row['medecin_nom'])) {
                 $appointment_item['medecin'] = [
                     "user_id" => (int)$row['medecin_user_id'],
                     "nom" => $row['medecin_nom'],
                     "prenom" => $row['medecin_prenom'],
                     "specialite" => [
                         "id" => (int)$row['specialite_id'],
                         "nom_specialite" => $row['nom_specialite']
                     ]
                 ];
            } elseif ($user_role === 'medecin' && isset($row['patient_nom'])) {
                  $appointment_item['patient'] = [
                     "user_id" => (int)$row['patient_user_id'],
                     "nom" => $row['patient_nom'],
                     "prenom" => $row['patient_prenom'],
                     "num_telephone" => $row['patient_num_telephone']
                  ];
            }
            array_push($appointments_arr["data"], $appointment_item);
        }
        http_response_code(200);
        echo json_encode($appointments_arr);
    } else {
        http_response_code(404);
        echo json_encode(["success" => false, "message" => "Aucun rendez-vous trouvé pour cet utilisateur."]);
    }
} catch (PDOException $e) {
    http_response_code(503);
    echo json_encode(["success" => false, "message" => "Erreur serveur: Impossible de récupérer les rendez-vous. " . $e->getMessage()]);
}