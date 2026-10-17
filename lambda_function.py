import json
import re


def lambda_handler(event, context):
    try:
        body = event.get("body", "{}")
        if isinstance(body, str) and body:
            try:
                body = json.loads(body)
            except json.JSONDecodeError:
                pass

        target_payload = (
            body.get("payload", "") if isinstance(body, dict) else str(body)
        )

        if not target_payload:
            return {
                "statusCode": 400,
                "headers": {"Content-Type": "application/json"},
                "body": json.dumps(
                    {"error": 'Parameter "payload" tidak ditemukan dalam body.'}
                ),
            }

        threat_score = 0
        detected_vectors = []

        # 1. Deteksi SQL Injection (SQLi)
        sqli_patterns = [
            r"(?i)(union\s+select)",
            r"(?i)('.*?(\bOR\b|\bAND\b).*?(=|>|<))",
            r"(?i)(--|\#|\/\*)",
            r"(?i)(exec\s+xp_)",
            r"(?i)(\bSELECT\b.*?\bFROM\b)",
        ]
        for pattern in sqli_patterns:
            if re.search(pattern, target_payload):
                threat_score += 45
                detected_vectors.append("SQL Injection")
                break

        # 2. Deteksi Path Traversal / Broken Access Control
        bac_patterns = [
            r"(\.\.\/|\.\.\\)",
            r"(?i)(/etc/passwd|/windows/win.ini)",
            r"(?i)(admin=true|role=admin|auth=0)",
        ]
        for pattern in bac_patterns:
            if re.search(pattern, target_payload):
                threat_score += 40
                detected_vectors.append("Path Traversal / BAC")
                break

        risk_level = "LOW"
        if threat_score >= 70:
            risk_level = "CRITICAL"
        elif threat_score >= 35:
            risk_level = "HIGH"

        return {
            "statusCode": 200,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({
                "analyzed_payload": target_payload,
                "threat_score": threat_score,
                "risk_level": risk_level,
                "detected_vectors": detected_vectors,
            }),
        }

    except Exception as e:
        return {
            "statusCode": 500,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": str(e)}),
        }