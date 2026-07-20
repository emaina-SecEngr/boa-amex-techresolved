# model/network_ids.py
import numpy as np
from collections import defaultdict
from datetime import datetime, timedelta

class NetworkIDSModel:
    """
    Analyzes VPC Flow Logs for intrusion indicators.
    Complements GuardDuty with custom patterns specific
    to our bank's network topology.
    """
    
    def __init__(self):
        # Known internal CIDR ranges
        self.internal_ranges = [
            '10.0.0.0/16',   # Security VPC
            '10.1.0.0/16',   # PCI-CDE
            '10.2.0.0/16',   # Dev
            '10.3.0.0/16',   # Core Banking
            '10.4.0.0/16',   # Fraud Detection
        ]
        
        # Track connection state
        self.connection_tracker = defaultdict(list)
    
    def analyze_flow(self, flow_record):
        """Analyze single VPC Flow Log record"""
        threats = []
        risk_score = 0
        
        src_ip = flow_record['srcaddr']
        dst_ip = flow_record['dstaddr']
        dst_port = flow_record['dstport']
        protocol = flow_record['protocol']
        action = flow_record['action']
        bytes_transferred = flow_record.get('bytes', 0)
        
        # Track this connection
        self.connection_tracker[src_ip].append({
            'dst': dst_ip,
            'port': dst_port,
            'time': flow_record['start'],
            'bytes': bytes_transferred
        })
        
        # Detection 1: Port scanning
        recent_connections = self.connection_tracker[src_ip][-100:]
        unique_ports = len(set(c['port'] for c in recent_connections))
        unique_dsts = len(set(c['dst'] for c in recent_connections))
        
        if unique_ports > 20 and len(recent_connections) > 50:
            risk_score += 40
            threats.append({
                'type': 'PORT_SCAN',
                'detail': f'{unique_ports} unique ports scanned from {src_ip}',
                'mitre': 'T1046 — Network Service Discovery'
            })
        
        # Detection 2: Lateral movement
        if unique_dsts > 10 and self._is_internal(src_ip):
            risk_score += 35
            threats.append({
                'type': 'LATERAL_MOVEMENT',
                'detail': f'{unique_dsts} internal hosts contacted from {src_ip}',
                'mitre': 'T1021 — Remote Services'
            })
        
        # Detection 3: Data exfiltration (large outbound transfer)
        if bytes_transferred > 100_000_000 and not self._is_internal(dst_ip):
            risk_score += 45
            threats.append({
                'type': 'DATA_EXFILTRATION',
                'detail': f'{bytes_transferred/1_000_000:.1f}MB transferred to external {dst_ip}',
                'mitre': 'T1048 — Exfiltration Over Alternative Protocol'
            })
        
        # Detection 4: C2 beaconing (regular interval connections)
        if self._detect_beaconing_pattern(src_ip, dst_ip):
            risk_score += 50
            threats.append({
                'type': 'C2_BEACONING',
                'detail': f'Regular interval connections from {src_ip} to {dst_ip}',
                'mitre': 'T1071 — Application Layer Protocol'
            })
        
        # Detection 5: Brute force (many rejected connections)
        if action == 'REJECT' and dst_port in [22, 3389, 5432, 3306]:
            rejected_count = sum(
                1 for c in recent_connections
                if c['dst'] == dst_ip and c['port'] == dst_port
            )
            if rejected_count > 10:
                risk_score += 30
                threats.append({
                    'type': 'BRUTE_FORCE',
                    'detail': f'{rejected_count} rejected connections to {dst_ip}:{dst_port}',
                    'mitre': 'T1110 — Brute Force'
                })
        
        # Detection 6: Cross-VPC communication anomaly
        if self._is_cross_vpc(src_ip, dst_ip):
            if not self._is_allowed_cross_vpc(src_ip, dst_ip, dst_port):
                risk_score += 25
                threats.append({
                    'type': 'UNAUTHORIZED_CROSS_VPC',
                    'detail': f'Unexpected cross-VPC traffic: {src_ip} → {dst_ip}:{dst_port}',
                    'mitre': 'T1599 — Network Boundary Bridging'
                })
        
        return {
            'source_ip': src_ip,
            'destination_ip': dst_ip,
            'destination_port': dst_port,
            'risk_score': min(risk_score, 100),
            'threats': threats,
            'is_malicious': risk_score > 50,
            'recommended_action': self._recommend_action(risk_score, threats)
        }
    
    def _is_internal(self, ip):
        return ip.startswith('10.') or ip.startswith('172.') or ip.startswith('192.168.')
    
    def _is_cross_vpc(self, src, dst):
        src_vpc = src.split('.')[1] if src.startswith('10.') else None
        dst_vpc = dst.split('.')[1] if dst.startswith('10.') else None
        return src_vpc and dst_vpc and src_vpc != dst_vpc
    
    def _is_allowed_cross_vpc(self, src, dst, port):
        # Define allowed cross-VPC communication
        allowed = {
            ('10.1', '10.4', 8000): True,  # PCI-CDE → Fraud on port 8000
            ('10.3', '10.1', 8001): True,  # Core Banking → PCI-CDE on port 8001
        }
        src_prefix = '.'.join(src.split('.')[:2])
        dst_prefix = '.'.join(dst.split('.')[:2])
        return allowed.get((src_prefix, dst_prefix, port), False)
    
    def _detect_beaconing_pattern(self, src, dst):
        connections = [
            c for c in self.connection_tracker[src]
            if c['dst'] == dst
        ]
        if len(connections) < 5:
            return False
        intervals = [
            connections[i+1]['time'] - connections[i]['time']
            for i in range(len(connections)-1)
        ]
        if not intervals:
            return False
        cv = np.std(intervals) / max(np.mean(intervals), 1)
        return cv < 0.3  # low variance = regular pattern
    
    def _recommend_action(self, score, threats):
        if score > 70:
            return 'BLOCK_AND_ISOLATE'
        elif score > 50:
            return 'ALERT_AND_INVESTIGATE'
        elif score > 30:
            return 'MONITOR'
        return 'LOG_ONLY'

