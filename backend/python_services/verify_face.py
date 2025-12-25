import sys
import json
import time

# MOCK IMPLEMENTATION OF VERIFY_FACE.PY
# Use this when dlib/face_recognition cannot be installed on the host machine.
# This script simulates a successful verification after a short delay.

def verify_biometrics_mock(selfie_path, id_doc_path, blocked_faces_paths):
    # Simulate processing time
    time.sleep(1.0) 
    
    # Logic: Always return verified for testing purposes
    # You can change this to "mismatch" or "blocked" to test other scenarios
    
    # Check if files exist (basic validation)
    try:
        with open(selfie_path, 'rb') as f:
            pass
        with open(id_doc_path, 'rb') as f:
            pass
    except IOError:
         return {"status": "error", "message": "File not found"}

    return {"status": "verified", "message": "Biometric verification successful (MOCK)"}

if __name__ == "__main__":
    # Same argument parsing as the real script
    if len(sys.argv) < 3:
        print(json.dumps({"status": "error", "message": "Missing arguments"}))
        sys.exit(1)

    selfie = sys.argv[1]
    id_doc = sys.argv[2]
    blocked_list = []
    
    # Return mock result
    result = verify_biometrics_mock(selfie, id_doc, blocked_list)
    print(json.dumps(result))
