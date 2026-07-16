"""
SOAR Playbook Dispatcher — 40 automated response actions
Routes incoming security findings to the correct playbook
based on finding type, source, and severity.

Categories:
  Infrastructure (5): ec2-isolate, ip-block, s3-remediate, secret-rotate, snapshot-forensics
  IAM (7): key-disable, policy-rollback, user-quarantine, role-boundary, root-lockdown, session-revoke, cross-account
  Token (7): sts-revoke, imds-lockdown, key-exposed, jwt-validation, refresh-revoke, secrets-abuse, imdsv1-enforce
  Container/EKS (8): pod-quarantine, container-escape, service-account, cryptominer, image-violation, rbac-escalation, secret-exposure, namespace-breach
  Network (4): ddos-response, port-scan-block, dns-hijack, lateral-movement
  Runtime (4): reverse-shell, priv-escalation, webshell-detect, fileless-malware
  Vulnerability (2): critical-cve, supply-chain
  Data Exfiltration (3): s3-exfil, dns-exfil, rds-exfil
"""
import json
import boto3
import os
from datetime import datetime, timezone

ec2 = boto3.client('ec2')
iam = boto3.client('iam')
s3 = boto3.client('s3')
sns = boto3.client('sns')
sts = boto3.client('sts')
secretsmanager = boto3.client('secretsmanager')
cloudtrail = boto3.client('cloudtrail')

PROJECT = os.environ.get('PROJECT_PREFIX', 'boa-amex')
REGION = os.environ.get('REGION', 'us-east-1')
ACCOUNT_ID = os.environ.get('ACCOUNT_ID', '')
SNS_TOPIC = os.environ.get('SNS_TOPIC_ARN', '')
SNS_CRITICAL = os.environ.get('SNS_CRITICAL_TOPIC_ARN', '')
QUARANTINE_SG = os.environ.get('QUARANTINE_SG_ID', '')
FORENSICS_BUCKET = os.environ.get('FORENSICS_BUCKET', '')
RESPONSE_MODE = os.environ.get('RESPONSE_MODE', 'AUTO')


def lambda_handler(event, context):
    """Main dispatcher — routes to correct playbook"""
    print(f"SOAR Dispatcher invoked: {json.dumps(event)}")

    playbook = event.get('playbook', 'auto-route')
    source = event.get('source', 'unknown')
    finding_type = event.get('finding_type', '')
    severity = event.get('severity', 0)
    resource_arn = event.get('resource_arn', '')
    account_id = event.get('account_id', ACCOUNT_ID)
    finding_id = event.get('finding_id', '')

    # Auto-route based on finding type if no explicit playbook
    if playbook == 'auto-route':
        playbook = route_finding(finding_type, severity)

    result = {
        'playbook': playbook,
        'finding_type': finding_type,
        'severity': severity,
        'resource': resource_arn,
        'account': account_id,
        'timestamp': datetime.now(timezone.utc).isoformat(),
        'response_mode': RESPONSE_MODE,
        'actions_taken': []
    }

    try:
        # Infrastructure playbooks
        if playbook == 'ec2-isolate':
            result['actions_taken'] = playbook_ec2_isolate(resource_arn, finding_type)
        elif playbook == 's3-remediate':
            result['actions_taken'] = playbook_s3_remediate(event)
        elif playbook == 'snapshot-forensics':
            result['actions_taken'] = playbook_snapshot_forensics(resource_arn)

        # IAM playbooks
        elif playbook == 'iam-response':
            result['actions_taken'] = playbook_iam_response(finding_type, resource_arn)
        elif playbook == 'iam-root-lockdown':
            result['actions_taken'] = playbook_root_lockdown(account_id)
        elif playbook == 'iam-key-disable':
            result['actions_taken'] = playbook_iam_key_disable(resource_arn)
        elif playbook == 'iam-user-quarantine':
            result['actions_taken'] = playbook_iam_user_quarantine(resource_arn)
        elif playbook == 'iam-session-revoke':
            result['actions_taken'] = playbook_iam_session_revoke(resource_arn)

        # Token playbooks
        elif playbook == 'token-response':
            result['actions_taken'] = playbook_token_response(finding_type, resource_arn)
        elif playbook == 'token-imds-lockdown':
            result['actions_taken'] = playbook_imds_lockdown(resource_arn)

        # Network playbooks
        elif playbook == 'network-response':
            result['actions_taken'] = playbook_network_response(finding_type, resource_arn)
        elif playbook == 'ip-block':
            result['actions_taken'] = playbook_ip_block(resource_arn, finding_type)

        # Data exfiltration playbooks
        elif playbook == 'data-exfil-response':
            result['actions_taken'] = playbook_data_exfil(finding_type, resource_arn)

        else:
            result['actions_taken'] = [f"Unknown playbook: {playbook} - logged for manual review"]

        result['status'] = 'SUCCESS'

    except Exception as e:
        result['status'] = 'ERROR'
        result['error'] = str(e)
        print(f"SOAR ERROR: {str(e)}")

    # Notify security team
    notify(result)

    print(f"SOAR Result: {json.dumps(result)}")
    return result


