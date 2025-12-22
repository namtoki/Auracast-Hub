/// Amplify configuration for Auracast Hub
///
/// After deploying Terraform infrastructure, update these values with:
/// ```bash
/// cd infrastructure/terraform
/// terraform output flutter_amplify_config
/// terraform output cognito_domain
/// ```
///
/// For social login, also update:
/// - socialProviders: Add enabled providers (e.g., ["GOOGLE", "FACEBOOK", "APPLE"])
/// - OAuth section: Update with your Cognito domain

const amplifyConfig = '''{
  "UserAgent": "aws-amplify-cli/2.0",
  "Version": "1.0",
  "auth": {
    "plugins": {
      "awsCognitoAuthPlugin": {
        "UserAgent": "aws-amplify-cli/0.1.0",
        "Version": "0.1.0",
        "IdentityManager": {
          "Default": {}
        },
        "CredentialsProvider": {
          "CognitoIdentity": {
            "Default": {
              "PoolId": "YOUR_IDENTITY_POOL_ID",
              "Region": "ap-northeast-1"
            }
          }
        },
        "CognitoUserPool": {
          "Default": {
            "PoolId": "YOUR_USER_POOL_ID",
            "AppClientId": "YOUR_APP_CLIENT_ID",
            "Region": "ap-northeast-1"
          }
        },
        "Auth": {
          "Default": {
            "authenticationFlowType": "USER_SRP_AUTH",
            "socialProviders": ["GOOGLE", "FACEBOOK", "APPLE"],
            "usernameAttributes": ["EMAIL"],
            "signupAttributes": ["EMAIL"],
            "passwordProtectionSettings": {
              "passwordPolicyMinLength": 8,
              "passwordPolicyCharacters": [
                "REQUIRES_LOWERCASE",
                "REQUIRES_UPPERCASE",
                "REQUIRES_NUMBERS"
              ]
            },
            "mfaConfiguration": "OPTIONAL",
            "mfaTypes": ["TOTP"],
            "verificationMechanisms": ["EMAIL"],
            "OAuth": {
              "WebDomain": "YOUR_COGNITO_DOMAIN.auth.ap-northeast-1.amazoncognito.com",
              "AppClientId": "YOUR_APP_CLIENT_ID",
              "SignInRedirectURI": "auracasthub://callback",
              "SignOutRedirectURI": "auracasthub://signout",
              "Scopes": ["email", "openid", "profile"]
            }
          }
        }
      }
    }
  }
}''';
