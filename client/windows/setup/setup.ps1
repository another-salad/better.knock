# Installs an Ubuntu instance and configures it ready for fwknop

$fwknopUser = "fwknopuser"
$SPAdistro = "Ubuntu-20.04"

Function outputCleanser ($stringToClean) {
    # I need to understand why this is needed on some machines, its nonsense...
    # ---- Nonsense start
    $returnStr = $stringToClean.replace("`0", "")
    # ---- Nonsense end
    return $returnStr
}
Function wslCommand($cmdArgs, $exitOnFailure=$True)
{
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = "wsl.exe"
    $pinfo.RedirectStandardError = $True
    $pinfo.RedirectStandardOutput = $True
    $pinfo.UseShellExecute = $False
    $pinfo.Arguments = $cmdArgs
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $pinfo
    $p.Start() | Out-Null
    $stdout = outputCleanser $p.StandardOutput.ReadToEnd()
    $stderr = outputCleanser $p.StandardError.ReadToEnd()
    $p | Add-Member "stdout" $stdout
    $p | Add-Member "stderr" $stderr
    if ($p.ExitCode -ne 0)
    {
        Write-Host "Error thrown running wsl command: $cmdArgs"
        Write-Host "stdout: $stdout"
        Write-Host "stderr: $stderr"
        Write-Host "exit code: " + $p.ExitCode
        if ($exitOnFailure) {
            Exit
        }
    }
    $p.WaitForExit()
    return $p
}

$allDistros = wslCommand @("--list")
if ($allDistros.stdout.contains($SPAdistro)) {
    Write-Host "WSL Ubuntu instance already installed, validating if it defaults to the fwknop user"
    $fwknopUserPresent = wslCommand @("-d", $SPAdistro , "-u", $fwknopUser) $False  # we don't want to exit
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

# Add logic for checking zip DIR and creating Stanzas
Exit