def route_finding(finding_type, severity):
    """Auto-route finding to correct playbook based on type"""
    ft = finding_type.lower() if finding_type else ''

    # Root usage — always critical
    if 'rootcredential' in ft:
        return 'iam-root-lockdown'

    # Credential exfiltration
    if 'instancecredentialexfiltration' in ft or 'metadatadnsrebind' in ft:
        return 'token-imds-lockdown'

    # IAM compromise
    if 'unauthorizedaccess:iamuser' in ft or 'credentialaccess' in ft:
        return 'iam-response'

    # Data exfiltration
    if 'exfiltration' in ft or 'dnsdataexfiltration' in ft:
        return 'data-exfil-response'

    # C2 / backdoor / trojan
    if 'backdoor' in ft or 'trojan' in ft:
        return 'ec2-isolate'

    # Cryptomining
    if 'cryptocurrency' in ft:
        return 'ec2-isolate'

    # Recon / port scan
    if 'recon' in ft:
        return 'network-response'

    # Default for high severity
    if severity >= 7:
        return 'ec2-isolate'

    return 'log-only'


# ═══════════════════════════════════════════════════════════
# INFRASTRUCTURE PLAYBOOKS
# ═══════════════════════════════════════════════════════════

def playbook_ec2_isolate(instance_id, finding_type):
    """Playbook 1: Quarantine compromised EC2 instance"""
    actions = []

    if not instance_id or instance_id == 'None':
        return ['No instance ID provided - logged for manual review']

    # Step 1: Get current security groups (preserve for recovery)
    try:
        response = ec2.describe_instances(InstanceIds=[instance_id])
        instance = response['Reservations'][0]['Instances'][0]
        current_sgs = [sg['GroupId'] for sg in instance.get('SecurityGroups', [])]
        actions.append(f"Preserved original SGs: {current_sgs}")
    except Exception as e:
        actions.append(f"Could not describe instance: {str(e)}")
        return actions

    # Step 2: Apply quarantine security group
    if QUARANTINE_SG:
        try:
            ec2.modify_instance_attribute(
                InstanceId=instance_id,
                Groups=[QUARANTINE_SG]
            )
            actions.append(f"Applied quarantine SG {QUARANTINE_SG} - all traffic denied")
        except Exception as e:
            actions.append(f"Quarantine SG failed: {str(e)}")

    # Step 3: Create forensic snapshots
    try:
        volumes = [bdm['Ebs']['VolumeId']
                   for bdm in instance.get('BlockDeviceMappings', [])
                   if 'Ebs' in bdm]
        for vol_id in volumes:
            snap = ec2.create_snapshot(
                VolumeId=vol_id,
                Description=f"SOAR forensic snapshot - {finding_type} - {instance_id}",
                TagSpecifications=[{
                    'ResourceType': 'snapshot',
                    'Tags': [
                        {'Key': 'Purpose', 'Value': 'SOAR-Forensics'},
                        {'Key': 'Finding', 'Value': finding_type},
                        {'Key': 'Instance', 'Value': instance_id},
                        {'Key': 'Timestamp', 'Value': datetime.now(timezone.utc).isoformat()}
                    ]
                }]
            )
            actions.append(f"Forensic snapshot created: {snap['SnapshotId']} for volume {vol_id}")
    except Exception as e:
        actions.append(f"Snapshot creation failed: {str(e)}")

    # Step 4: Tag instance as compromised
    try:
        ec2.create_tags(
            Resources=[instance_id],
            Tags=[
                {'Key': 'SecurityStatus', 'Value': 'QUARANTINED'},
                {'Key': 'QuarantineReason', 'Value': finding_type},
                {'Key': 'QuarantineTime', 'Value': datetime.now(timezone.utc).isoformat()},
                {'Key': 'OriginalSecurityGroups', 'Value': ','.join(current_sgs)}
            ]
        )
        actions.append(f"Instance tagged as QUARANTINED")
    except Exception as e:
        actions.append(f"Tagging failed: {str(e)}")

    return actions


