# Generates an encryption key
param([Parameter(Mandatory=$true)][string]$userName)

$EncryptionKeyBytes = New-Object Byte[] 16
[Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($EncryptionKeyBytes)
$OutDir = ($pwd).path
Write-Host "Key for user '$userName': $EncryptionKeyBytes"
$EncryptionKeyBytes | Out-File "$OutDir/keys/$userName.key"