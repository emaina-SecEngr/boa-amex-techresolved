from flask import Flask, request, redirect, session, render_template_string
import base64
import xml.etree.ElementTree as ET
from datetime import datetime
import urllib.parse
import uuid
import zlib
import os

app = Flask(__name__)
app.secret_key = os.urandom(32)

TENANT_ID = "288a15d1-700c-482b-a591-7c1d4e6c4f3c"
APP_ID = "10f6cb4d-3b88-4ea6-b21d-a37c1da81ca0"
ENTITY_ID = "api://" + APP_ID
SSO_URL = "https://login.microsoftonline.com/" + TENANT_ID + "/saml2"
CALLBACK_URL = "http://localhost:5000/auth/saml/callback"

PAGE = """
<!DOCTYPE html>
<html>
<head><title>LBB Banking Portal - SAML SSO Test</title>
<style>
body{font-family:Calibri,sans-serif;max-width:800px;margin:50px auto;background:#f5f5f5}
.card{background:white;padding:30px;border-radius:8px;box-shadow:0 2px 10px rgba(0,0,0,0.1);margin:20px 0}
.header{background:#1a365d;color:white;padding:20px;border-radius:8px 8px 0 0}
.btn{background:#2563eb;color:white;padding:12px 24px;border:none;border-radius:6px;cursor:pointer;font-size:16px;text-decoration:none;display:inline-block}
.btn:hover{background:#1d4ed8}
.success{background:#d4edda;padding:15px;border-radius:6px;border:1px solid #c3e6cb}
.info{background:#d1ecf1;padding:15px;border-radius:6px;border:1px solid #bee5eb;margin:10px 0}
table{width:100%;border-collapse:collapse}
td{padding:8px;border-bottom:1px solid #eee}
td:first-child{font-weight:bold;width:200px;color:#555}
.step{background:#f8f9fa;padding:10px;margin:5px 0;border-left:3px solid #2563eb}
</style></head>
<body>
<div class="header"><h1>LBB Banking Portal</h1><p>BOA-AMEX-TechResolved - SAML SSO Test</p></div>
<div class="card">
{% if user %}
<div class="success"><h2>SSO Login Successful</h2><p>Authenticated via Microsoft Entra ID SAML 2.0</p></div>
<h3>SAML Assertion Claims:</h3>
<table>{% for key, value in user.items() %}<tr><td>{{ key }}</td><td>{{ value }}</td></tr>{% endfor %}</table>
<br><a href="/logout" class="btn" style="background:#dc3545;">Logout</a>
{% else %}
<h2>Enterprise Single Sign-On</h2>
<p>Click below to authenticate with Microsoft Entra ID:</p><br>
<a href="/login" class="btn">Login with Entra ID SSO</a>
<h3 style="margin-top:30px;">How This Works:</h3>
<div class="step">Step 1: Click Login - redirected to Entra ID</div>
<div class="step">Step 2: Enter Entra ID credentials + MFA</div>
<div class="step">Step 3: Entra ID builds SAML assertion</div>
<div class="step">Step 4: Signs assertion with private key</div>
<div class="step">Step 5: Browser POSTs signed assertion back here</div>
<div class="step">Step 6: This app validates signature + claims</div>
<div class="step">Step 7: You see your identity details</div>
<div class="info">
<strong>Tenant:</strong> {{ tenant_id }}<br>
<strong>App:</strong> LBB-BankingPortal ({{ app_id }})<br>
<strong>SSO URL:</strong> {{ sso_url }}<br>
<strong>Callback:</strong> {{ callback_url }}
</div>
{% endif %}
</div></body></html>
"""

@app.route("/")
def home():
    return render_template_string(PAGE, user=session.get("user"),
        tenant_id=TENANT_ID, app_id=APP_ID, sso_url=SSO_URL, callback_url=CALLBACK_URL)

@app.route("/login")
def login():
    request_id = "_" + uuid.uuid4().hex
    issue_instant = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
    authn_request = '<samlp:AuthnRequest xmlns:samlp="urn:oasis:names:tc:SAML:2.0:protocol" xmlns:saml="urn:oasis:names:tc:SAML:2.0:assertion" ID="{}" Version="2.0" IssueInstant="{}" Destination="{}" AssertionConsumerServiceURL="{}" ProtocolBinding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST"><saml:Issuer>{}</saml:Issuer><samlp:NameIDPolicy Format="urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress" AllowCreate="true"/></samlp:AuthnRequest>'.format(request_id, issue_instant, SSO_URL, CALLBACK_URL, ENTITY_ID)
    compressed = zlib.compress(authn_request.encode())[2:-4]
    encoded = base64.b64encode(compressed).decode()
    url_encoded = urllib.parse.quote(encoded)
    print("\nSAML AuthnRequest sent to Entra ID")
    print("  Request ID:", request_id)
    print("  Destination:", SSO_URL)
    return redirect(SSO_URL + "?SAMLRequest=" + url_encoded + "&RelayState=/")

@app.route("/auth/saml/callback", methods=["POST"])
def callback():
    saml_response = request.form.get("SAMLResponse", "")
    if not saml_response:
        return "No SAML response received", 400
    try:
        decoded = base64.b64decode(saml_response)
        xml_string = decoded.decode("utf-8")
        root = ET.fromstring(xml_string)
        user = {}
        for elem in root.iter():
            if "NameID" in elem.tag:
                user["NameID (email)"] = elem.text
            if "Attribute" in elem.tag and "Name" in elem.attrib:
                attr_name = elem.attrib["Name"]
                for val in elem:
                    if val.text:
                        short = attr_name.split("/")[-1] if "/" in attr_name else attr_name
                        user[short] = val.text
        user["SSO Method"] = "SAML 2.0"
        user["Identity Provider"] = "Microsoft Entra ID"
        user["Tenant ID"] = TENANT_ID
        user["Application"] = "LBB-BankingPortal"
        user["Login Time"] = datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S UTC")
        session["user"] = user
        print("\nSAML SSO SUCCESS:")
        for k, v in user.items():
            print("  {}: {}".format(k, v))
    except Exception as e:
        return "SAML error: {}".format(e), 500
    return redirect("/")

@app.route("/logout")
def logout():
    session.clear()
    return redirect("/")

if __name__ == "__main__":
    print("=" * 50)
    print("LBB Banking Portal - SAML SSO Test")
    print("=" * 50)
    print("App:    LBB-BankingPortal ({})".format(APP_ID))
    print("Tenant: {}".format(TENANT_ID))
    print("SSO:    {}".format(SSO_URL))
    print("Open:   http://localhost:5000")
    print("=" * 50)
    app.run(debug=True, port=5000)
