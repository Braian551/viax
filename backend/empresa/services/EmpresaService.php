<?php
/**
 * EmpresaService.php
 * Handles business logic for empresa registration
 * Single Responsibility: Business Rules Coordination
 */

require_once __DIR__ . '/../validators/EmpresaValidator.php';
require_once __DIR__ . '/../repositories/EmpresaRepository.php';
require_once __DIR__ . '/../../utils/Mailer.php';

class EmpresaService {
    
    private $repository;
    private $validator;
    
    public function __construct($db) {
        $this->repository = new EmpresaRepository($db);
        $this->validator = new EmpresaValidator($db);
    }
    
    /**
     * Register a new empresa with admin user
     * @return array registration result
     */
    /**
     * Register a new empresa (Database Transaction part)
     * @return array registration result + data for notifications
     */
    public function processRegistration($input) {
        // 1. Validate all inputs
        $email = $this->validator->validateAll($input);
        
        // 2. Process vehicle types
        $tiposVehiculo = $this->processVehicleTypes($input['tipos_vehiculo'] ?? []);
        
        // 3. Handle logo upload
        $logoUrl = $this->uploadLogo();
        
        // 4. Process representative name
        $representante = $this->processRepresentativeName($input);
        
        // 5. Start transaction and create records
        $this->repository->beginTransaction();
        
        try {
            // Create empresa
            $empresaData = $this->prepareEmpresaData($input, $email, $tiposVehiculo, $logoUrl, $representante['nombre_completo']);
            $empresaResult = $this->repository->createEmpresa($empresaData);
            $empresaId = $empresaResult['id'];
            
            // Create admin user
            $usuarioData = $this->prepareUsuarioData($input, $email, $representante, $empresaId);
            $usuarioResult = $this->repository->createUsuario($usuarioData);
            $userId = $usuarioResult['id'];
            
            // Update empresa with creator
            $this->repository->updateEmpresaCreador($empresaId, $userId);
            
            // Register device if provided
            $deviceRegistered = $this->repository->registerDevice($userId, $input['device_uuid'] ?? '');
            
            // Log audit
            $this->repository->logAudit(null, 'empresa_registrada_publico', 'empresas_transporte', $empresaId, [
                'nombre' => $input['nombre_empresa'],
                'email' => $email,
                'nit' => $input['nit'] ?? null
            ]);
            
            // Commit transaction
            $this->repository->commit();
            
            // Return success data needed for response AND notifications
            return [
                'success' => true,
                'message' => 'Empresa registrada exitosamente. Tu solicitud está pendiente de aprobación.',
                'data' => [
                    'empresa_id' => $empresaId,
                    'user' => [
                        'id' => $userId,
                        'uuid' => $usuarioData['uuid'],
                        'nombre' => $representante['nombre'],
                        'apellido' => $representante['apellido'],
                        'email' => $email,
                        'telefono' => trim($input['telefono']),
                        'tipo_usuario' => 'empresa',
                        'empresa_id' => $empresaId
                    ],
                    'estado' => 'pendiente',
                    'device_registered' => $deviceRegistered
                ],
                // Context data for background notifications
                'notification_context' => [
                    'email' => $email, 
                    'input' => $input, 
                    'representante_nombre' => $representante['nombre_completo'], 
                    'logo_url' => $logoUrl,
                    'empresa_id' => $empresaId,
                    'nombre_empresa' => $input['nombre_empresa']
                ]
            ];
            
        } catch (Exception $e) {
            $this->repository->rollback();
            throw $e;
        }
    }

    /**
     * Send notifications for a registration (Emails)
     * Should be called AFTER response is sent to client
     */
    public function sendNotifications($context) {
        $email = $context['email']; // Company/Main Email
        $input = $context['input'];
        $representante = $context['representante_nombre'];
        $logoUrl = $context['logo_url'];
        $empresaId = $context['empresa_id'];
        $nombreEmpresa = $context['nombre_empresa'];

        // 1. Send to Company Email (Main)
        $this->sendWelcomeEmail($email, $input, $representante, $logoUrl);
        
        // 2. Send to Personal Email (if provided and different)
        // Check if 'representante_email' is present and different from main email
        $personalEmail = $input['representante_email'] ?? null;
        if ($personalEmail && strtolower(trim($personalEmail)) !== strtolower(trim($email))) {
            // Validate it's a valid email strictly before sending
            if (filter_var($personalEmail, FILTER_VALIDATE_EMAIL)) {
                $this->sendWelcomeEmail($personalEmail, $input, $representante, $logoUrl);
            }
        }
        
        // Notify admins
        $this->notifyAdmins($empresaId, $nombreEmpresa, $email, $representante);
    }
    
    /**
     * Process vehicle types into PostgreSQL array format
     */
    private function processVehicleTypes($tiposVehiculo) {
        if (empty($tiposVehiculo)) {
            return '{}';
        }
        
        $vehiculos = $tiposVehiculo;
        
        // Handle JSON string
        if (is_string($vehiculos)) {
            $decoded = json_decode($vehiculos, true);
            if (json_last_error() === JSON_ERROR_NONE) {
                $vehiculos = $decoded;
            } else {
                $vehiculos = explode(',', $vehiculos);
            }
        }
        
        // Convert to PostgreSQL array
        if (is_array($vehiculos)) {
            return $this->phpArrayToPg($vehiculos);
        }
        
        return '{}';
    }
    
    /**
     * Convert PHP array to PostgreSQL array format
     */
    private function phpArrayToPg($phpArray) {
        if (empty($phpArray)) {
            return '{}';
        }
        
        $escaped = array_map(function($item) {
            return '"' . str_replace('"', '\\"', $item) . '"';
        }, $phpArray);
        
        return '{' . implode(',', $escaped) . '}';
    }
    