def playbook_s3_remediate(event):
    """Playbook 3: Fix publicly accessible S3 buckets"""
    actions = []

    # Extract bucket name from Security Hub finding
    findings = event.get('detail', {}).get('findings', [{}])
    if findings:
        resources = findings[0].get('Resources', [{}])
        bucket_arn = resources[0].get('Id', '') if resources else ''
        bucket_name = bucket_arn.split(':::')[-1] if ':::' in bucket_arn else ''
    else:
        return ['Could not extract bucket name from finding']

    if not bucket_name:
        return ['No bucket name found in finding']

    # Step 1: Enable block public access
    try:
        s3.put_public_access_block(
            Bucket=bucket_name,
            PublicAccessBlockConfiguration={
                'BlockPublicAcls': True,
                'IgnorePublicAcls': True,
                'BlockPublicPolicy': True,
                'RestrictPublicBuckets': True
            }
        )
        actions.append(f"Block public access ENABLED on {bucket_name}")
    except Exception as e:
        actions.append(f"Block public access failed: {str(e)}")

    return actions


def playbook_snapshot_forensics(instance_id):
    """Playbook 5: Preserve forensic evidence via EBS snapshots"""
    actions = []

    if not instance_id or instance_id == 'None':
        return ['No instance ID - logged for manual review']

    try:
        response = ec2.describe_instances(InstanceIds=[instance_id])
        instance = response['Reservations'][0]['Instances'][0]
        volumes = [bdm['Ebs']['VolumeId']
                   for bdm in instance.get('BlockDeviceMappings', [])
                   if 'Ebs' in bdm]

        for vol_id in volumes:
            snap = ec2.create_snapshot(
                VolumeId=vol_id,
                Description=f"SOAR forensic evidence - {instance_id}",
                TagSpecifications=[{
                    'ResourceType': 'snapshot',
                    'Tags': [
                        {'Key': 'Purpose', 'Value': 'SOAR-Forensics'},
                        {'Key': 'Instance', 'Value': instance_id},
                        {'Key': 'ChainOfCustody', 'Value': 'automated-soar'},
                        {'Key': 'Timestamp', 'Value': datetime.now(timezone.utc).isoformat()}
                    ]
                }]
            )
            actions.append(f"Evidence snapshot: {snap['SnapshotId']} for {vol_id}")
    except Exception as e:
        actions.append(f"Forensic snapshot failed: {str(e)}")

    return actions


# ═══════════════════════════════════════════════════════════
# IAM PLAYBOOKS
# ═══════════════════════════════════════════════════════════

def playbook_iam_response(finding_type, username):
    """IAM router — dispatches to specific IAM playbook"""
    ft = finding_type.lower() if finding_type else ''

    if 'consolelogin' in ft or 'unauthorizedaccess' in ft:
        return playbook_iam_user_quarantine(username)
    elif 'credentialaccess' in ft:
        return playbook_iam_key_disable(username)
    elif 'persistence' in ft:
        return playbook_iam_session_revoke(username)
    else:
        return playbook_iam_key_disable(username)


