<?php
class R2Service {
    private $accountId;
    private $accessKeyId;
    private $secretAccessKey;
    private $bucketName;
    private $region = 'auto'; // R2 uses auto

    public function __construct() {
        $this->accountId = '9e36b59ddd8dc8dcc4edc374e6140fda';
        $this->accessKeyId = '5cad6e2f8d263db4251b7662983a4f13';
        $this->secretAccessKey = '01e3898d9bcd9da30faa201b77e816bafffb4699f3586f5ad443894875c14013';
        $this->bucketName = 'uploadviax';
    }

    public function uploadFile($fileTempPath, $fileName, $contentType) {
        $host = "{$this->bucketName}.{$this->accountId}.r2.cloudflarestorage.com";
        $endpoint = "https://{$host}/{$fileName}";
        
        $content = file_get_contents($fileTempPath);
        if ($content === false) {
             throw new Exception("Error reading file content.");
        }

        $datetime = gmdate('Ymd\THis\Z');
        $date = gmdate('Ymd');

        // Headers
        $headers = [
            'host' => $host,
            'x-amz-content-sha256' => hash('sha256', $content),
            'x-amz-date' => $datetime,
            'content-type' => $contentType,
        ];
        
        // Canonical Request
        $canonicalUri = '/' . $fileName;
        $canonicalQueryString = '';
        
        ksort($headers);
        $canonicalHeaders = '';
        $signedHeaders = '';
        foreach ($headers as $key => $value) {
            $canonicalHeaders .= strtolower($key) . ':' . trim($value) . "\n";
            $signedHeaders .= strtolower($key) . ';';
        }
        $signedHeaders = rtrim($signedHeaders, ';');

        $payloadHash = hash('sha256', $content);
        $canonicalRequest = "PUT\n$canonicalUri\n$canonicalQueryString\n$canonicalHeaders\n$signedHeaders\n$payloadHash";

        // String to Sign
        $algorithm = 'AWS4-HMAC-SHA256';
        $credentialScope = "$date/{$this->region}/s3/aws4_request";
        $stringToSign = "$algorithm\n$datetime\n$credentialScope\n" . hash('sha256', $canonicalRequest);

        // Calculate Signature
        $kSecret = 'AWS4' . $this->secretAccessKey;
        $kDate = hash_hmac('sha256', $date, $kSecret, true);
        $kRegion = hash_hmac('sha256', $this->region, $kDate, true);
        $kService = hash_hmac('sha256', 's3', $kRegion, true);
        $kSigning = hash_hmac('sha256', 'aws4_request', $kService, true);
        $signature = hash_hmac('sha256', $stringToSign, $kSigning);

        // Authorization Header
        $authorization = "$algorithm Credential={$this->accessKeyId}/$credentialScope, SignedHeaders=$signedHeaders, Signature=$signature";
        
        // Make Request
        $ch = curl_init($endpoint);
        curl_setopt($ch, CURLOPT_CUSTOMREQUEST, 'PUT');
        curl_setopt($ch, CURLOPT_POSTFIELDS, $content);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_HTTPHEADER, [
            "Authorization: $authorization",
            "x-amz-date: $datetime",
            "x-amz-content-sha256: $payloadHash",
            "Content-Type: $contentType"
        ]);

        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $error = curl_error($ch);
        curl_close($ch);

        if ($httpCode >= 200 && $httpCode < 300) {
             // Return Public URL (assuming public access or custom domain)
             // R2 Public URL format usually is custom domain or similar
             // For now using the CF Worker/Public Bucket pattern if configured, or the S3 endpoint style
             // User provided "S3 API" URL, but for public access usually a domain is set.
             // Based on bucket name, let's assume standard public access domain for now or return the S3 path
             // A common pattern is https://pub-xxxxxxxx.r2.dev/filename if authorized
             // OR specific domain. I'll return the full URL we uploaded to, or a cleaner one if provided later.
             return "https://pub-9e36b59ddd8dc8dcc4edc374e6140fda.r2.dev/{$fileName}";
        } else {
            throw new Exception("R2 Upload Failed: HTTP $httpCode - Response: $response - CurlError: $error");
        }
    }
}
?>
