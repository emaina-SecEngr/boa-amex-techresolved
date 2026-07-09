# Microsoft Entra ID — AWS Identity Center Integration

## Status: ACTIVE

## What was configured (manual console steps)

### Entra ID Enterprise Application
- App Name: AWS IAM Identity Center (successor to AWS Single Sign-On)
- Tenant ID: 288a15d1-700c-482b-a591-7c1d4e6c4f3c
- Tenant Domain: mwangimaina83gmail.onmicrosoft.com

### SAML Federation (Step 1)
- Identity Center Instance: ssoins-72238d4e4906358a (Azaria)
- ACS URL: https://us-east-1.sso.signin.aws/platform/saml/acs/75732d656173742d312d059231ef-7dc0-44bb-8ebe-3427c5a9fe86
- Entity ID: https://us-east-1.signin.aws.amazon.com/platform/saml/d-9066208dac
- IdP Sign-in URL: https://login.microsoftonline.com/288a15d1-700c-482b-a591-7c1d4e6c4f3c/saml2
- IdP Issuer URL: https://sts.windows.net/288a15d1-700c-482b-a591-7c1d4e6c4f3c/
- Certificate: CN=Microsoft Azure Federated SSO Certificate (expires 7/8/2029)

### SCIM Provisioning (Step 2)
- SCIM Endpoint: https://scim.us-east-1.amazonaws.com/c468b408-d011-70d7-46f9-e8bb95a047e3/scim/v2
- Token: stored securely locally (never committed to Git)
- Status: Active — provisioning running

### SSO Portal URL
https://ssoins-72238d4e4906358a.portal.us-east-1.app.aws

## What Terraform manages (code in modules/iam-identity-center/)

| Resource | File | Status |
|---|---|---|
| DenyRootUsage SCP | scps.tf | Deployed |
| DenyPublicS3 SCP | scps.tf | Deployed |
| DenyRegionExit SCP | scps.tf | Deployed |
| RequireEncryption SCP | scps.tf | Deployed |
| DenyDisablingSecurity SCP | scps.tf | Deployed |
| DenyAllWrites SCP (Compliance OU) | scps.tf | Deployed |
| SecurityAuditor Permission Set | permission_sets.tf | Deployed |
| Developer Permission Set | permission_sets.tf | Deployed |
| NetworkAdmin Permission Set | permission_sets.tf | Deployed |
| BreakGlass Permission Set | permission_sets.tf | Deployed |
| OCCExaminer Permission Set | permission_sets.tf | Deployed |
| Break Glass Alarm | main.tf | Deployed |

## Next Steps
1. Create Entra ID groups matching Permission Sets:
   - AWS-SecurityAuditors
   - AWS-Developers
   - AWS-NetworkAdmins
   - AWS-BreakGlass (restrict to 2-3 people maximum)
   - AWS-OCCExaminers (assigned only during examination periods)
2. Wait for SCIM to sync groups to AWS Identity Center
3. Add group IDs to account assignments in main.tf
4. Test SSO login via portal URL above
5. Test Break Glass alarm fires within 60 seconds

## Reproduction Steps (if rebuilding)
If this integration needs to be rebuilt from scratch:
1. Enable Identity Center in Management account
2. Create Enterprise App "AWS IAM Identity Center" in Entra ID
3. Configure SAML using ACS URL and Entity ID from Identity Center
4. Download Federation Metadata XML from Entra ID
5. Upload metadata XML to Identity Center as external IdP
6. Enable automatic provisioning in Identity Center
7. Configure SCIM in Entra ID with endpoint + token
8. Start provisioning in Entra ID