"""
Network Intrusion Detection — VPC Flow Log Analysis
Detects port scanning, lateral movement, data exfiltration,
C2 beaconing, brute force, cross-VPC violations.
"""
from collections import defaultdict
import numpy as np

class NetworkIDSModel:
    def __init__(self):
        self.connection_tracker = defaultdict(list)

    def analyze_flow(self, flow):
        threats = []
        risk_score = 0
        src = flow['srcaddr']
        dst = flow['dstaddr']
        port = flow['dstport']
        self.connection_tracker[src].append({'dst': dst, 'port': port, 'time': flow['start'], 'bytes': flow.get('bytes', 0)})
        recent = self.connection_tracker[src][-100:]

        # Port scanning
        if len(set(c['port'] for c in recent)) > 20:
            risk_score += 40; threats.append({'type': 'PORT_SCAN', 'mitre': 'T1046'})

        # Lateral movement
        if len(set(c['dst'] for c in recent)) > 10 and src.startswith('10.'):
            risk_score += 35; threats.append({'type': 'LATERAL_MOVEMENT', 'mitre': 'T1021'})

        # Data exfiltration
        if flow.get('bytes', 0) > 100_000_000 and not dst.startswith('10.'):
            risk_score += 45; threats.append({'type': 'DATA_EXFILTRATION', 'mitre': 'T1048'})

        # Brute force
        if flow.get('action') == 'REJECT' and port in [22, 3389, 5432]:
            rejected = sum(1 for c in recent if c['dst'] == dst and c['port'] == port)
            if rejected > 10:
                risk_score += 30; threats.append({'type': 'BRUTE_FORCE', 'mitre': 'T1110'})

        return {'risk_score': min(risk_score, 100), 'threats': threats, 'is_malicious': risk_score > 50}