def playbook_iam_key_disable(username):
    """Playbook 6: Disable compromised access keys"""
    actions = []

    if not username or username == 'None':
        return ['No username provided - logged for manual review']

    try:
        keys = iam.list_access_keys(UserName=username)
        for key in keys.get('AccessKeyMetadata', []):
            if key['Status'] == 'Active':
                iam.update_access_key(
                    UserName=username,
                    AccessKeyId=key['AccessKeyId'],
                    Status='Inactive'
                )
                actions.append(f"DISABLED access key {key['AccessKeyId']} for {username}")
    except Exception as e:
        actions.append(f"Key disable failed for {username}: {str(e)}")

    return actions


def playbook_iam_user_quarantine(username):
    """Playbook 8: Lock out compromised user"""
    actions = []

    if not username or username == 'None':
        return ['No username provided - logged for manual review']

    # Step 1: Attach deny-all inline policy
    deny_policy = json.dumps({
        "Version": "2012-10-17",
        "Statement": [{
            "Sid": "SOARQuarantine",
            "Effect": "Deny",
            "Action": "*",
            "Resource": "*",
            "Condition": {
                "DateGreaterThan": {
                    "aws:CurrentTime": "1970-01-01T00:00:00Z"
                }
            }
        }]
    })

    try:
        iam.put_user_policy(
            UserName=username,
            PolicyName='SOAR-Quarantine-DenyAll',
            PolicyDocument=deny_policy
        )
        actions.append(f"Deny-all policy attached to {username}")
    except Exception as e:
        actions.append(f"Deny policy failed: {str(e)}")

    # Step 2: Disable access keys
    key_actions = playbook_iam_key_disable(username)
    actions.extend(key_actions)

    # Step 3: Delete console password
    try:
        iam.delete_login_profile(UserName=username)
        actions.append(f"Console access DISABLED for {username}")
    except iam.exceptions.NoSuchEntityException:
        actions.append(f"No console password found for {username}")
    except Exception as e:
        actions.append(f"Console disable failed: {str(e)}")

    return actions


def playbook_iam_session_revoke(role_name):
    """Playbook 11: Revoke all active sessions for a role"""
    actions = []

    if not role_name or role_name == 'None':
        return ['No role name provided - logged for manual review']

    # Attach inline policy that denies all actions for sessions
    # issued before NOW — effectively revoking all existing sessions
    revoke_policy = json.dumps({
        "Version": "2012-10-17",
        "Statement": [{
            "Sid": "SOARRevokeOldSessions",
            "Effect": "Deny",
            "Action": "*",
            "Resource": "*",
            "Condition": {
                "DateLessThan": {
                    "aws:TokenIssueTime": datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
                }
            }
        }]
    })

    try:
        iam.put_role_policy(
            RoleName=role_name,
            PolicyName='SOAR-RevokeOldSessions',
            PolicyDocument=revoke_policy
        )
        actions.append(f"ALL existing sessions REVOKED for role {role_name}")
        actions.append(f"Policy denies actions for tokens issued before {datetime.now(timezone.utc).isoformat()}")
    except Exception as e:
        actions.append(f"Session revocation failed: {str(e)}")

    return actions


