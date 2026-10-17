import json
import logging
import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Inisialisasi client Bedrock Runtime (region us-east-1)
bedrock = boto3.client("bedrock-runtime", region_name="us-east-1")

MODEL_ID = "amazon.nova-micro-v1:0"

def lambda_handler(event, context):
    try:
        # 1. Ekstraksi data HTTP request dari Lambda Function URL (Payload v2)
        method = event.get("requestContext", {}).get("http", {}).get("method", "GET")
        path = event.get("rawPath", "/")
        headers = event.get("headers", {})
        body = event.get("body", "")

        # 2. Susun prompt analisa ancaman
        prompt = f"""You are an automated SOC security triage analyst.
Analyze the following HTTP request captured by a honeypot endpoint:
- HTTP Method: 
{method}
- Path Requested: 
{path}
- Headers: 
{json.dumps(headers)}
- Request Body: 
{body}

Determine if this represents a cyber attack, automated bot scan, or benign traffic.
Respond ONLY with a valid JSON object (no markdown, no backticks, no extra text):
{{
  "is_malicious": true,
  "attack_type": "SQLi or Path Traversal or Reconnaissance or Normal Traffic",
  "severity": "LOW or MEDIUM or HIGH or CRITICAL",
  "intent": "Brief explanation of what the request tries to do",
  "recommended_mitigation": "Short actionable recommendation"
}}"""

        # 3. Panggil Bedrock via Converse API (Menggunakan Variabel Global)
        response = bedrock.converse(
            modelId = MODEL_ID,
            messages=[
                {
                    "role": "user",
                    "content": [{"text": prompt}]
                }
            ],
            inferenceConfig={
                "temperature": 0.0,  # 0.0 agar output deterministik
                "maxTokens": 350
            }
        )

        # 4. Ambil teks jawaban AI
        ai_reply_raw = response["output"]["message"]["content"][0]["text"].strip()

        # Bersihkan format jika model masih menyertakan backticks markdown ```json
        if ai_reply_raw.startswith("```"):
            ai_reply_raw = ai_reply_raw.strip("`").replace("json\n", "", 1).strip()

        try:
            analysis = json.loads(ai_reply_raw)
        except json.JSONDecodeError:
            analysis = {
                "raw_analysis": ai_reply_raw,
                "warning": "Model output non-strict JSON"
            }

        # 5. CloudWatch Structured Logging (Bisa di-filter di CloudWatch Logs Insights)
        client_ip = headers.get("x-forwarded-for", "unknown")
        logger.info(json.dumps({
            "event": "honeypot_threat_triage",
            "client_ip": client_ip,
            "method": method,
            "path": path,
            "analysis": analysis
        }))

        # 6. Response HTTP 200
        return {
            "statusCode": 200,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps(analysis)
        }

    except Exception as e:
        logger.error(f"Execution failed: {str(e)}")
        return {
            "statusCode": 500,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": str(e)})
        }