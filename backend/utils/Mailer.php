<?php
/**
 * Mailer.php
 * Componente reutilizable para el envío de correos electrónicos con diseño unificado.
 */

use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\Exception;

require_once __DIR__ . '/../vendor/autoload.php';

class Mailer {
    
    // Configuración SMTP (Idealmente mover a variables de entorno)
    private const SMTP_HOST = 'smtp.gmail.com';
    private const SMTP_USER = 'viaxoficialcol@gmail.com';
    private const SMTP_PASS = 'filz vqel gadn kugb'; // App Password
    private const SMTP_PORT = 587;
    private const FROM_NAME = 'Viax';

    /**
     * Envía un código de verificación.
     */
    public static function sendVerificationCode($toEmail, $userName, $code) {
        $subject = "Tu código de verificación Viax: $code";
        
        // Contenido específico para verificación
        $bodyContent = "
            <div class='greeting'>Hola, $userName</div>
            <p class='message'>Aquí tienes tu código de verificación para continuar en Viax. Úsalo para completar tu inicio de sesión.</p>
            
            <div class='code-container'>
                <div class='code'>$code</div>
            </div>
            
            <p class='note'>Este código caduca en 10 minutos. No lo compartas.</p>
        ";

        // Envolvemos el contenido en el diseño base
        $htmlBody = self::wrapLayout($bodyContent);
        
        // Versión texto plano LIMPIA para notificaciones
        $altBody = "Tu código de verificación Viax: $code\n\n" .
                   "Hola $userName, usa este código para completar tu inicio de sesión.\n\n" .
                   "Este código caduca en 10 minutos. No lo compartas.\n\n" .
                   "Saludos,\nEl equipo de Viax";
        
        return self::send($toEmail, $userName, $subject, $htmlBody, $altBody);
    }

    /**
     * Envía un correo genérico (para futuros usos).
     */
    public static function sendEmail($toEmail, $userName, $subject, $message) {
        $bodyContent = "
            <div class='greeting'>Hola, $userName</div>
            <p class='message'>$message</p>
        ";
        $htmlBody = self::wrapLayout($bodyContent);
        return self::send($toEmail, $userName, $subject, $htmlBody);
    }

