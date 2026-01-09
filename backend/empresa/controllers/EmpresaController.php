<?php
/**
 * EmpresaController.php
 * Handles HTTP requests for empresa operations
 * Single Responsibility: HTTP Layer
 */

require_once __DIR__ . '/../services/EmpresaService.php';

class EmpresaController {
    
    private $service;
    
    public function __construct($db) {
        $this->service = new EmpresaService($db);
    }
    
    /**
     * Handle incoming HTTP request
     */
    public function handleRequest($input) {
        $action = $input['action'] ?? 'register';
        
        switch ($action) {
            case 'register':
                return $this->register($input);
            default:
                http_response_code(400);
                return $this->jsonResponse(false, 'Acción no válida');
        }
    }
    
    /**
     * Handle empresa registration
     */
    private function register($input) {
        try {
            // 1. Process Database Registration (Fast)
            $result = $this->service->processRegistration($input);
            
            // 2. Send Response to User (Closes connection)
            http_response_code(200);
            $this->jsonResponse(
                $result['success'],
                $result['message'],
                $result['data'] ?? []
            );
            
            // 3. Send Notifications (Slow - running in background)
            // This happens AFTER the user gets the response
            if (isset($result['notification_context'])) {
                // Close session/connection if not already closed by jsonResponse
                if (function_exists('fastcgi_finish_request')) {
                    fastcgi_finish_request();
                }
                
                // Increase time limit for email sending
                set_time_limit(120); 
                
                $this->service->sendNotifications($result['notification_context']);
            }
            
            exit;
            
        } catch (Exception $e) {
            error_log("Empresa registration error: " . $e->getMessage());
            error_log("Stack trace: " . $e->getTraceAsString());
            
            http_response_code(500);
            // Can't use $this->jsonResponse here if headers already sent, but let's try
            return $this->jsonResponse(
                false,
                $e->getMessage(),
                [
                    'debug_error' => $e->getMessage(),
                    'debug_line' => $e->getLine(),
                    'debug_file' => basename($e->getFile())
                ]
            );
        }
    }
    
    /**
     * Format JSON response
     */
    /**
     * Format JSON response and close connection immediately
     * to allow background processing (like sending emails)
     */
    private function jsonResponse($success, $message, $data = []) {
        $response = [
            'success' => $success,
            'message' => $message
        ];
        
        if (!empty($data)) {
            $response['data'] = $data;
        }
        
        $json = json_encode($response);
        
        // Clear all existing buffers
        while (ob_get_level()) {
            ob_end_clean();
        }
        
        // Headers to force connection close
        header('Connection: close');
        header('Content-Encoding: none');
        header('Content-Length: ' . strlen($json));
        
        // Send content
        ignore_user_abort(true); // Continue setup even if user "disconnects"
        echo $json;
        
        // Flush to client
        if (function_exists('fastcgi_finish_request')) {
            fastcgi_finish_request();
        } else {
            flush();
        }
        
        // Note: Do NOT exit here if we want to continue execution in caller
        // But for this helper, we usually want to return execution control
    }
}
