<?php
// Ensure error reporting is set once at the beginning of the main script (or included script)
error_reporting(E_ALL);
ini_set('display_errors', 1);

// --- Headers ---
header("Access-Control-Allow-Origin: *"); // Allow access from any origin (adjust for production)
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: POST"); // Allow POST method
header("Access-Control-Max-Age: 3600");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

// --- Include Database Connection ---
// Capture the returned PDO object
$pdo = require_once __DIR__ . '/../../config/db_connect.php';

// --- Add a check here to ensure $pdo is a valid PDO object ---
// This is important in case db_connect.php exited without returning the object (though it should now)
if (!$pdo instanceof PDO) {
    // This case should ideally not be reached if db_connect.php exits on error,
    // but it's a robust fallback check.
    http_response_code(500); // Internal Server Error
    echo json_encode([
       "success" => false,
       "message" => "Erreur interne du serveur: Impossible d'établir la connexion base de données." // More generic error
    ]);
    exit;
}


// --- Get Posted Data ---
// Takes raw data from the request
$data = json_decode(file_get_contents("php://input"));

// --- Basic Validation ---
if (
    empty($data->nom) ||
    empty($data->prenom) ||
    empty($data->email) ||
    empty($data->mot_de_passe) ||
    empty($data->role) ||
    !in_array($data->role, ['patient', 'medecin']) || // Ensure role is valid
    (isset($data->num_telephone) && empty($data->num_telephone)) // Optional phone number validation if provided
    // Add more specific validation as needed (e.g., email format, password strength)
) {
    http_response_code(400); // Bad Request
    echo json_encode(["success" => false, "message" => "Données d'inscription incomplètes ou invalides."]); // Incomplete or invalid registration data.
    exit;
}

// --- Sanitize data (basic example) ---
$nom = htmlspecialchars(strip_tags($data->nom));
$prenom = htmlspecialchars(strip_tags($data->prenom));
$email = filter_var($data->email, FILTER_SANITIZE_EMAIL);
$mot_de_passe = $data->mot_de_passe; // Keep original for hashing
$role = htmlspecialchars(strip_tags($data->role));
$num_telephone = isset($data->num_telephone) ? htmlspecialchars(strip_tags($data->num_telephone)) : null;

// --- Further Validate Email ---
if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Format d'email invalide."]); // Invalid email format.
    exit;
}

// --- Check if Email Already Exists ---
try {
    $query_check = "SELECT id FROM users WHERE email = :email LIMIT 1";
    $stmt_check = $pdo->prepare($query_check);
    $stmt_check->bindParam(':email', $email);
    $stmt_check->execute();

    if ($stmt_check->rowCount() > 0) {
        http_response_code(409); // Conflict
        // Corrected error message output to be consistent JSON
        echo json_encode(["success" => false, "message" => "L'adresse email existe déjà."]); // Email address already exists.
        exit;
    }
} catch (PDOException $e) {
    // Corrected error message output to be consistent JSON
    http_response_code(503); // Service Unavailable
    echo json_encode(["success" => false, "message" => "Erreur lors de la vérification de l'email: " . $e->getMessage()]);
    exit;
}

// --- Hash Password ---
$hashed_password = password_hash($mot_de_passe, PASSWORD_BCRYPT); // Recommended hashing algorithm

// --- Insert User using Transaction ---
// Use transaction to ensure atomicity (all or nothing)
$pdo->beginTransaction();