    /**
     * Envía un correo de bienvenida para empresa con todos los detalles del registro.
     */
    public static function sendCompanyWelcomeEmail($toEmail, $userName, $companyData) {
        $subject = "Bienvenido a Viax - Registro de {$companyData['nombre_empresa']}";
        
        // Construir tabla de detalles
        $detailsTable = "
        <table style='width: 100%; border-collapse: collapse; margin: 20px 0; background: #F8F9FA; border-radius: 8px; overflow: hidden;'>
            <tr style='background: #E3F2FD;'>
                <td colspan='2' style='padding: 12px; text-align: center; font-weight: 600; color: #1976D2;'>
                    Detalles del Registro
                </td>
            </tr>
            <tr>
                <td style='padding: 10px; border-bottom: 1px solid #E0E0E0; font-weight: 600; width: 40%;'>Empresa:</td>
                <td style='padding: 10px; border-bottom: 1px solid #E0E0E0;'>{$companyData['nombre_empresa']}</td>
            </tr>";
        
        if (!empty($companyData['nit'])) {
            $detailsTable .= "
            <tr>
                <td style='padding: 10px; border-bottom: 1px solid #E0E0E0; font-weight: 600;'>NIT:</td>
                <td style='padding: 10px; border-bottom: 1px solid #E0E0E0;'>{$companyData['nit']}</td>
            </tr>";
        }
        
        if (!empty($companyData['razon_social'])) {
            $detailsTable .= "
            <tr>
                <td style='padding: 10px; border-bottom: 1px solid #E0E0E0; font-weight: 600;'>Razón Social:</td>
                <td style='padding: 10px; border-bottom: 1px solid #E0E0E0;'>{$companyData['razon_social']}</td>
            </tr>";
        }
        
        $detailsTable .= "
            <tr>
                <td style='padding: 10px; border-bottom: 1px solid #E0E0E0; font-weight: 600;'>Email:</td>
                <td style='padding: 10px; border-bottom: 1px solid #E0E0E0;'>{$companyData['email']}</td>
            </tr>
            <tr>
                <td style='padding: 10px; border-bottom: 1px solid #E0E0E0; font-weight: 600;'>Teléfono:</td>
                <td style='padding: 10px; border-bottom: 1px solid #E0E0E0;'>{$companyData['telefono']}</td>
            </tr>";
        
        if (!empty($companyData['direccion'])) {
            $detailsTable .= "
            <tr>
                <td style='padding: 10px; border-bottom: 1px solid #E0E0E0; font-weight: 600;'>Dirección:</td>
                <td style='padding: 10px; border-bottom: 1px solid #E0E0E0;'>{$companyData['direccion']}</td>
            </tr>";
        }
        
        if (!empty($companyData['municipio']) && !empty($companyData['departamento'])) {
            $detailsTable .= "
            <tr>
                <td style='padding: 10px; border-bottom: 1px solid #E0E0E0; font-weight: 600;'>Ubicación:</td>
                <td style='padding: 10px; border-bottom: 1px solid #E0E0E0;'>{$companyData['municipio']}, {$companyData['departamento']}</td>
            </tr>";
        }
        
        if (!empty($companyData['tipos_vehiculo'])) {
            $vehiculos = is_array($companyData['tipos_vehiculo']) 
                ? implode(', ', array_map('ucfirst', $companyData['tipos_vehiculo']))
                : ucfirst($companyData['tipos_vehiculo']);
            $detailsTable .= "
            <tr>
                <td style='padding: 10px; border-bottom: 1px solid #E0E0E0; font-weight: 600;'>Tipos de Vehículo:</td>
                <td style='padding: 10px; border-bottom: 1px solid #E0E0E0;'>$vehiculos</td>
            </tr>";
        }
        
        $detailsTable .= "
            <tr>
                <td style='padding: 10px; font-weight: 600;'>Representante:</td>
                <td style='padding: 10px;'>{$companyData['representante_nombre']}</td>
            </tr>
        </table>";
        
        // Logo de la empresa (si existe)
        $companyLogoHtml = '';
        if (!empty($companyData['logo_url'])) {
            $companyLogoHtml = "
            <div style='text-align: center; margin: 20px 0;'>
                <img src='{$companyData['logo_url']}' alt='Logo de {$companyData['nombre_empresa']}' style='max-width: 150px; height: auto; border-radius: 8px; border: 2px solid #E0E0E0;'>
            </div>";
        }
        
        // Contenido del email
        $bodyContent = "
            <div class='greeting'>¡Bienvenido a Viax, $userName!</div>
            $companyLogoHtml
            <p class='message'>Gracias por registrar <strong>{$companyData['nombre_empresa']}</strong> en Viax.</p>
            
            <div style='background: #FFF3CD; border: 2px solid #FFC107; padding: 16px; border-radius: 8px; margin: 20px 0; text-align: center;'>
                <p style='margin: 0; color: #856404; font-weight: 600;'>
                    ⏳ Estado: Pendiente de Aprobación
                </p>
                <p style='margin: 8px 0 0 0; color: #856404; font-size: 14px;'>
                    Tu solicitud será revisada en las próximas 24-48 horas.
                </p>
            </div>
            
            $detailsTable
            
            <div style='background: #E8F5E9; padding: 16px; border-radius: 8px; margin: 20px 0;'>
                <p style='margin: 0 0 10px 0; font-weight: 600; color: #2E7D32;'>Una vez aprobada tu empresa, podrás:</p>
                <ul style='margin: 0; padding-left: 20px; color: #2E7D32;'>
                    <li>✅ Gestionar tus conductores</li>
                    <li>✅ Ver estadísticas de viajes</li>
                    <li>✅ Administrar tu flota de vehículos</li>
                    <li>✅ Acceder al panel de empresa</li>
                </ul>
            </div>
            
            <p class='note' style='font-weight: 600;'>Te notificaremos por email cuando tu cuenta esté activa.</p>
        ";
        
        // Versión texto plano
        $altBody = "¡Bienvenido a Viax, $userName!\n\n" .
                   "Gracias por registrar {$companyData['nombre_empresa']} en Viax.\n\n" .
                   "Estado: Pendiente de Aprobación\n" .
                   "Tu solicitud será revisada en las próximas 24-48 horas.\n\n" .
                   "DETALLES DEL REGISTRO:\n" .
                   "Empresa: {$companyData['nombre_empresa']}\n" .
                   "Email: {$companyData['email']}\n" .
                   "Teléfono: {$companyData['telefono']}\n\n" .
                   "Te notificaremos cuando tu cuenta esté activa.\n\n" .
                   "Saludos,\nEl equipo de Viax";
        
        $htmlBody = self::wrapLayout($bodyContent);
        return self::send($toEmail, $userName, $subject, $htmlBody, $altBody);
    }


