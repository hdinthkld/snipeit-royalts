$global:ErrorActionPreference = "Stop"
$global:WarningPreference = "SilentlyContinue"
$global:InformationPreference = "SilentlyContinue"
$global:VerbosePreference = "SilentlyContinue"
$global:DebugPreference = "SilentlyContinue"
$global:ProgressPreference = "SilentlyContinue"
$global:OutputEncoding = New-Object Text.Utf8Encoding -ArgumentList (,$false) # BOM-less
[Console]::OutputEncoding = $global:OutputEncoding

function Get-SnipeIT-JSON {
    $uri = "https://raw.githubusercontent.com/hdinthkld/snipeit-royalts/refs/heads/main/snipe-static-data.json"
    $data = Invoke-WebRequest -Method Get -uri $uri
    $content = $data.Content
    $json = ConvertFrom-Json $content
    $devices = $json.rows

    return $devices
}

$devices = Get-SnipeIT-JSON

$rts_devices = @{}

foreach ($device in $devices) {
    if ($rts_devices.Keys -notcontains $device.company.name) {
        $rts_devices[$device.company.name] = @{}
    }

    if ($rts_devices[$device.company.name].Keys -notcontains $device.location.name) {
        $rts_devices[$device.company.name][$device.location.name] = @()
    }

    $rts_device = [PSCustomObject]@{
        Name = ''
        ComputerName = ''
        ManagementIp = ''
        SecureGatewayID = ''
        SecureGatewayUsageMode = 1
        SecureGatewayFromParent = $false
        CredentialName = ''
        Type = ''
        TerminalConnectionType = ''
        Port = ""
        Notes = ""
    }

    $ConnectionType = $device.custom_fields.'Management Protocol'.value

    if (($ConnectionType -eq "SSH") -or ($ConnectionType -eq "SSH and HTTPS")) {
        $rts_device.Name = $device.name
        $rts_device.ComputerName = $device.custom_fields.'Management IP'.value
        if (!($device.custom_fields.'Secure Gateway'.value -eq "None")) {
            $rts_device.SecureGatewayID = $device.custom_fields.'Secure Gateway'.value
            $rts_device.SecureGatewayFromParent = $False
            $rts_device.SecureGatewayUsageMode = 1; # Always
        }
        $rts_device.CredentialName = $device.custom_fields.'Credential Name'.value
        $rts_device.Type = "TerminalConnection"
        $rts_device.TerminalConnectionType = "SSH"
        $rts_device.Port = "22"
        $rts_device.Notes = "Exported from SNIPE"
    }

    if (!$rts_device.ComputerName -eq "") {
        $rts_devices[$device.company.name][$device.location.name] += $rts_device
    }
    
}

$company_keys= $rts_devices.Keys
$companies = @()

foreach ($company in $company_keys) {
    $sites = @()

    foreach ($site in $rts_devices.$company.Keys) {
        $devices = @()
        foreach ($device in $rts_devices.$company.$site) {
            $devices += $device
        }

        $sites += @{
            Type="Folder"
            Name=$site
            Objects=$devices
        }
    }

    $companies += @{
        Type="Folder"
        Name=$company
        Objects=$sites
    }
}

$companies += @{
    Type="Folder"
    Name="Shared"
    Objects = @(
        @{
            Name="AUTOSVR"
            ID="AUTOSVR"
            Type="SecureGateway"
            SecureGatewayCredentialMode=3
            SecureGatewayCredentialName="SG-CREDENTIAL"
            SecureGatewayHost="127.0.0.1"
            SecureGatewayPort="22"
            IconName="/VMware Clarity/Technology/Router Solid"

        }
    )
}

$objects = @{
    Objects = $companies
}

$rts_json = ConvertTo-Json -Depth 100 $objects

write-host $rts_json