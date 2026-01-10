<?php
require_once __DIR__ . '/../vendor/autoload.php';
require_once __DIR__ . '/../config/R2Service.php';

class PdfGenerator {
    
    public function generateRegistrationPdf($data) {
        // Create new PDF document
        $pdf = new TCPDF(PDF_PAGE_ORIENTATION, PDF_UNIT, PDF_PAGE_FORMAT, true, 'UTF-8', false);

        // Set document information
        $pdf->SetCreator('Viax Platform');
        $pdf->SetAuthor('Viax');
        $pdf->SetTitle('Registro de Empresa - ' . $data['nombre_empresa']);
        $pdf->SetSubject('Confirmación de Registro');

        // Remove default header/footer
        $pdf->setPrintHeader(false);
        $pdf->setPrintFooter(false);

        // Set margins
        $pdf->SetMargins(15, 15, 15);
        $pdf->SetAutoPageBreak(TRUE, 15);

        // Add a page
        $pdf->AddPage();
        
        // --- 1. Header (Logo App + Title) ---
        $appLogoPath = __DIR__ . '/../assets/images/logo.png';
        if (file_exists($appLogoPath)) {
            $pdf->Image($appLogoPath, 15, 10, 25, '', 'PNG', '', 'T', false, 300, '', false, false, 0, false, false, false);
        }
        
        $pdf->SetFont('helvetica', 'B', 20);
        $pdf->SetXY(45, 15);
        $pdf->Cell(0, 10, 'Registro de Empresa', 0, 1, 'L');
        
        $pdf->SetFont('helvetica', '', 10);
        $pdf->SetXY(45, 24);
        $pdf->SetTextColor(100, 100, 100);
        $pdf->Cell(0, 10, 'Comprobante de Solicitud de Vinculación', 0, 1, 'L');
        
        $pdf->SetTextColor(0, 0, 0); // Reset color
        $pdf->Ln(10);
        $pdf->Line(15, 35, 195, 35); // Separator line
        
        // --- 2. Company Logo (Center) ---
        $logoTempFile = null;
        if (!empty($data['logo_url'])) {
            $logoTempFile = $this->fetchImage($data['logo_url']);
            if ($logoTempFile && file_exists($logoTempFile)) {
                $pdf->Ln(5);
                // Center the image
                $pdf->Image($logoTempFile, 85, 40, 40, 40, '', '', '', false, 300, 'C', false, false, 0, false, false, false);
                $pdf->Ln(45); // Space after image
            } else {
                 $pdf->Ln(10);
            }
        } else {
             $pdf->Ln(10);
        }

        // --- 3. Company Details ---
        $pdf->SetFont('helvetica', 'B', 14);
        $pdf->Cell(0, 10, 'Información de la Empresa', 0, 1, 'L');
        $pdf->Ln(2);

        $this->addDetailRow($pdf, 'Nombre Comercial', $data['nombre_empresa']);
        $this->addDetailRow($pdf, 'Razón Social', $data['razon_social']);
        $this->addDetailRow($pdf, 'NIT', $data['nit']);
        $this->addDetailRow($pdf, 'Email Corporativo', $data['email']);
        $this->addDetailRow($pdf, 'Teléfono', $data['telefono']);
        if (!empty($data['telefono_secundario'])) {
            $this->addDetailRow($pdf, 'Teléfono Secundario', $data['telefono_secundario']);
        }
        
        $ubicacion = ($data['municipio'] ?? '') . ', ' . ($data['departamento'] ?? '');
        $this->addDetailRow($pdf, 'Ubicación', trim($ubicacion, ', '));
        $this->addDetailRow($pdf, 'Dirección', $data['direccion']);
        
        // Vehicles
        $vehiculos = $this->formatVehicles($data['tipos_vehiculo']);
        $this->addDetailRow($pdf, 'Tipos de Vehículo', $vehiculos);

        $pdf->Ln(5);
        
        // --- 4. Representative Details ---
        $pdf->SetFont('helvetica', 'B', 14);
        $pdf->Cell(0, 10, 'Representante Legal', 0, 1, 'L');
        $pdf->Ln(2);
        
        $this->addDetailRow($pdf, 'Nombre Completo', $data['representante_nombre']);
        if (!empty($data['representante_telefono'])) {
            $this->addDetailRow($pdf, 'Teléfono Personal', $data['representante_telefono']);
        }
        if (!empty($data['representante_email'])) {
            $this->addDetailRow($pdf, 'Email Personal', $data['representante_email']);
        }

        // --- 5. Footer / Status ---
        $pdf->Ln(15);
        
        $pdf->SetFillColor(240, 248, 255); // Light blue
        $pdf->SetDrawColor(200, 200, 200);
        $pdf->RoundedRect($pdf->GetX(), $pdf->GetY(), 180, 25, 3.50, '1111', 'DF');
        
        $pdf->SetXY($pdf->GetX() + 5, $pdf->GetY() + 5);
        $pdf->SetFont('helvetica', 'B', 11);
        $pdf->SetTextColor(13, 110, 253); // Blue accent
        $pdf->Cell(0, 7, 'Estado: Pendiente de Aprobación', 0, 1);
        
        $pdf->SetX($pdf->GetX() + 5);
        $pdf->SetFont('helvetica', '', 10);
        $pdf->SetTextColor(80, 80, 80);
        $pdf->Cell(0, 7, 'Documento generado automáticamente el ' . date('d/m/Y H:i A'), 0, 1);
        
        // Cleanup temp logo if created
        if ($logoTempFile && file_exists($logoTempFile)) {
            @unlink($logoTempFile);
        }

        // Output PDF to a temporary file path
        $tempPdfPath = tempnam(sys_get_temp_dir(), 'viax_reg_') . '.pdf';
        $pdf->Output($tempPdfPath, 'F');
        
        return $tempPdfPath;
    }
    
