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
             // Return Proxy URL relative path
             // Frontend will prepend BaseURL to this: r2_proxy.php?key=...
             return "r2_proxy.php?key={$fileName}";
        } else {
            throw new Exception("R2 Upload Failed: HTTP $httpCode - Response: $response - CurlError: $error");
        }
    }

    public function getFile($fileName) {
        $host = "{$this->bucketName}.{$this->accountId}.r2.cloudflarestorage.com";
        $endpoint = "https://{$host}/{$fileName}";
        
        $datetime = gmdate('Ymd\THis\Z');
        $date = gmdate('Ymd');

        // Headers for GET
        $headers = [
            'host' => $host,
            'x-amz-content-sha256' => hash('sha256', ''), // Empty payload for GET
            'x-amz-date' => $datetime,
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

        $payloadHash = hash('sha256', '');
        $canonicalRequest = "GET\n$canonicalUri\n$canonicalQueryString\n$canonicalHeaders\n$signedHeaders\n$payloadHash";

        // String to Sign
        $stringToSign = "AWS4-HMAC-SHA256\n$datetime\n$date/{$this->region}/s3/aws4_request\n" . hash('sha256', $canonicalRequest);

        // Signature Calculation
        $kSecret = 'AWS4' . $this->secretAccessKey;
        $kDate = hash_hmac('sha256', $date, $kSecret, true);
        $kRegion = hash_hmac('sha256', $this->region, $kDate, true);
        $kService = hash_hmac('sha256', 's3', $kRegion, true);
        $kSigning = hash_hmac('sha256', 'aws4_request', $kService, true);
        $signature = hash_hmac('sha256', $stringToSign, $kSigning);

        $authorization = "AWS4-HMAC-SHA256 Credential={$this->accessKeyId}/$date/{$this->region}/s3/aws4_request, SignedHeaders=$signedHeaders, Signature=$signature";
        
        $ch = curl_init($endpoint);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        // Important: passthrough headers might be needed, but R2 returns proper types usually.
        // We will return the raw content.
        curl_setopt($ch, CURLOPT_HTTPHEADER, [
            "Authorization: $authorization",
            "x-amz-date: $datetime",
            "x-amz-content-sha256: $payloadHash"
        ]);

        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $contentType = curl_getinfo($ch, CURLINFO_CONTENT_TYPE);
        curl_close($ch);

        if ($httpCode == 200) {
            return ['content' => $response, 'type' => $contentType];
        }
        return false;
    }
}
?>