try {
    // 1. Insert into 'users' table
    $query_user = "INSERT INTO users (nom, prenom, email, num_telephone, mot_de_passe, role)
                   VALUES (:nom, :prenom, :email, :num_telephone, :mot_de_passe, :role)";

    $stmt_user = $pdo->prepare($query_user);

    // Bind parameters
    $stmt_user->bindParam(':nom', $nom);
    $stmt_user->bindParam(':prenom', $prenom);
    $stmt_user->bindParam(':email', $email);
    $stmt_user->bindParam(':num_telephone', $num_telephone);
    $stmt_user->bindParam(':mot_de_passe', $hashed_password);
    $stmt_user->bindParam(':role', $role);

    if (!$stmt_user->execute()) {
        // This should be caught by PDOException due to ATTR_ERRMODE_EXCEPTION
        // but as a fallback:
        throw new Exception("Erreur lors de la création de l'utilisateur."); // Error creating user.
    }

    // Get the ID of the newly created user
    $user_id = $pdo->lastInsertId();

    // 2. Insert into 'patients' or 'medecins' table based on role
    if ($role === 'patient') {
        // Potentially get CIN, CNSS, date_naissance from $data if provided
        $cin_patient = isset($data->cin) ? htmlspecialchars(strip_tags($data->cin)) : null;
        $cnss_patient = isset($data->cnss) ? htmlspecialchars(strip_tags($data->cnss)) : null;
        $date_naissance = isset($data->date_naissance) ? $data->date_naissance : null; // Add validation for date format

        $query_patient = "INSERT INTO patients (user_id, cin, cnss, date_naissance) VALUES (:user_id, :cin, :cnss, :date_naissance)";
        $stmt_patient = $pdo->prepare($query_patient);
        $stmt_patient->bindParam(':user_id', $user_id);
        $stmt_patient->bindParam(':cin', $cin_patient);
        $stmt_patient->bindParam(':cnss', $cnss_patient);
        $stmt_patient->bindParam(':date_naissance', $date_naissance);
        // Removed duplicate error reporting lines here

        if (!$stmt_patient->execute()) {
             throw new Exception("Erreur lors de la création du profil patient."); // Error creating patient profile.
        }

    } elseif ($role === 'medecin') {
        // Potentially get CIN, description, address_id, specialite_id from $data if provided
        $cin_medecin = isset($data->cin) ? htmlspecialchars(strip_tags($data->cin)) : null;
        $description = isset($data->description) ? htmlspecialchars(strip_tags($data->description)) : null;
        // Ensure address_id and specialite_id are treated as potential INTs
        $address_id = isset($data->address_id) && $data->address_id !== null ? filter_var($data->address_id, FILTER_VALIDATE_INT) : null;
        $specialite_id = isset($data->specialite_id) && $data->specialite_id !== null ? filter_var($data->specialite_id, FILTER_VALIDATE_INT) : null;


        // You MUST ensure specialite_id is provided and valid for a doctor
        if ($specialite_id === null || $specialite_id === false) { // Check if it's null or failed validation
             // Throwing an exception is better than echoing and exiting within a transaction try block
             throw new Exception("L'ID de spécialité est requis et doit être un nombre valide pour un médecin."); // Speciality ID is required and must be a valid number for a doctor.
        }
        // You might want to check if the specialite_id actually exists in the specialities table (advanced)

        $query_medecin = "INSERT INTO medecins (user_id, cin, description, address_id, specialite_id, is_approved)
                           VALUES (:user_id, :cin, :description, :address_id, :specialite_id, 0)"; // Default is_approved to 0
        $stmt_medecin = $pdo->prepare($query_medecin);
        $stmt_medecin->bindParam(':user_id', $user_id);
        $stmt_medecin->bindParam(':cin', $cin_medecin);
        $stmt_medecin->bindParam(':description', $description);
        // Bind address_id: use PDO::PARAM_INT for potential null value
        $stmt_medecin->bindParam(':address_id', $address_id, PDO::PARAM_INT);
        $stmt_medecin->bindParam(':specialite_id', $specialite_id);

         if (!$stmt_medecin->execute()) {
             throw new Exception("Erreur lors de la création du profil médecin."); // Error creating doctor profile.
        }
    }

    // If all insertions were successful, commit the transaction
    $pdo->commit();

    http_response_code(201); // Created
    echo json_encode(["success" => true, "message" => "Utilisateur enregistré avec succès."]); // User registered successfully.

} catch (Exception $e) {
    // If any error occurred, roll back the transaction
    // Make sure rollback is called only if transaction was started
    if ($pdo->inTransaction()) {
         $pdo->rollBack();
    }


    http_response_code(503); // Service Unavailable or specific error code
    // Log the error on the server side (essential for debugging in production)
    error_log("Registration Error: " . $e->getMessage() . " Stack: " . $e->getTraceAsString());
    // Return a generic or specific error message to the client
    echo json_encode(["success" => false, "message" => "Erreur lors de la prise de rendez-vous: " . $e->getMessage()]); // Send specific error to client for debugging
    // In production, send a generic message:
    // echo json_encode(["success" => false, "message" => "Une erreur s'est produite lors de l'enregistrement."]);
}

// No closing ?> tag is needed