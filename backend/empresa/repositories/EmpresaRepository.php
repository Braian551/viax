<?php
/**
 * EmpresaRepository.php
 * Handles all database operations for empresa registration
 * Single Responsibility: Data Persistence Layer
 */

class EmpresaRepository {
    
    private $db;
    
    public function __construct($db) {
        $this->db = $db;
    }
    
    /**
     * Create a new empresa record
     * @return array with id and creado_en
     */
    public function createEmpresa($empresaData) {
        $query = "INSERT INTO empresas_transporte (
            nombre, nit, razon_social, email, telefono, telefono_secundario,
            direccion, municipio, departamento, representante_nombre,
            representante_telefono, representante_email, tipos_vehiculo,
            logo_url, descripcion, estado, verificada, notas_admin
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pendiente', false, ?)
        RETURNING id, creado_en";
        
        $stmt = $this->db->prepare($query);
        $stmt->execute([
            $empresaData['nombre'],
            $empresaData['nit'],
            $empresaData['razon_social'],
            $empresaData['email'],
            $empresaData['telefono'],
            $empresaData['telefono_secundario'],
            $empresaData['direccion'],
            $empresaData['municipio'],
            $empresaData['departamento'],
            $empresaData['representante_nombre'],
            $empresaData['representante_telefono'],
            $empresaData['representante_email'],
            $empresaData['tipos_vehiculo'],
            $empresaData['logo_url'],
            $empresaData['descripcion'],
            $empresaData['notas_admin']
        ]);
        
        return $stmt->fetch(PDO::FETCH_ASSOC);
    }
    
    /**
     * Create a new usuario record for empresa admin
     * @return array with id
     */
    public function createUsuario($userData) {
        $query = "INSERT INTO usuarios (
            uuid, nombre, apellido, email, telefono, hash_contrasena, 
            tipo_usuario, empresa_id, es_activo
        ) VALUES (?, ?, ?, ?, ?, ?, 'empresa', ?, 1)
        RETURNING id";
        
        $stmt = $this->db->prepare($query);
        $stmt->execute([
            $userData['uuid'],
            $userData['nombre'],
            $userData['apellido'],
            $userData['email'],
            $userData['telefono'],
            $userData['hash_contrasena'],
            $userData['empresa_id']
        ]);
        
        return $stmt->fetch(PDO::FETCH_ASSOC);
    }
    
    /**
     * Update empresa with creator user id
     */
    public function updateEmpresaCreador($empresaId, $userId) {
        $stmt = $this->db->prepare("UPDATE empresas_transporte SET creado_por = ? WHERE id = ?");
        $stmt->execute([$userId, $empresaId]);
    }
    
    /**
     * Check if email already exists in usuarios table
     */
    public function checkEmailExists($email) {
        $stmt = $this->db->prepare("SELECT id FROM usuarios WHERE email = ? LIMIT 1");
        $stmt->execute([$email]);
        return $stmt->fetch(PDO::FETCH_ASSOC) !== false;
    }
    
    /**
     * Register a device for a user
     */
    public function registerDevice($userId, $deviceUuid) {
        if (empty($deviceUuid)) {
            return false;
        }
        
        $stmt = $this->db->prepare(
            'INSERT INTO user_devices (user_id, device_uuid, trusted) 
             VALUES (?, ?, 1) 
             ON CONFLICT (user_id, device_uuid) DO NOTHING'
        );
        $stmt->execute([$userId, trim($deviceUuid)]);
        return true;
    }
    
    /**
     * Log audit action
     */
    public function logAudit($adminId, $action, $tabla, $registroId, $detalles) {
        try {
            // Check if audit_logs table exists
            $checkTable = $this->db->query("SELECT EXISTS (
                SELECT FROM information_schema.tables 
                WHERE table_name = 'audit_logs'
            )");
            $exists = $checkTable->fetchColumn();
            
            if (!$exists) {
                return;
            }
            
            $query = "INSERT INTO audit_logs (admin_id, action, tabla_afectada, registro_id, detalles, ip_address) 
                      VALUES (?, ?, ?, ?, ?, ?)";
            $stmt = $this->db->prepare($query);
            $stmt->execute([
                $adminId,
                $action,
                $tabla,
                $registroId,
                json_encode($detalles),
                $_SERVER['REMOTE_ADDR'] ?? 'unknown'
            ]);
        } catch (Exception $e) {
            error_log("Error al registrar auditoría: " . $e->getMessage());
        }
    }
    
    /**
     * Begin database transaction
     */
    public function beginTransaction() {
        $this->db->beginTransaction();
    }
    
    /**
     * Commit database transaction
     */
    public function commit() {
        $this->db->commit();
    }
    
    /**
     * Rollback database transaction
     */
    public function rollback() {
        $this->db->rollBack();
    }
}
