<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET");
header("Access-Control-Max-Age: 3600");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

require_once __DIR__ . '/../../config/db_connect.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode(["success" => false, "message" => "Method Not Allowed"]);
    exit;
}

$query = "SELECT id, nom_specialite FROM specialities ORDER BY nom_specialite ASC";

try {
    $stmt = $pdo->prepare($query);
    $stmt->execute();

    $num = $stmt->rowCount();

    if ($num > 0) {
        $specialities_arr = [];
        $specialities_arr["success"] = true;
        $specialities_arr["data"] = [];

        while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
            extract($row);

            $speciality_item = [
                "id" => $id,
                "nom_specialite" => $nom_specialite
            ];

            array_push($specialities_arr["data"], $speciality_item);
        }

        http_response_code(200);
        echo json_encode($specialities_arr);
    } else {
        http_response_code(404);
        echo json_encode([
            "success" => false,
            "message" => "Aucune spécialité trouvée."
        ]);
    }
} catch (PDOException $e) {
    http_response_code(503);
    echo json_encode([
        "success" => false,
        "message" => "Impossible de récupérer les spécialités. Erreur: " . $e->getMessage()
    ]);
}
