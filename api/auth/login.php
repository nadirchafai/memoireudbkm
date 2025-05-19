<?php
// --- Headers ---
header("Access-Control-Allow-Origin: *"); // Allow access from any origin (adjust for production)
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: POST"); // Allow POST method
header("Access-Control-Max-Age: 3600");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

// Enable error reporting for debugging (keep enabled during development)
error_reporting(E_ALL);
ini_set('display_errors', 1);

// --- Include Database Connection ---
$pdo = require_once __DIR__ . '/../../config/db_connect.php'; // Adjust path as needed

// --- Get Posted Data ---
$data = json_decode(file_get_contents("php://input"));

// --- Basic Validation ---
if (
    empty($data->email) ||
    empty($data->mot_de_passe)
) {
    http_response_code(400); // Bad Request
    echo json_encode(["success" => false, "message" => "Email et mot de passe requis."]); // Email and password required.
    exit;
}

// --- Sanitize data ---
$email = filter_var($data->email, FILTER_SANITIZE_EMAIL);
$mot_de_passe = $data->mot_de_passe; // Keep original for verification

// --- Further Validate Email ---
if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Format d'email invalide."]); // Invalid email format.
    exit;
}

// --- Find User by Email ---
try {
    // Select basic user info and hashed password
    $query_user = "SELECT id, nom, prenom, email, num_telephone, mot_de_passe, role FROM users WHERE email = :email LIMIT 1";
    $stmt_user = $pdo->prepare($query_user);
    $stmt_user->bindParam(':email', $email);
    $stmt_user->execute();

    // Check if user exists
    if ($stmt_user->rowCount() == 0) {
        http_response_code(401); // Unauthorized
        echo json_encode(["success" => false, "message" => "Email ou mot de passe incorrect."]); // Incorrect email or password.
        exit;
    }

    // Fetch user data
    $user = $stmt_user->fetch(PDO::FETCH_ASSOC);

    // --- Verify Password ---
    if (!password_verify($mot_de_passe, $user['mot_de_passe'])) {
        http_response_code(401); // Unauthorized
        echo json_encode(["success" => false, "message" => "Email ou mot de passe incorrect."]); // Incorrect email or password.
        exit;
    }

    // --- Password is correct, GENERATE AND SAVE TOKEN ---
    // Generate a unique token
    // You can use various methods for generating unique tokens (e.g., uniqid, bin2hex, hash)
    // Ensure it's long enough for uniqueness
    $token = bin2hex(random_bytes(32)); // Generates a 64-character hex string

    // Update the user's auth_token in the database
    $query_update_token = "UPDATE users SET auth_token = :token WHERE id = :user_id";
    $stmt_update_token = $pdo->prepare($query_update_token);
    $stmt_update_token->bindParam(':token', $token);
    $stmt_update_token->bindParam(':user_id', $user['id']);

    if (!$stmt_update_token->execute()) {
         // If token update fails, it's a server issue, not a login failure
         http_response_code(500); // Internal Server Error
         echo json_encode(["success" => false, "message" => "Impossible de générer le token d'authentification."]); // Unable to generate authentication token.
         exit;
    }


    // --- Prepare Success Response with Token and User Data ---
    $response_data = [
        "user" => [
            "id" => (int)$user['id'], // Cast to int
            "nom" => $user['nom'],
            "prenom" => $user['prenom'],
            "email" => $user['email'],
            "num_telephone" => $user['num_telephone'],
            "role" => $user['role'],
            // Add other user details fetched earlier if needed in the response
        ],
        "token" => $token // Include the generated token in the response
    ];

    // Optional: Fetch additional patient/doctor data here if needed in the login response
    // This was in the previous version, can be added back if necessary,
    // but for token-based auth, often only basic user data + token is returned here.
    // The client can fetch full profile details using another protected endpoint later.
    /*
    $role = $user['role'];
    $additional_data = null;
    if ($role === 'patient') { ... fetch from patients ... }
    elseif ($role === 'medecin') { ... fetch from medecins ... }
    if ($additional_data) { $response_data['user'][$role] = $additional_data; }
    */


    http_response_code(200); // OK
    echo json_encode(["success" => true, "message" => "Connexion réussie.", "data" => $response_data]); // Login successful with token.

} catch (PDOException $e) {
    // Handle database errors during user lookup or token update
    http_response_code(503); // Service Unavailable
    echo json_encode([
        "success" => false,
        "message" => "Erreur serveur lors de la connexion: " . $e->getMessage() // Server error: Unable to login.
    ]);
    // Optional: Log the actual error $e->getMessage() on the server side
} catch (Exception $e) {
     // Catch any other exceptions (like random_bytes failure)
     http_response_code(500);
     echo json_encode(["success" => false, "message" => "Une erreur inattendue est survenue: " . $e->getMessage()]);
}