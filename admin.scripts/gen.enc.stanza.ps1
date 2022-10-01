# Generates the encrypted Stanxza files and zips them up

param([Parameter(Mandatory=$true)][string]$userKeyFileName)

$rootDir = ($pwd).path
$sourcePath = "$rootDir/input.stanzas/"
$outPath = "$rootDir/output.stanzas/"

Function zipToOutputDir($sourceDir) {
    $outputZipPath = "$outPath/$userKeyFileName.enc.stanzas.zip"
    Compress-Archive -Path "$sourceDir/*" -CompressionLevel Optimal -DestinationPath $outputZipPath
}

Function encryptStanzas() {
    $tempDir = "$outPath/temp"
    mkdir $tempDir
    $userKey = Get-Content "$rootDir/keys/$userKeyFileName.key"
    $unencryptedStanzas = Get-ChildItem $sourcePath -Filter *.fwknop
    foreach ($stanza in $unencryptedStanzas) {
        $fname = $stanza.Name
        $SecureStanzaData = Get-Content "$sourcePath/$stanza" -Raw | ConvertTo-SecureString -AsPlainText -Force
        ConvertFrom-SecureString $SecureStanzaData -Key $userKey | Out-File -FilePath "$tempDir/$fname"
    }
    zipToOutputDir $tempDir
    Remove-Item $tempDir -Recurse
}

encryptStanzas
Remove-Item "$sourcePath/*"