    /**
     * Upload logo to R2 storage
     */
    private function uploadLogo() {
        if (!isset($_FILES['logo']) || $_FILES['logo']['error'] === UPLOAD_ERR_NO_FILE) {
            return null;
        }
        
        $file = $_FILES['logo'];
        
        if ($file['error'] !== UPLOAD_ERR_OK) {
            throw new Exception('Error en la subida del archivo: ' . $file['error']);
        }
        
        // Validate size (5MB)
        if ($file['size'] > 5 * 1024 * 1024) {
            throw new Exception('El archivo excede el tamaño máximo permitido (5MB)');
        }
        
        // Validate type
        $allowedTypes = ['image/jpeg', 'image/png', 'image/webp', 'image/jpg'];
        $finfo = finfo_open(FILEINFO_MIME_TYPE);
        $mimeType = finfo_file($finfo, $file['tmp_name']);
        finfo_close($finfo);
        
        if (!in_array($mimeType, $allowedTypes)) {
            throw new Exception('Tipo de archivo no permitido. Solo se permiten JPG, PNG y WEBP.');
        }
        
        // Upload to R2
        $year = date('Y');
        $month = date('m');
        $extension = pathinfo($file['name'], PATHINFO_EXTENSION);
        $filename = "empresas/registros/$year/$month/logo_" . time() . '_' . bin2hex(random_bytes(8)) . '.' . $extension;
        
        try {
            require_once __DIR__ . '/../../config/R2Service.php';
            $r2 = new R2Service();
            return $r2->uploadFile($file['tmp_name'], $filename, $mimeType);
        } catch (Exception $e) {
            error_log('Error subiendo logo a R2: ' . $e->getMessage());
            return null; // Don't fail registration if logo upload fails
        }
    }
    
    /**
     * Process representative name into nombre and apellido
     */
    private function processRepresentativeName($input) {
        $nombreCompleto = trim($input['representante_nombre']);
        $nombre = trim($input['representante_nombre']);
        $apellido = '';
        
        // If apellido sent separately (recommended), use it
        if (isset($input['representante_apellido']) && !empty($input['representante_apellido'])) {
            $nombre = trim($input['representante_nombre']);
            $apellido = trim($input['representante_apellido']);
            $nombreCompleto = $nombre . ' ' . $apellido;
        } else {
            // Fallback: try to split full name
            $nombreParts = explode(' ', $nombreCompleto, 2);
            $nombre = $nombreParts[0];
            $apellido = $nombreParts[1] ?? '';
        }
        
        return [
            'nombre' => $nombre,
            'apellido' => $apellido,
            'nombre_completo' => $nombreCompleto
        ];
    }
    
    /**
     * Prepare empresa data for database insertion
     */
    private function prepareEmpresaData($input, $email, $tiposVehiculo, $logoUrl, $representanteNombre) {
        return [
            'nombre' => trim($input['nombre_empresa']),
            'nit' => $input['nit'] ?? null,
            'razon_social' => $input['razon_social'] ?? null,
            'email' => $email,
            'telefono' => trim($input['telefono']),
            'telefono_secundario' => $input['telefono_secundario'] ?? null,
            'direccion' => $input['direccion'] ?? null,
            'municipio' => $input['municipio'] ?? null,
            'departamento' => $input['departamento'] ?? null,
            'representante_nombre' => $representanteNombre,
            'representante_telefono' => $input['representante_telefono'] ?? $input['telefono'],
            'representante_email' => $input['representante_email'] ?? $email,
            'tipos_vehiculo' => $tiposVehiculo,
            'logo_url' => $logoUrl,
            'descripcion' => $input['descripcion'] ?? null,
            'notas_admin' => 'Registro desde app móvil - pendiente de verificación'
        ];
    }
    
    /**
     * Prepare usuario data for database insertion
     */
    private function prepareUsuarioData($input, $email, $representante, $empresaId) {
        return [
            'uuid' => uniqid('empresa_', true),
            'nombre' => $representante['nombre'],
            'apellido' => $representante['apellido'],
            'email' => $email,
            'telefono' => trim($input['telefono']),
            'hash_contrasena' => password_hash($input['password'], PASSWORD_DEFAULT),
            'empresa_id' => $empresaId
        ];
    }
    
    /**
     * Send welcome email to empresa
     */
    private function sendWelcomeEmail($email, $input, $representante, $logoUrl) {
        try {
            Mailer::sendCompanyWelcomeEmail(
                $email,
                $representante,
                [
                    'nombre_empresa' => $input['nombre_empresa'],
                    'nit' => $input['nit'] ?? null,
                    'razon_social' => $input['razon_social'] ?? null,
                    'email' => $email,
                    'telefono' => trim($input['telefono']),
                    'direccion' => $input['direccion'] ?? null,
                    'municipio' => $input['municipio'] ?? null,
                    'departamento' => $input['departamento'] ?? null,
                    'tipos_vehiculo' => $input['tipos_vehiculo'] ?? [],
                    'representante_nombre' => $representante,
                    'logo_url' => $logoUrl,
                ]
            );
        } catch (Exception $e) {
            error_log("Error sending welcome email: " . $e->getMessage());
            // Don't fail registration if email fails
        }
    }
    
    /**
     * Notify admins about new empresa registration
     */
    private function notifyAdmins($empresaId, $nombreEmpresa, $email, $representante) {
        // Implementation would go here - keeping it simple for now
        error_log("New empresa registered: $nombreEmpresa (ID: $empresaId)");
    }
}
