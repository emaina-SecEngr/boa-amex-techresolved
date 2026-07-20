"""
Identity Threat Detection
Detects impossible travel, credential stuffing,
privilege escalation, service account abuse.
"""
from collections import defaultdict
from datetime import datetime

class IdentityThreatDetector:
    def __init__(self):
        self.user_history = defaultdict(list)
        self.failed_tracker = defaultdict(int)

    def analyze_auth(self, event):
        threats = []
        risk_score = 0
        user = event.get('userIdentity', {}).get('arn', '')
        source_ip = event.get('sourceIPAddress', '')
        event_name = event.get('eventName', '')
        error = event.get('errorCode', '')

        self.user_history[user].append({'ip': source_ip, 'event': event_name, 'error': error})

        # Impossible travel
        history = self.user_history[user]
        if len(history) >= 2 and history[-2]['ip'] != source_ip:
            risk_score += 40; threats.append({'type': 'IMPOSSIBLE_TRAVEL', 'mitre': 'T1078'})

        # Credential stuffing
        if error in ['AccessDenied', 'Client.UnauthorizedAccess']:
            self.failed_tracker[source_ip] += 1
            if self.failed_tracker[source_ip] > 20:
                risk_score += 35; threats.append({'type': 'CREDENTIAL_STUFFING', 'mitre': 'T1110.004'})

        # Privilege escalation
        priv_events = ['CreateRole', 'AttachRolePolicy', 'PutRolePolicy', 'CreateUser']
        if event_name in priv_events:
            priv_history = [h for h in history if h['event'] in priv_events]
            if len(priv_history) <= 1:
                risk_score += 30; threats.append({'type': 'PRIVILEGE_ESCALATION', 'mitre': 'T1098'})

        # Service account interactive login
        if ('service' in user.lower() or 'automation' in user.lower()) and event_name == 'ConsoleLogin':
            risk_score += 50; threats.append({'type': 'SERVICE_ACCOUNT_INTERACTIVE', 'mitre': 'T1078.004'})

        return {'user': user, 'risk_score': min(risk_score, 100), 'threats': threats, 'is_threat': risk_score > 50}
# model/identity_threat.py
from datetime import datetime, timedelta
from math import radians, sin, cos, sqrt, atan2
from collections import defaultdict

class IdentityThreatDetector:
    """
    Detects identity-based threats by analyzing
    authentication patterns across all accounts.
    Complements CrowdStrike Falcon Identity.
    """
    
    def __init__(self):
        self.user_history = defaultdict(list)
        self.failed_login_tracker = defaultdict(int)
    
    def analyze_auth_event(self, event):
        """Analyze authentication event for threats"""
        threats = []
        risk_score = 0
        
        user = event.get('userIdentity', {}).get('arn', '')
        source_ip = event.get('sourceIPAddress', '')
        event_time = event.get('eventTime', '')
        event_name = event.get('eventName', '')
        account_id = event.get('recipientAccountId', '')
        user_agent = event.get('userAgent', '')
        error_code = event.get('errorCode', '')
        
        # Track user history
        self.user_history[user].append({
            'ip': source_ip,
            'time': event_time,
            'account': account_id,
            'event': event_name,
            'error': error_code
        })
        
        # Detection 1: Impossible travel
        travel_result = self._check_impossible_travel(user, source_ip, event_time)
        if travel_result:
            risk_score += 40
            threats.append({
                'type': 'IMPOSSIBLE_TRAVEL',
                'detail': travel_result,
                'mitre': 'T1078 — Valid Accounts'
            })
        
        # Detection 2: Credential stuffing
        if error_code in ['AccessDenied', 'Client.UnauthorizedAccess']:
            self.failed_login_tracker[source_ip] += 1
            if self.failed_login_tracker[source_ip] > 20:
                risk_score += 35
                threats.append({
                    'type': 'CREDENTIAL_STUFFING',
                    'detail': f'{self.failed_login_tracker[source_ip]} failed attempts from {source_ip}',
                    'mitre': 'T1110.004 — Credential Stuffing'
                })
        
        # Detection 3: Privilege escalation
        priv_events = ['CreateRole', 'AttachRolePolicy', 'PutRolePolicy',
                       'CreateUser', 'AddUserToGroup', 'AttachUserPolicy']
        if event_name in priv_events:
            # Check if user normally makes these calls
            history = self.user_history[user]
            priv_history = [h for h in history if h['event'] in priv_events]
            if len(priv_history) <= 1:  # first time ever
                risk_score += 30
                threats.append({
                    'type': 'PRIVILEGE_ESCALATION',
                    'detail': f'{user} called {event_name} for the first time',
                    'mitre': 'T1098 — Account Manipulation'
                })
        
        # Detection 4: Service account used interactively
        if 'service' in user.lower() or 'automation' in user.lower():
            if event_name == 'ConsoleLogin':
                risk_score += 50
                threats.append({
                    'type': 'SERVICE_ACCOUNT_INTERACTIVE',
                    'detail': f'Service account {user} used for console login',
                    'mitre': 'T1078.004 — Cloud Accounts'
                })
        
        # Detection 5: Cross-account role assumption anomaly
        if event_name == 'AssumeRole':
            target_account = event.get('requestParameters', {}).get('roleArn', '').split(':')[4]
            if target_account and target_account != account_id:
                # Check if this cross-account assumption is normal
                cross_history = [
                    h for h in self.user_history[user]
                    if h['event'] == 'AssumeRole' and h['account'] != account_id
                ]
                if len(cross_history) <= 1:
                    risk_score += 25
                    threats.append({
                        'type': 'UNUSUAL_CROSS_ACCOUNT',
                        'detail': f'{user} assumed role in {target_account} (first time)',
                        'mitre': 'T1550 — Use Alternate Authentication Material'
                    })
        
        # Detection 6: Off-hours access
        try:
            hour = datetime.fromisoformat(event_time.replace('Z', '+00:00')).hour
            if 1 <= hour <= 5:  # 1 AM - 5 AM
                if event_name in ['ConsoleLogin', 'AssumeRole']:
                    risk_score += 15
                    threats.append({
                        'type': 'OFF_HOURS_ACCESS',
                        'detail': f'{user} accessed at {hour}:00 UTC',
                        'mitre': 'T1078 — Valid Accounts'
                    })
        except (ValueError, TypeError):
            pass
        
        return {
            'user': user,
            'source_ip': source_ip,
            'event': event_name,
            'account': account_id,
            'risk_score': min(risk_score, 100),
            'threats': threats,
            'is_threat': risk_score > 50,
            'recommended_action': 'QUARANTINE_USER' if risk_score > 70 else 'INVESTIGATE' if risk_score > 40 else 'MONITOR'
        }
    
    def _check_impossible_travel(self, user, current_ip, current_time):
        """Check if user logged in from impossible distance"""
        history = self.user_history[user]
        if len(history) < 2:
            return None
        
        # Get previous login
        prev = history[-2]
        prev_ip = prev['ip']
        prev_time = prev['time']
        
        if prev_ip == current_ip:
            return None
        
        # In production: GeoIP lookup for both IPs
        # Calculate distance and time difference
        # If distance/time > 500mph → impossible travel
        
        # Simplified check: different IP = flag for review
        if prev_ip != current_ip:
            return f"Login from {current_ip} after previous login from {prev_ip}"
        
        return None