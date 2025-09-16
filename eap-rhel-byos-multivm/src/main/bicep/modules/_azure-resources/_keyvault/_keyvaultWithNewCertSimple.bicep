@description('Managed identity to be used for the deployment script. Currently, only user-assigned MSI is supported.')
param identity object = {}

@description('Used to name the new Azure Key Vault resoure.')
param keyVaultName string = 'jboss-kv-${uniqueString(utcValue)}'

param location string

@description('Access permission of the key vault, will applied to all access policies.')
param permission object = {
  certificates: [
    'get'
    'list'
    'update'
    'create'
  ]
}

@description('Used to name the new certificate resource.')
param secretName string = 'mySelfSignedCertificate'

@description('Price tier for Key Vault.')
param sku string = 'Standard'

@description('Subject name to create a new certificate, example: \'CN=contoso.com\'.')
param subjectName string = 'contoso.xyz'
param utcValue string = utcNow()
param guidValue string = ''
@description('${label.tagsLabel}')
param tagsByResource object

var const_identityId = substring(string(identity.userAssignedIdentities), indexOf(string(identity.userAssignedIdentities), '"') + 1, lastIndexOf(string(identity.userAssignedIdentities), '"') - (indexOf(string(identity.userAssignedIdentities), '"') + 1))

resource keyvault 'Microsoft.KeyVault/vaults@${azure.apiVersionForKeyVault}' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: sku
    }
    tenantId: subscription().tenantId
    accessPolicies: [
      {
        // Must specify API version of identity.
        objectId: reference(const_identityId, '2018-11-30').principalId
        tenantId: subscription().tenantId
        permissions: permission
      }
    ]
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: true
    enableRbacAuthorization: false
    enableSoftDelete: true
  }
  tags: union(tagsByResource['${identifier.vaults}'], {
        'managed-by-azure-jboss': utcValue
  })
}

resource createAddCertificate 'Microsoft.Resources/deploymentScripts@${azure.apiVersionForDeploymentScript}' = {
  name: 'ds-create-add-appgw-certificate-${guidValue}'
  location: location
  identity: identity
  kind: 'AzurePowerShell'
  properties: {
    forceUpdateTag: utcValue
    azPowerShellVersion: '11.5'
    timeout: 'PT30M'
    arguments: ' -vaultName ${keyVaultName} -certificateName ${secretName} -subjectName ${subjectName}'
    scriptContent: '\n                    param(\n                        [string] [Parameter(Mandatory=$true)] $vaultName,\n                        [string] [Parameter(Mandatory=$true)] $certificateName,\n                        [string] [Parameter(Mandatory=$true)] $subjectName\n                    )\n\n                    $ErrorActionPreference = \'Stop\'\n                    $DeploymentScriptOutputs = @{}\n\n                    try {\n                        $existingCert = Get-AzKeyVaultCertificate -VaultName $vaultName -Name $certificateName -ErrorAction SilentlyContinue\n\n                        if ($existingCert -and $existingCert.Certificate.Subject -eq $subjectName) {\n                            Write-Host \'Certificate $certificateName in vault $vaultName is already present.\'\n                            $DeploymentScriptOutputs[\'certThumbprint\'] = $existingCert.Thumbprint\n                        }\n                        else {\n                            Write-Host \'Creating new certificate $certificateName in vault $vaultName\'\n                            $policy = New-AzKeyVaultCertificatePolicy -SubjectName $subjectName -IssuerName Self -ValidityInMonths 12\n                            Add-AzKeyVaultCertificate -VaultName $vaultName -Name $certificateName -CertificatePolicy $policy\n                            \n                            # Wait a bit for the certificate to be created\n                            Start-Sleep -Seconds 30\n                            \n                            $newCert = Get-AzKeyVaultCertificate -VaultName $vaultName -Name $certificateName\n                            $DeploymentScriptOutputs[\'certThumbprint\'] = $newCert.Thumbprint\n                        }\n                    }\n                    catch {\n                        Write-Host \'Error creating certificate: $($_.Exception.Message)\'\n                        # Create a simple certificate policy and try again\n                        $policy = New-AzKeyVaultCertificatePolicy -SubjectName $subjectName -IssuerName Self -ValidityInMonths 12\n                        Add-AzKeyVaultCertificate -VaultName $vaultName -Name $certificateName -CertificatePolicy $policy\n                        \n                        Start-Sleep -Seconds 30\n                        $newCert = Get-AzKeyVaultCertificate -VaultName $vaultName -Name $certificateName\n                        $DeploymentScriptOutputs[\'certThumbprint\'] = $newCert.Thumbprint\n                    }\n                '
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
  }
  dependsOn: [
    keyvault
  ]
  tags: tagsByResource['${identifier.deploymentScripts}']
}

output keyVaultName string = keyVaultName
output secretName string = secretName
output identityId string = const_identityId