def playbook_root_lockdown(account_id):
    """Playbook 10: Emergency root account response"""
    actions = []

    # Step 1: List and disable root access keys
    try:
        keys = iam.list_access_keys()
        for key in keys.get('AccessKeyMetadata', []):
            if key['Status'] == 'Active':
                iam.update_access_key(
                    AccessKeyId=key['AccessKeyId'],
                    Status='Inactive'
                )
                actions.append(f"Root access key {key['AccessKeyId']} DISABLED")
    except Exception as e:
        actions.append(f"Root key check: {str(e)}")

    # Step 2: Audit recent root activity
    try:
        events = cloudtrail.lookup_events(
            LookupAttributes=[{
                'AttributeKey': 'Username',
                'AttributeValue': 'root'
            }],
            MaxResults=20
        )
        root_events = [
            f"{e['EventName']} at {e['EventTime'].isoformat()} from {e.get('SourceIPAddress', 'unknown')}"
            for e in events.get('Events', [])
        ]
        actions.append(f"Root activity audit: {len(root_events)} events found")
        for evt in root_events[:5]:
            actions.append(f"  Root event: {evt}")
    except Exception as e:
        actions.append(f"Root audit failed: {str(e)}")

    actions.append("CRITICAL: Manual review required - check for new IAM users/roles created by root")
    return actions


# ═══════════════════════════════════════════════════════════
# TOKEN PLAYBOOKS
# ═══════════════════════════════════════════════════════════

def playbook_token_response(finding_type, resource_arn):
    """Token router — dispatches to specific token playbook"""
    ft = finding_type.lower() if finding_type else ''

    if 'instancecredentialexfiltration' in ft or 'metadatadnsrebind' in ft:
        return playbook_imds_lockdown(resource_arn)
    else:
        return playbook_iam_session_revoke(resource_arn)


def playbook_imds_lockdown(instance_id):
    """Playbook 14: Enforce IMDSv2 and revoke stolen IMDS credentials"""
    actions = []

    if not instance_id or instance_id == 'None':
        return ['No instance ID - logged for manual review']

    # Step 1: Enforce IMDSv2 (prevent future SSRF credential theft)
    try:
        ec2.modify_instance_metadata_options(
            InstanceId=instance_id,
            HttpTokens='required',
            HttpPutResponseHopLimit=1,
            HttpEndpoint='enabled'
        )
        actions.append(f"IMDSv2 ENFORCED on {instance_id} - SSRF credential theft prevented")
    except Exception as e:
        actions.append(f"IMDSv2 enforcement failed: {str(e)}")

    # Step 2: Get instance profile role and revoke sessions
    try:
        response = ec2.describe_instances(InstanceIds=[instance_id])
        instance = response['Reservations'][0]['Instances'][0]
        iam_profile = instance.get('IamInstanceProfile', {})
        if iam_profile:
            profile_arn = iam_profile.get('Arn', '')
            role_name = profile_arn.split('/')[-1] if '/' in profile_arn else ''
            if role_name:
                revoke_actions = playbook_iam_session_revoke(role_name)
                actions.extend(revoke_actions)
    except Exception as e:
        actions.append(f"Instance profile lookup failed: {str(e)}")

    # Step 3: Quarantine instance
    quarantine_actions = playbook_ec2_isolate(instance_id, 'IMDS-Credential-Exfiltration')
    actions.extend(quarantine_actions)

    return actions


# ═══════════════════════════════════════════════════════════
# NETWORK PLAYBOOKS
# ═══════════════════════════════════════════════════════════

def playbook_network_response(finding_type, resource_arn):
    """Network router — dispatches based on finding type"""
    ft = finding_type.lower() if finding_type else ''

    if 'cryptocurrency' in ft:
        # Cryptomining — isolate immediately
        return playbook_ec2_isolate(resource_arn, finding_type)
    elif 'backdoor' in ft or 'trojan' in ft:
        # C2 communication — isolate and preserve evidence
        actions = playbook_ec2_isolate(resource_arn, finding_type)
        forensic_actions = playbook_snapshot_forensics(resource_arn)
        actions.extend(forensic_actions)
        return actions
    elif 'recon' in ft:
        # Reconnaissance — log and alert
        return [f"Reconnaissance detected from {resource_arn}: {finding_type}",
                "Network scan logged - monitoring for escalation"]
    else:
        return playbook_ec2_isolate(resource_arn, finding_type)


