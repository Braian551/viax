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
            $types = $companyData['tipos_vehiculo'];
            // If it's a string, try to decode it if it looks like JSON
            if (is_string($types)) {
                $decoded = json_decode($types, true);
                if (json_last_error() === JSON_ERROR_NONE && is_array($decoded)) {
                    $types = $decoded;
                } else {
                    // Clean brackets if it's like ["a","b"] string but not valid JSON for some reason or just standard cleanup
                    $types = explode(',', str_replace(['[',']','"'], '', $types)); 
                }
            }
            
            $vehiculos = is_array($types) 
                ? implode(', ', array_map('ucfirst', $types))
                : ucfirst($types);
                
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
        
        // Logo de la empresa (si existe) - Always use CID for embedded images
        $companyLogoHtml = '';
        if (!empty($companyData['logo_url'])) {
            $companyLogoHtml = "
            <div style='text-align: center; margin: 20px 0;'>
                <img src='cid:company_logo' alt='Logo de {$companyData['nombre_empresa']}' style='max-width: 150px; height: auto; border-radius: 8px; border: 2px solid #E0E0E0;'>
            </div>";
        }
        
        // Contenido del email
        $bodyContent = "
            <div class='greeting'>¡Bienvenido a Viax, $userName!</div>
            $companyLogoHtml
            <p class='message'>Gracias por registrar <strong>{$companyData['nombre_empresa']}</strong> en Viax.</p>
            
            <div style='background-color: #f8f9fa; border-left: 4px solid #0d6efd; padding: 16px; margin: 24px 0; border-radius: 4px;'>
                <h3 style='margin: 0 0 8px 0; color: #0d6efd; font-size: 16px; font-weight: 700;'>Estado: Pendiente de Aprobación</h3>
                <p style='margin: 0; color: #495057; font-size: 14px; line-height: 1.5;'>
                    Tu solicitud ha sido recibida. Nuestro equipo revisará la documentación en un plazo de 24-48 horas.
                </p>
            </div>
            
            $detailsTable
            
            <div style='margin-top: 30px; border-top: 1px solid #eee; padding-top: 20px;'>
                <p style='font-size: 16px; font-weight: 600; color: #212529; margin-bottom: 20px;'>Próximos Pasos:</p>
                
                <table style='width: 100%; border-collapse: separate; border-spacing: 0 15px;'>
                    <tr>
                        <td style='width: 40px; vertical-align: top; padding-right: 15px;'>
                            <div style='background-color: #e7f1ff; color: #0d6efd; width: 32px; height: 32px; border-radius: 50%; text-align: center; line-height: 32px; font-weight: bold; font-size: 14px;'>1</div>
                        </td>
                        <td style='vertical-align: top;'>
                            <strong style='color: #212529; display: block; margin-bottom: 4px; font-size: 14px;'>Revisión Administrativa</strong>
                            <span style='color: #6c757d; font-size: 13px; line-height: 1.4; display: block;'>Verificamos la legalidad y documentos de tu empresa.</span>
                        </td>
                    </tr>
                    <tr>
                        <td style='width: 40px; vertical-align: top; padding-right: 15px;'>
                            <div style='background-color: #e7f1ff; color: #0d6efd; width: 32px; height: 32px; border-radius: 50%; text-align: center; line-height: 32px; font-weight: bold; font-size: 14px;'>2</div>
                        </td>
                        <td style='vertical-align: top;'>
                            <strong style='color: #212529; display: block; margin-bottom: 4px; font-size: 14px;'>Activación de Cuenta</strong>
                            <span style='color: #6c757d; font-size: 13px; line-height: 1.4; display: block;'>Recibirás un email confirmando tu acceso total a la plataforma.</span>
                        </td>
                    </tr>
                </table>
            </div>
            
            <p class='note' style='margin-top: 30px; color: #6c757d; font-size: 13px;'>
                Una vez activo, podrás gestionar conductores, vehículos y ver estadísticas en tiempo real desde tu panel.
            </p>
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
        
        // Prepare attachments
        $attachments = [];
        $tempFile = null;
        
        // 1. Company Logo - Always embed to avoid email client blocking external images
        if (!empty($companyData['logo_url'])) {
            $logoUrl = $companyData['logo_url'];
            $imageContent = null;
            $mime = 'image/png';
            
            if (filter_var($logoUrl, FILTER_VALIDATE_URL)) {
                // It's a full URL (e.g., Cloudflare R2 public URL) - download it
                try {
                    $ch = curl_init($logoUrl);
                    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
                    curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
                    curl_setopt($ch, CURLOPT_TIMEOUT, 10);
                    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
                    $imageContent = curl_exec($ch);
                    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
                    $contentType = curl_getinfo($ch, CURLINFO_CONTENT_TYPE);
                    curl_close($ch);
                    
                    if ($httpCode == 200 && $imageContent) {
                        $mime = $contentType ?: 'image/png';
                    } else {
                        $imageContent = null;
                        error_log("Failed to download logo from URL: $logoUrl - HTTP $httpCode");
                    }
                } catch (Exception $e) {
                    error_log("Error downloading logo from URL: " . $e->getMessage());
                }
            } else {
                // It's an R2 key - use R2Service to fetch
                require_once __DIR__ . '/../config/R2Service.php';
                try {
                    $r2 = new R2Service();
                    $fileData = $r2->getFile($logoUrl);
                    if ($fileData && !empty($fileData['content'])) {
                        $imageContent = $fileData['content'];
                        $mime = $fileData['type'] ?? 'image/png';
                    }
                } catch (Exception $e) {
                    error_log("Failed to fetch R2 logo for email: " . $e->getMessage());
                }
            }
            
            // If we got image content, embed it
            if ($imageContent) {
                $ext = 'png';
                if (strpos($mime, 'jpeg') !== false || strpos($mime, 'jpg') !== false) $ext = 'jpg';
                elseif (strpos($mime, 'gif') !== false) $ext = 'gif';
                elseif (strpos($mime, 'webp') !== false) $ext = 'webp';
                
                $tempFile = tempnam(sys_get_temp_dir(), 'logo');
                file_put_contents($tempFile, $imageContent);
                $attachments[] = [
                    'path' => $tempFile,
                    'name' => "company_logo.$ext",
                    'cid' => 'company_logo',
                    'type' => $mime
                ];
            }
        }
        
        // 2. Registration PDF (passed as internal key)
        if (!empty($companyData['_pdf_path']) && file_exists($companyData['_pdf_path'])) {
            $attachments[] = [
                'path' => $companyData['_pdf_path'],
                'name' => 'Registro_Empresa_Viax.pdf'
            ];
        }

        $result = self::send($toEmail, $userName, $subject, $htmlBody, $altBody, $attachments);
        
        // Cleanup local logo temp file if created in this scope
        if (isset($tempFile) && file_exists($tempFile)) {
            @unlink($tempFile);
        }
        
        return $result;
    }

    /**
     * Envía un correo de Aprobación para empresa (Diseño Premium).
     * Reutiliza la estructura de detalles y estilo.
     */
    public static function sendCompanyApprovedEmail($toEmail, $userName, $companyData) {
        $subject = "✅ ¡Tu empresa ha sido aprobada! - {$companyData['nombre_empresa']}";
        
        // --- Reutilización de Componentes (Tabla de Detalles) ---
        $detailsTable = "
        <table style='width: 100%; border-collapse: collapse; margin: 20px 0; background: #F8F9FA; border-radius: 8px; overflow: hidden;'>
            <tr style='background: #E8F5E9;'> <!-- Verde suave -->
                <td colspan='2' style='padding: 12px; text-align: center; font-weight: 600; color: #2E7D32;'>
                    Detalles de la Cuenta
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
        
        $detailsTable .= "
            <tr>
                <td style='padding: 10px; border-bottom: 1px solid #E0E0E0; font-weight: 600;'>Email:</td>
                <td style='padding: 10px; border-bottom: 1px solid #E0E0E0;'>{$companyData['email']}</td>
            </tr>";
            
        if (!empty($companyData['razon_social'])) {
             $detailsTable .= "
            <tr>
                <td style='padding: 10px; border-bottom: 1px solid #E0E0E0; font-weight: 600;'>Razón Social:</td>
                <td style='padding: 10px; border-bottom: 1px solid #E0E0E0;'>{$companyData['razon_social']}</td>
            </tr>";
        }

        $detailsTable .= "
            <tr>
                <td style='padding: 10px; font-weight: 600;'>Representante:</td>
                <td style='padding: 10px;'>{$companyData['representante_nombre']}</td>
            </tr>
        </table>";
        
        // Initialize attachments and temp files tracking
        $attachments = [];
        $tempFiles = [];
        
        // 1. Prepare Logo - Always embed to avoid email client blocking external images
        $logoSrc = '';
        if (!empty($companyData['logo_url'])) {
            $logoUrl = $companyData['logo_url'];
            $imageContent = null;
            $mime = 'image/png';
            
            // Try to fetch the image content
            if (filter_var($logoUrl, FILTER_VALIDATE_URL)) {
                // It's a full URL (e.g., Cloudflare R2 public URL) - download it
                try {
                    $ch = curl_init($logoUrl);
                    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
                    curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
                    curl_setopt($ch, CURLOPT_TIMEOUT, 10);
                    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
                    $imageContent = curl_exec($ch);
                    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
                    $contentType = curl_getinfo($ch, CURLINFO_CONTENT_TYPE);
                    curl_close($ch);
                    
                    if ($httpCode == 200 && $imageContent) {
                        $mime = $contentType ?: 'image/png';
                    } else {
                        $imageContent = null;
                        error_log("Failed to download logo from URL: $logoUrl - HTTP $httpCode");
                    }
                } catch (Exception $e) {
                    error_log("Error downloading logo from URL: " . $e->getMessage());
                }
            } else {
                // It's an R2 key - use R2Service to fetch
                require_once __DIR__ . '/../config/R2Service.php';
                try {
                    $r2 = new R2Service();
                    $fileData = $r2->getFile($logoUrl);
                    if ($fileData && !empty($fileData['content'])) {
                        $imageContent = $fileData['content'];
                        $mime = $fileData['type'] ?? 'image/png';
                    }
                } catch (Exception $e) { 
                    error_log("Failed to download logo from R2: " . $e->getMessage());
                }
            }
            
            // If we got image content, embed it
            if ($imageContent) {
                $ext = 'png';
                if (strpos($mime, 'jpeg') !== false || strpos($mime, 'jpg') !== false) $ext = 'jpg';
                elseif (strpos($mime, 'gif') !== false) $ext = 'gif';
                elseif (strpos($mime, 'webp') !== false) $ext = 'webp';
                
                $fileName = "company_logo.$ext";
                $tempFile = tempnam(sys_get_temp_dir(), 'logo');
                file_put_contents($tempFile, $imageContent);
                $tempFiles[] = $tempFile;
                
                $attachments[] = [
                    'path' => $tempFile,
                    'name' => $fileName,
                    'cid' => 'company_logo',
                    'type' => $mime
                ];
                $logoSrc = 'cid:company_logo';
            }
        }
        
        // 2. Prepare PDF Attachment
        if (!empty($companyData['_pdf_path']) && file_exists($companyData['_pdf_path'])) {
            $attachments[] = [
                'path' => $companyData['_pdf_path'],
                'name' => 'Credenciales_Viax.pdf'
            ];
        }

        // Logo de la empresa (si existe)
        $companyLogoHtml = '';
        if (!empty($logoSrc)) {
            $companyLogoHtml = "
            <div style='text-align: center; margin: 20px 0;'>
                <img src='$logoSrc' alt='Logo de {$companyData['nombre_empresa']}' style='max-width: 150px; height: auto; border-radius: 8px; border: 2px solid #E0E0E0;'>
            </div>";
        }
        
        $bodyContent = "
            <div class='greeting'>¡Bienvenido a Viax, $userName!</div>
            $companyLogoHtml
            <div style='background-color: #e8f5e9; border: 1px solid #4caf50; border-radius: 8px; padding: 16px; margin: 20px 0; text-align: center;'>
                <h2 style='color: #2e7d32; margin: 0 0 8px 0;'>¡Tu cuenta ha sido Aprobada!</h2>
                <p style='color: #1b5e20; margin: 0;'>Ahora puedes gestionar tu flota de transporte.</p>
            </div>
            
            <p class='message'>Nos complace informarte que la empresa <strong>{$companyData['nombre_empresa']}</strong> está activa en nuestra plataforma.</p>
            
            <p class='message'>Detalles del registro:</p>
            $detailsTable
            
            <p class='message'>Pasos a seguir:</p>
            <ul style='color: #555; line-height: 1.6;'>
                <li>Inicia sesión en la aplicación Viax.</li>
                <li>Registra tus vehículos y conductores.</li>
                <li>Comienza a recibir viajes.</li>
            </ul>
        ";
        
        // Texto plano
        $altBody = "¡Felicidades, $userName!\n\n" .
                   "Tu empresa {$companyData['nombre_empresa']} ha sido APROBADA en Viax.\n\n" .
                   "Estado: Activo\n" .
                   "Ya puedes gestionar tu flota desde la aplicación.\n\n" .
                   "Saludos,\nEquipo Viax";
        
        $htmlBody = self::wrapLayout($bodyContent);
        
        $result = self::send($toEmail, $userName, $subject, $htmlBody, $altBody, $attachments);
        
        // Cleanup temp files
        foreach ($tempFiles as $tf) {
            if (file_exists($tf)) @unlink($tf);
        }
        
        return $result;
    }

    /**
     * Envía un correo de Rechazo para empresa (Diseño Profesional).
     * Incluye logo y motivo.
     */
    public static function sendCompanyRejectedEmail($toEmail, $userName, $companyData, $reason) {
        $subject = "⚠️ Actualización sobre tu registro en Viax - {$companyData['nombre_empresa']}";
        
        // --- Reutilización de Componentes (Tabla de Detalles) ---
        $detailsTable = "
        <table style='width: 100%; border-collapse: collapse; margin: 20px 0; background: #FFF4F4; border-radius: 8px; overflow: hidden;'>
            <tr style='background: #FFEBEE;'> <!-- Rojo suave -->
                <td colspan='2' style='padding: 12px; text-align: center; font-weight: 600; color: #D32F2F;'>
                    Detalles de la Solicitud
                </td>
            </tr>
            <tr>
                <td style='padding: 10px; border-bottom: 1px solid #FFCDD2; font-weight: 600; width: 40%;'>Empresa:</td>
                <td style='padding: 10px; border-bottom: 1px solid #FFCDD2;'>{$companyData['nombre_empresa']}</td>
            </tr>
            <tr>
                <td style='padding: 10px; font-weight: 600;'>Representante:</td>
                <td style='padding: 10px;'>{$companyData['representante_nombre']}</td>
            </tr>
        </table>";
        
        // Initialize attachments and temp files tracking
        $attachments = [];
        $tempFiles = [];
        
        // 1. Prepare Logo - Always embed to avoid email client blocking external images
        $logoSrc = '';
        if (!empty($companyData['logo_url'])) {
            $logoUrl = $companyData['logo_url'];
            $imageContent = null;
            $mime = 'image/png';
            
            // Try to fetch the image content
            if (filter_var($logoUrl, FILTER_VALIDATE_URL)) {
                try {
                    $ch = curl_init($logoUrl);
                    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
                    curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
                    curl_setopt($ch, CURLOPT_TIMEOUT, 10);
                    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
                    $imageContent = curl_exec($ch);
                    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
                    $contentType = curl_getinfo($ch, CURLINFO_CONTENT_TYPE);
                    curl_close($ch);
                    
                    if ($httpCode == 200 && $imageContent) {
                        $mime = $contentType ?: 'image/png';
                    } else {
                        $imageContent = null;
                    }
                } catch (Exception $e) {}
            } else {
                // R2 Key
                require_once __DIR__ . '/../config/R2Service.php';
                try {
                    $r2 = new R2Service();
                    $fileData = $r2->getFile($logoUrl);
                    if ($fileData && !empty($fileData['content'])) {
                        $imageContent = $fileData['content'];
                        $mime = $fileData['type'] ?? 'image/png';
                    }
                } catch (Exception $e) {}
            }
            
            // If we got image content, embed it
            if ($imageContent) {
                $ext = 'png';
                if (strpos($mime, 'jpeg') !== false || strpos($mime, 'jpg') !== false) $ext = 'jpg';
                elseif (strpos($mime, 'gif') !== false) $ext = 'gif';
                elseif (strpos($mime, 'webp') !== false) $ext = 'webp';
                
                $fileName = "company_logo.$ext";
                $tempFile = tempnam(sys_get_temp_dir(), 'logo');
                file_put_contents($tempFile, $imageContent);
                $tempFiles[] = $tempFile;
                
                $attachments[] = [
                    'path' => $tempFile,
                    'name' => $fileName,
                    'cid' => 'company_logo',
                    'type' => $mime
                ];
                $logoSrc = 'cid:company_logo';
            }
        }

        // Logo de la empresa (si existe)
        $companyLogoHtml = '';
        if (!empty($logoSrc)) {
            $companyLogoHtml = "
            <div style='text-align: center; margin: 20px 0;'>
                <img src='$logoSrc' alt='Logo de {$companyData['nombre_empresa']}' style='max-width: 150px; height: auto; border-radius: 8px; border: 2px solid #E0E0E0;'>
            </div>";
        }
        
        $bodyContent = "
            <div class='greeting'>Hola, $userName</div>
            $companyLogoHtml
            <div style='background-color: #ffebee; border: 1px solid #ef9a9a; border-radius: 8px; padding: 16px; margin: 20px 0; text-align: center;'>
                <h2 style='color: #c62828; margin: 0 0 8px 0;'>Solicitud Rechazada</h2>
                <p style='color: #b71c1c; margin: 0;'>No hemos podido aprobar tu registro en esta ocasión.</p>
            </div>
            
            <p class='message'>Hemos revisado la documentación de <strong>{$companyData['nombre_empresa']}</strong> y hemos encontrado inconsistencias.</p>
            
            <div style='text-align: left; padding: 20px; background-color: #f8f9fa; border-left: 4px solid #d32f2f; margin: 20px 0;'>
                <strong style='display: block; color: #d32f2f; margin-bottom: 8px;'>Motivo del rechazo:</strong>
                <p style='margin: 0; color: #333; font-style: italic; white-space: pre-line;'>$reason</p>
            </div>
            
            $detailsTable
            
            <p class='message'>
                Esta decisión es definitiva y tus datos han sido eliminados del sistema por seguridad. 
                Si deseas intentarlo nuevamente, por favor asegúrate de cumplir con todos los requisitos y realiza un nuevo registro.
            </p>
        ";
        
        // Texto plano
        $altBody = "Hola, $userName.\n\n" .
                   "Tu solicitud de registro para {$companyData['nombre_empresa']} ha sido RECHAZADA.\n\n" .
                   "Motivo: $reason\n\n" .
                   "Tus datos han sido eliminados de nuestro sistema.\n\n" .
                   "Saludos,\nEquipo Viax";
        
        $htmlBody = self::wrapLayout($bodyContent);
        
        $result = self::send($toEmail, $userName, $subject, $htmlBody, $altBody, $attachments);
        
        // Cleanup temp files
        foreach ($tempFiles as $tf) {
            if (file_exists($tf)) @unlink($tf);
        }
        
        // Cleanup temp files
        foreach ($tempFiles as $tf) {
            if (file_exists($tf)) @unlink($tf);
        }
        
        return $result;
    }

    /**
     * Envía un correo de Eliminación para empresa.
     * Notifica que la cuenta ha sido eliminada permanentemente.
     */
    public static function sendCompanyDeletedEmail($toEmail, $userName, $companyData) {
        $subject = "⚠️ Cuenta eliminada - {$companyData['nombre_empresa']}";
        
        // --- Reutilización de Componentes (Tabla de Detalles) ---
        $detailsTable = "
        <table style='width: 100%; border-collapse: collapse; margin: 20px 0; background: #FFF4F4; border-radius: 8px; overflow: hidden;'>
            <tr style='background: #FFEBEE;'>
                <td colspan='2' style='padding: 12px; text-align: center; font-weight: 600; color: #D32F2F;'>
                    Detalles de la Cuenta Eliminada
                </td>
            </tr>
            <tr>
                <td style='padding: 10px; border-bottom: 1px solid #FFCDD2; font-weight: 600; width: 40%;'>Empresa:</td>
                <td style='padding: 10px; border-bottom: 1px solid #FFCDD2;'>{$companyData['nombre_empresa']}</td>
            </tr>
            <tr>
                <td style='padding: 10px; font-weight: 600;'>Representante:</td>
                <td style='padding: 10px;'>{$companyData['representante_nombre']}</td>
            </tr>
        </table>";
        
        // Initialize attachments
        $attachments = [];
        $tempFiles = [];
        
        // 1. Prepare Logo (Logic copied for consistency)
        $logoSrc = '';
        if (!empty($companyData['logo_url'])) {
            $logoUrl = $companyData['logo_url'];
            $imageContent = null;
            $mime = 'image/png';
            
            if (filter_var($logoUrl, FILTER_VALIDATE_URL)) {
                try {
                    $ch = curl_init($logoUrl);
                    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
                    curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
                    curl_setopt($ch, CURLOPT_TIMEOUT, 10);
                    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
                    $imageContent = curl_exec($ch);
                    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
                    $contentType = curl_getinfo($ch, CURLINFO_CONTENT_TYPE);
                    curl_close($ch);
                    if ($httpCode == 200 && $imageContent) $mime = $contentType ?: 'image/png';
                    else $imageContent = null;
                } catch (Exception $e) {}
            } else {
                require_once __DIR__ . '/../config/R2Service.php';
                try {
                    $r2 = new R2Service();
                    $fileData = $r2->getFile($logoUrl);
                    if ($fileData && !empty($fileData['content'])) {
                        $imageContent = $fileData['content'];
                        $mime = $fileData['type'] ?? 'image/png';
                    }
                } catch (Exception $e) {}
            }
            
            if ($imageContent) {
                $ext = 'png';
                if (strpos($mime, 'jpeg') !== false || strpos($mime, 'jpg') !== false) $ext = 'jpg';
                $fileName = "company_logo.$ext";
                $tempFile = tempnam(sys_get_temp_dir(), 'logo');
                file_put_contents($tempFile, $imageContent);
                $tempFiles[] = $tempFile;
                
                $attachments[] = [
                    'path' => $tempFile,
                    'name' => $fileName,
                    'cid' => 'company_logo',
                    'type' => $mime
                ];
                $logoSrc = 'cid:company_logo';
            }
        }

        $companyLogoHtml = '';
        if (!empty($logoSrc)) {
            $companyLogoHtml = "
            <div style='text-align: center; margin: 20px 0;'>
                <img src='$logoSrc' alt='Logo de {$companyData['nombre_empresa']}' style='max-width: 150px; height: auto; border-radius: 8px; border: 2px solid #E0E0E0;'>
            </div>";
        }
        
        $bodyContent = "
            <div class='greeting'>Hola, $userName</div>
            $companyLogoHtml
            <div style='background-color: #ffebee; border: 1px solid #ef9a9a; border-radius: 8px; padding: 16px; margin: 20px 0; text-align: center;'>
                <h2 style='color: #c62828; margin: 0 0 8px 0;'>Cuenta Eliminada</h2>
                <p style='color: #b71c1c; margin: 0;'>Tu cuenta ha sido eliminada por un administrador.</p>
            </div>
            
            <p class='message'>Te informamos que la cuenta de la empresa <strong>{$companyData['nombre_empresa']}</strong> y todos los datos asociados han sido eliminados de forma permanente de nuestros servidores.</p>
            
            $detailsTable
            
            <p class='message'>
                Esta acción es irreversible. Si crees que esto es un error o deseas volver a registrarte, ponte en contacto con nuestro soporte.
            </p>
        ";
        
        $altBody = "Hola, $userName.\n\n" .
                   "Tu cuenta de empresa {$companyData['nombre_empresa']} ha sido ELIMINADA por un administrador.\n" .
                   "Todos tus datos han sido borrados permanentemente.\n\n" .
                   "Saludos,\nEquipo Viax";
        
        $htmlBody = self::wrapLayout($bodyContent);
        
        $result = self::send($toEmail, $userName, $subject, $htmlBody, $altBody, $attachments);
        
        foreach ($tempFiles as $tf) {
            if (file_exists($tf)) @unlink($tf);
        }
        
        return $result;
    }

    /**
     * Método base para enviar el correo usando PHPMailer.
     * @param array $attachments Array of ['path' => string, 'name' => string, 'cid' => string|null]
     */
    private static function send($toEmail, $toName, $subject, $htmlBody, $altBody = null, $attachments = []) {
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
            
            // Embed Viax Logo (standard)
            $logoPath = __DIR__ . '/../assets/images/logo.png';
            if (file_exists($logoPath)) {
                $mail->addEmbeddedImage($logoPath, 'viax_logo', 'logo.png');
            }
            
            // Handle custom attachments
            if (!empty($attachments)) {
                // If single path passed (backward compatibility or simple usage)
                if (is_string($attachments)) {
                    $attachments = [['path' => $attachments, 'name' => 'attachment', 'cid' => 'company_logo']];
                }
                
                foreach ($attachments as $att) {
                    if ( isset($att['path']) && file_exists($att['path']) ) {
                        if (!empty($att['cid'])) {
                            // Embedded Image (Inline)
                            $mime = $att['type'] ?? '';
                            $mail->addEmbeddedImage($att['path'], $att['cid'], $att['name'] ?? '', 'base64', $mime);
                        } else {
                            // Standard Attachment
                            $mail->addAttachment($att['path'], $att['name'] ?? '');
                        }
                    }
                }
            }
            
            $mail->Body = $htmlBody;
            
            // Usar altBody proporcionado o generar uno básico
            $mail->AltBody = $altBody ?? strip_tags($htmlBody);

            $mail->send();
            
            // NOTE: We do NOT delete attachments here anymore, because they might be reused 
            // for multiple emails (e.g. company + representative).
            // The caller is responsible for cleanup.
            
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
