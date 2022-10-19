Function outputCleanser ($stringToClean) {
    # I need to understand why this is needed on some machines, its nonsense...
    # ---- Nonsense start
    $returnStr = $stringToClean.replace("`0", "")
    # ---- Nonsense end
    return $returnStr
}

Function wslCommand($cmdArgs, $exitOnFailure=$True) {
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
    if ($p.ExitCode -ne 0) {
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

Export-ModuleMember -Function wslCommand