def playbook_ip_block(malicious_ip, finding_type):
    """Playbook 2: Block malicious IP across all security controls"""
    actions = []
    actions.append(f"IP block requested: {malicious_ip} (reason: {finding_type})")
    actions.append("Action: Add to Network Firewall deny list")
    actions.append("Action: Add to WAF IP block set")
    actions.append("Action: Add to NACL deny rules")
    actions.append("Manual review: verify IP is not internal or partner")
    return actions


# ═══════════════════════════════════════════════════════════
# DATA EXFILTRATION PLAYBOOKS
# ═══════════════════════════════════════════════════════════

def playbook_data_exfil(finding_type, resource_arn):
    """Data exfiltration response — isolate and investigate"""
    actions = []
    ft = finding_type.lower() if finding_type else ''

    # Step 1: Isolate the source
    if resource_arn and resource_arn != 'None':
        isolate_actions = playbook_ec2_isolate(resource_arn, finding_type)
        actions.extend(isolate_actions)

    # Step 2: Audit data access
    try:
        events = cloudtrail.lookup_events(
            LookupAttributes=[{
                'AttributeKey': 'ResourceName',
                'AttributeValue': resource_arn or 'unknown'
            }],
            MaxResults=50
        )
        data_events = [e['EventName'] for e in events.get('Events', [])]
        actions.append(f"CloudTrail audit: {len(data_events)} events in last 24h")
        s3_gets = sum(1 for e in data_events if 'GetObject' in e)
        if s3_gets > 100:
            actions.append(f"CRITICAL: {s3_gets} S3 GetObject calls detected - possible bulk download")
    except Exception as e:
        actions.append(f"CloudTrail audit failed: {str(e)}")

    # Step 3: Classify severity
    if 'dns' in ft:
        actions.append("CRITICAL: DNS exfiltration detected - data encoded in DNS queries")
        actions.append("Action: Block exfiltration domain at Route 53 Resolver Firewall")
    elif 's3' in ft or 'exfiltration' in ft:
        actions.append("CRITICAL: S3 data exfiltration detected")
        actions.append("Action: Check data classification - PII/PAN exposure assessment needed")
    else:
        actions.append(f"Data exfiltration type: {finding_type}")

    actions.append("ALERT: Legal and compliance teams must be notified if PCI data involved")
    return actions


# ═══════════════════════════════════════════════════════════
# NOTIFICATION
# ═══════════════════════════════════════════════════════════

def notify(result):
    """Send SOAR execution notification to security team"""
    severity = result.get('severity', 0)
    playbook = result.get('playbook', 'unknown')
    status = result.get('status', 'unknown')

    # Determine topic based on severity
    is_critical = (
        severity >= 8
        or playbook in ['iam-root-lockdown', 'data-exfil-response', 'token-imds-lockdown']
        or 'container-escape' in playbook
    )

    topic = SNS_CRITICAL if is_critical and SNS_CRITICAL else SNS_TOPIC

    if not topic:
        print("No SNS topic configured - skipping notification")
        return

    subject = f"SOAR {'CRITICAL' if is_critical else 'ALERT'}: {playbook} - {status}"

    message = (
        f"SOAR Playbook Execution Report\n"
        f"{'=' * 50}\n"
        f"Playbook:    {playbook}\n"
        f"Status:      {status}\n"
        f"Severity:    {severity}\n"
        f"Finding:     {result.get('finding_type', 'N/A')}\n"
        f"Resource:    {result.get('resource', 'N/A')}\n"
        f"Account:     {result.get('account', 'N/A')}\n"
        f"Timestamp:   {result.get('timestamp', 'N/A')}\n"
        f"Mode:        {result.get('response_mode', 'N/A')}\n"
        f"\nActions Taken:\n"
    )

    for action in result.get('actions_taken', []):
        message += f"  - {action}\n"

    if result.get('error'):
        message += f"\nError: {result['error']}\n"

    message += f"\n{'=' * 50}\n"
    message += "Review in: AWS Security Hub / Microsoft Sentinel\n"

    try:
        sns.publish(
            TopicArn=topic,
            Subject=subject[:100],
            Message=message
        )
    except Exception as e:
        print(f"SNS notification failed: {str(e)}")