    /**
     * Método base para enviar el correo usando PHPMailer.
     */
    private static function send($toEmail, $toName, $subject, $htmlBody, $altBody = null) {
        $mail = new PHPMailer(true);

        try {
            // Configuración del servidor
            $mail->isSMTP();
            $mail->Host       = self::SMTP_HOST;
            $mail->SMTPAuth   = true;
            $mail->Username   = self::SMTP_USER;
            $mail->Password   = self::SMTP_PASS;
            $mail->SMTPSecure = PHPMailer::ENCRYPTION_STARTTLS;
            $mail->Port       = self::SMTP_PORT;
            $mail->CharSet    = 'UTF-8';

            // Destinatarios
            $mail->setFrom(self::SMTP_USER, self::FROM_NAME);
            $mail->addAddress($toEmail, $toName);

            // Contenido
            $mail->isHTML(true);
            $mail->Subject = $subject;
            
            // Embed Logo si existe
            $logoPath = __DIR__ . '/../assets/images/logo.png';
            if (file_exists($logoPath)) {
                $mail->addEmbeddedImage($logoPath, 'viax_logo', 'logo.png');
            }
            
            $mail->Body = $htmlBody;
            
            // Usar altBody proporcionado o generar uno básico
            $mail->AltBody = $altBody ?? strip_tags($htmlBody);

            $mail->send();
            return true;
        } catch (Exception $e) {
            error_log("Mailer Error: {$mail->ErrorInfo}");
            return false;
        }
    }

    /**
     * Envuelve el contenido en el diseño estándar de Viax.
     * Esto asegura que todos los correos tengan la misma cabecera y pie de página.
     */
    private static function wrapLayout($content) {
        $year = date('Y');
        
        // Cabecera con Logo
        $headerContent = "
        <table border='0' cellpadding='0' cellspacing='0' style='border-collapse: collapse; margin: 0 auto;'><tr><td style='padding: 0;'><img src='cid:viax_logo' alt='' width='36' height='36' style='width: 36px; height: 36px; vertical-align: middle; border: 0;'></td><td style='padding-left: 4px;'><span style='font-size: 26px; font-weight: bold; vertical-align: middle;'>Viax</span></td></tr></table>
        ";

        return "
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
                table { font-size: 14px; }
                table td { text-align: left; }
            </style>
        </head>
        <body>
            <div class='container'>
                <div class='card'>
                    <div class='header'>
                        $headerContent
                    </div>
                    <div class='content'>
                        $content
                    </div>
                </div>
                <div class='footer'>
                    <p>&copy; $year Viax. Viaja fácil, llega rápido.</p>
                </div>
            </div>
        </body>
        </html>";
    }
}