    private function addDetailRow($pdf, $label, $value) {
        $pdf->SetFont('helvetica', 'B', 11);
        $pdf->SetTextColor(50, 50, 50);
        $pdf->Cell(50, 8, $label . ':', 0, 0, 'L');
        
        $pdf->SetFont('helvetica', '', 11);
        $pdf->SetTextColor(0, 0, 0);
        $pdf->Cell(0, 8, $value, 0, 1, 'L');
        
        // Light separator line
        $y = $pdf->GetY();
        $pdf->SetDrawColor(240, 240, 240);
        $pdf->Line(15, $y, 195, $y);
        $pdf->Ln(2);
    }
    
    private function fetchImage($urlOrPath) {
        if (empty($urlOrPath)) return null;

        // If it's a URL, download it with timeout
        if (filter_var($urlOrPath, FILTER_VALIDATE_URL)) {
             // Create context with timeout
             $ctx = stream_context_create([
                 'http' => ['timeout' => 5], // 5 seconds max
                 'https' => ['timeout' => 5]
             ]);
             
             $content = @file_get_contents($urlOrPath, false, $ctx);
             if ($content) {
                 $path = tempnam(sys_get_temp_dir(), 'img_dl');
                 file_put_contents($path, $content);
                 return $path;
             }
        } 
        // If it looks like an R2 key (relative path)
        else {
            try {
                // We use R2Service, but we need to ensure it doesn't hang forever
                // R2Service uses curl, we should check timeouts there if possible, 
                // but here we just wrap it.
                $r2 = new R2Service();
                $fileData = $r2->getFile($urlOrPath);
                if ($fileData && !empty($fileData['content'])) {
                     $path = tempnam(sys_get_temp_dir(), 'img_r2');
                     file_put_contents($path, $fileData['content']);
                     return $path;
                }
            } catch (Exception $e) {
                error_log("PDF Gen: Failed to fetch image (R2): " . $e->getMessage());
            }
        }
        return null; // Failed or empty
    }
    
    private function formatVehicles($types) {
        if (empty($types)) return 'N/A';
        
        if (is_string($types)) {
            $decoded = json_decode($types, true);
            if (json_last_error() === JSON_ERROR_NONE && is_array($decoded)) {
                $types = $decoded;
            } else {
                $types = explode(',', str_replace(['[',']','"'], '', $types)); 
            }
        }
        
        if (is_array($types)) {
             return implode(', ', array_map('ucfirst', $types));
        }
        return ucfirst($types);
    }
}
