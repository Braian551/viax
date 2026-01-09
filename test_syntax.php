<?php
ini_set('display_errors', 1);
error_reporting(E_ALL);

echo "Testing imports...\n";

try {
    require_once __DIR__ . '/backend/empresa/validators/EmpresaValidator.php';
    echo "✓ Validator imported\n";
    
    require_once __DIR__ . '/backend/empresa/repositories/EmpresaRepository.php';
    echo "✓ Repository imported\n";
    
    // Check Mailer import path relative to Service
    // Service is in backend/empresa/services/EmpresaService.php
    // It calls require_once __DIR__ . '/../../utils/Mailer.php';
    // Let's test that specific require
    
    require_once __DIR__ . '/backend/empresa/services/EmpresaService.php';
    echo "✓ Service imported\n";
    
    require_once __DIR__ . '/backend/empresa/controllers/EmpresaController.php';
    echo "✓ Controller imported\n";
    
    echo "All syntax checks passed!\n";
    
} catch (Throwable $e) {
    echo "❌ Error: " . $e->getMessage() . "\n";
    echo "File: " . $e->getFile() . "\n";
    echo "Line: " . $e->getLine() . "\n";
}
