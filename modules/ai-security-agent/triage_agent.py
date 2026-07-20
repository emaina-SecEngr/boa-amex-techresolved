"""AI Security Agent — Bedrock-backed finding triage + authorized SOAR invocation"""
import json
import logging
import os

import boto3

logger = logging.getLogger("ai-security-agent")
logger.setLevel(logging.INFO)

BEDROCK_MODEL_ID = os.environ["BEDROCK_MODEL_ID"]
BEDROCK_REGION = os.environ["BEDROCK_REGION"]
SOAR_DISPATCHER_ARN = os.environ.get("SOAR_DISPATCHER_ARN", "")
ALLOWED_PLAYBOOKS = json.loads(os.environ.get("ALLOWED_PLAYBOOKS", "[]"))
SOAR_PLAYBOOK_CATALOG = json.loads(os.environ.get("SOAR_PLAYBOOK_CATALOG", "[]"))
ENABLE_AUTONOMOUS_RESPONSE = os.environ.get("ENABLE_AUTONOMOUS_RESPONSE", "false").lower() == "true"
TRIAGE_SNS_TOPIC_ARN = os.environ["TRIAGE_SNS_TOPIC_ARN"]

bedrock = boto3.client("bedrock-runtime", region_name=BEDROCK_REGION)
lambda_client = boto3.client("lambda")
sns = boto3.client("sns")

SYSTEM_PROMPT = """You are a security triage analyst for a bank's AWS environment. You will be given
a single security finding (GuardDuty or Security Hub). Respond with ONLY a JSON object, no other
text, with these exact keys:
  "summary": one or two sentence plain-language explanation of the finding and why it matters
  "severity_assessment": your own severity judgment - one of "low", "medium", "high", "critical"
  "recommended_playbook": the single best matching playbook name from the allowed catalog below,
      or the literal string "none" if nothing in the catalog is an appropriate response
  "confidence": your confidence in recommended_playbook, a number from 0.0 to 1.0
  "reasoning": one sentence on why you chose that playbook (or "none")

Valid playbook names you may choose from: {catalog}
"""


def lambda_handler(event, context):
    logger.info("Received event: %s", json.dumps(event))

    finding = {
        "source": event.get("source", "unknown"),
        "finding_type": event.get("finding_type", "unknown"),
        "severity": event.get("severity", 0),
        "account_id": event.get("account_id", "unknown"),
        "region": event.get("region", ""),
        "resource_arn": event.get("resource_arn", ""),
        "finding_id": event.get("finding_id", "unknown"),
    }

    decision = triage(finding)
    decision["finding"] = finding
    decision["soar_invoked"] = False
    decision["soar_invoke_error"] = None

    if ENABLE_AUTONOMOUS_RESPONSE and decision["recommended_playbook"] != "none":
        if decision["recommended_playbook"] in ALLOWED_PLAYBOOKS and decision["recommended_playbook"] in SOAR_PLAYBOOK_CATALOG:
            try:
                invoke_soar(finding, decision["recommended_playbook"])
                decision["soar_invoked"] = True
            except Exception as exc:  # report the failure in the audit trail, don't crash the triage record
                decision["soar_invoke_error"] = str(exc)
                logger.error("SOAR invocation failed: %s", decision["soar_invoke_error"])
        else:
            logger.info(
                "recommended_playbook '%s' not authorized (allowed_playbooks=%s) - triage only",
                decision["recommended_playbook"], ALLOWED_PLAYBOOKS,
            )

    publish_decision(finding, decision)
    logger.info("Triage complete: %s", json.dumps(decision))
    return decision


def triage(finding):
    prompt = SYSTEM_PROMPT.format(catalog=", ".join(SOAR_PLAYBOOK_CATALOG))
    response = bedrock.converse(
        modelId=BEDROCK_MODEL_ID,
        system=[{"text": prompt}],
        messages=[{"role": "user", "content": [{"text": json.dumps(finding)}]}],
        inferenceConfig={"maxTokens": 500, "temperature": 0},
    )
    text = response["output"]["message"]["content"][0]["text"]
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        logger.error("Model did not return valid JSON: %s", text)
        return {
            "summary": text[:500],
            "severity_assessment": "unknown",
            "recommended_playbook": "none",
            "confidence": 0.0,
            "reasoning": "Model response was not valid JSON - defaulting to no action.",
        }


def invoke_soar(finding, playbook):
    payload = {
        "playbook": playbook,
        "source": finding["source"],
        "finding_type": finding["finding_type"],
        "severity": finding["severity"],
        "account_id": finding["account_id"],
        "resource_arn": finding["resource_arn"],
        "finding_id": finding["finding_id"],
    }
    lambda_client.invoke(
        FunctionName=SOAR_DISPATCHER_ARN,
        InvocationType="Event",
        Payload=json.dumps(payload).encode("utf-8"),
    )
    logger.info("Invoked SOAR dispatcher with payload: %s", json.dumps(payload))


def publish_decision(finding, decision):
    subject = f"AI Agent Triage: {finding['finding_type']}"[:100]
    sns.publish(
        TopicArn=TRIAGE_SNS_TOPIC_ARN,
        Subject=subject,
        Message=json.dumps(decision, indent=2),
    )
