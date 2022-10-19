# Installs an Ubuntu instance and configures it ready for fwknop

$currentDir = ($pwd).path
$clientDir = (get-item $currentDir).parent.parent.FullName
$env:PSModulePath = $env:PSModulePath,"$clientDir/modules" -join [System.IO.Path]::PathSeparator
Import-Module wslCommands

$fwknopUser = "fwknopuser"
$SPAdistro = "Ubuntu-20.04"

$allDistros = wslCommand @("--list")
if ($allDistros.stdout.contains($SPAdistro)) {
    Write-Host "WSL Ubuntu instance already installed, validating if it defaults to the fwknop user"
    $fwknopUserPresent = wslCommand @("-d", $SPAdistro , "-u", $fwknopUser, "exit") $False  # we don't want to stop installation if the user is there
    if ($fwknopUserPresent.ExitCode -ne 0) {
        Write-Host "An unknown (to me) installation of Ubuntu is already present. Exiting to avoid data loss."
        Exit
    }
    Write-Host "fwknop user is present, lets make sure everything is up to date."
} else {
    Write-Host "Installing $SPAdistro"
    # if a non-zero is returned, we will write stdout and err to host and exit
    wslCommand @("--install", "-d", $SPAdistro)
    Write-Host "Waiting for WSL: $SPAdistro install to complete. DO NOT TYPE ANYTHING INTO ANYTHING! We will auto configure in 60 seconds."
    for ($i=0; $i -lt 12; $i++) {
        Write-Host "... Waiting ..."
        Start-Sleep 5
    }
    # Kill off the spawned Window, as we are auto configuring it.
    get-process | where-object {$_.MainWindowTitle.ToLower().Contains("ubuntu")} | stop-process
    # Creating our SPA user
    Write-Host "Creating User: $fwknopUser"
    wslCommand @("-d", $SPAdistro, "-u", "root", "useradd", "-m", "-s", "/bin/bash", $fwknopUser)
    wslCommand @("-d", $SPAdistro, "-u", "root", "usermod", "-aG", "sudo", $fwknopUser)
    wslCommand @("-d", $SPAdistro, "-u", "root", "passwd", "-d", $fwknopUser)  # no password, we can debate this.
}

Write-Host "Updating packages (may take some time)."
wslCommand @("-d", $SPAdistro, "-u", "root", "apt", "update")
Write-Host "Upgrading Packages (may take some time)."
wslCommand @("-d", $SPAdistro, "-u", "root", "apt", "upgrade", "-y")
Write-Host "Installing fwknop client (SPA)"
wslCommand @("-d", $SPAdistro, "-u", "root", "apt", "install", "fwknop-client", "-y")

# Check if we have the zip file and key, we will exit here if not. If all you want to do is update the distro, this is nice (enough).
$dataDir = "$currentDir/data"
$dataFiles = Get-ChildItem -Path $dataDir -force | Where-Object Extension -in ('.zip','.key')
if (($dataFiles | Measure-Object).Count -ne 2) {
    Write-Host "Looks like you haven't got the required zip and key file in: $dataDir. We will now Exit."
    Exit
}

Write-Host "Zip file present in data DIR"
$stanzaDirName = "stanzas"
$stanzaDirPresent = wslCommand @("-d", $SPAdistro, "test", "-d", "/home/$fwknopUser/$stanzaDirName") $False
if ($stanzaDirPresent.ExitCode -eq 1) {
    Write-Host "Creating Stanza DIR"
    wslCommand @("-d", $SPAdistro, "mkdir", "/home/$fwknopUser/$stanzaDirName")
}

$key = Get-Content ($dataFiles | Get-ChildItem | Where-Object Extension -eq ".key")
$stanzaTempDir = "$dataDir/temp"
mkdir $stanzaTempDir
$zip = $dataFiles | Get-ChildItem | Where-Object Extension -eq ".zip"
Write-Host "Extracting zip"
Expand-Archive -Path $zip -DestinationPath $stanzaTempDir
foreach ($encStanza in Get-ChildItem $stanzaTempDir) {
    $fname = $encStanza.Name
    $stanzaData = Get-Content "$stanzaTempDir/$fname" | ConvertTo-SecureString -key $key
    $data = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($stanzaData))
    # Write each file to the WSL instance
    Write-Host "Copying Stanza $fname to WSL instance"
    wslCommand @("-d", $SPAdistro, "echo", $data, ">", "/home/$fwknopUser/$stanzaDirName/$fname")
}

Write-Host "Tidying up..."
Remove-Item "$dataDir/*" -Recurse
Write-Host ".....Installation complete....."
