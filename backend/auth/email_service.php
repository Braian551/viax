<?php

use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\Exception;

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, GET, OPTIONS, DELETE, PUT');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

function getJsonInput() {
    $input = json_decode(file_get_contents('php://input'), true);
    if (json_last_error() !== JSON_ERROR_NONE) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'JSON invalido']);
        exit;
    }
    return $input;
}

function sendJsonResponse($success, $message, $data = []) {
    $response = ['success' => $success, 'message' => $message];
    if (!empty($data)) {
        $response['data'] = $data;
    }
    echo json_encode($response);
    exit;
}

try {
    $input = getJsonInput();
    $email = filter_var($input['email'] ?? '', FILTER_VALIDATE_EMAIL);
    $code = $input['code'] ?? '';
    $userName = $input['userName'] ?? '';

    // Ajustado a códigos de 4 dígitos (antes 6)
    if (!$email || strlen($code) !== 4 || empty($userName)) {
        sendJsonResponse(false, 'Datos incompletos o invalidos (se esperan 4 dígitos)');
    }

    // Verificar que las dependencias estén disponibles
    $vendorPath = __DIR__ . '/../vendor/autoload.php';
    if (!file_exists($vendorPath)) {
        throw new Exception("Dependencias no encontradas. Vendor path: $vendorPath");
    }

    require $vendorPath;

    // Verificar que PHPMailer esté disponible
    if (!class_exists('PHPMailer\PHPMailer\PHPMailer')) {
        throw new Exception("PHPMailer no está disponible");
    }

    $mail = new PHPMailer(true);

    // Configuración del servidor
    $mail->isSMTP();
    $mail->Host = 'smtp.gmail.com';
    $mail->SMTPAuth = true;
    $mail->Username = 'viaxoficialcol@gmail.com';
    $mail->Password = 'filz vqel gadn kugb';
    $mail->SMTPSecure = PHPMailer::ENCRYPTION_STARTTLS;
    $mail->Port = 587;

    $mail->CharSet = 'UTF-8';
    $mail->setFrom('viaxoficialcol@gmail.com', 'Viax');
    $mail->addAddress($email, $userName);
    $mail->isHTML(true);
    $mail->Subject = 'Tu código de verificación Viax';

    // Colores de AppColors
    // Primary: #2196F3
    // Background: #F5F5F5
    // Surface: #FFFFFF
    
    // Ruta al logo
    $logoPath = __DIR__ . '/../assets/images/logo.png';
    $hasLogo = false;
    if (file_exists($logoPath)) {
        $mail->addEmbeddedImage($logoPath, 'viax_logo', 'logo.png');
        $hasLogo = true;
    }

    // Cabecera: Logo pequeño + Texto Viax
    $headerContent = $hasLogo 
        ? "<table border='0' cellpadding='0' cellspacing='0' style='border-collapse: collapse; margin: 0 auto;'><tr><td style='padding: 0;'><img src='cid:viax_logo' alt='' width='36' height='36' style='width: 36px; height: 36px; vertical-align: middle; border: 0;'></td><td style='padding-left: 4px;'><span style='font-size: 26px; font-weight: bold; vertical-align: middle;'>Viax</span></td></tr></table>" 
        : "<span style='font-size: 26px; font-weight: bold;'>Viax</span>";
    
    $mail->Body = "
    <!DOCTYPE html>
    <html>
    <head>
        <meta name='viewport' content='width=device-width, initial-scale=1.0'>
        <style>
            body { font-family: 'Roboto', 'Helvetica', 'Arial', sans-serif; background-color: #F5F5F5; margin: 0; padding: 0; }
            .container { max-width: 600px; margin: 20px auto; background-color: #F5F5F5; } 
            .card { background-color: #FFFFFF; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 12px rgba(0,0,0,0.05); }
            .header { background: linear-gradient(135deg, #2196F3 0%, #1976D2 100%); padding: 25px 30px; }
            .content { padding: 40px 30px; text-align: center; color: #333333; }
            .greeting { font-size: 22px; font-weight: 600; margin-bottom: 16px; color: #212121; }
            .message { font-size: 16px; line-height: 1.6; color: #5F6368; margin-bottom: 32px; margin-top: 0; }
            .code-container { background-color: #F1F3F4; padding: 24px 32px; border-radius: 12px; display: inline-block; margin-bottom: 32px; letter-spacing: 2px; }
            .code { font-size: 36px; font-weight: bold; color: #1967D2; margin: 0; font-family: monospace; }
            .footer { padding: 24px; text-align: center; font-size: 12px; color: #9AA0A6; }
            .note { font-size: 13px; color: #5F6368; margin-top: 0; }
        </style>
    </head>
    <body>
        <div class='container'>
            <div class='card'>
                <div class='header'>
                    $headerContent
                </div>
                <div class='content'>
                    <div class='greeting'>Hola, $userName</div>
                    <p class='message'>Aquí tienes tu código de verificación para continuar en Viax. Úsalo para completar tu inicio de sesión.</p>
                    
                    <div class='code-container'>
                        <div class='code'>$code</div>
                    </div>
                    
                    <p class='note'>Este código caduca en 10 minutos. No lo compartas.</p>
                </div>
            </div>
            <div class='footer'>
                <p>&copy; " . date('Y') . " Viax. Viaja fácil, llega rápido.</p>
            </div>
        </div>
    </body>
    </html>";

    $mail->AltBody = "Hola $userName,\n\nTu código de verificación para Viax es: $code\n\nEste código expirará en 10 minutos.\n\nSaludos,\nEl equipo de Viax";

    if ($mail->send()) {
        sendJsonResponse(true, 'Código enviado correctamente');
    } else {
        throw new Exception("Error al enviar email: " . $mail->ErrorInfo);
    }

} catch (Exception $e) {
    error_log("Email service error: " . $e->getMessage());
    http_response_code(500);
    sendJsonResponse(false, 'Error: ' . $e->getMessage());
}