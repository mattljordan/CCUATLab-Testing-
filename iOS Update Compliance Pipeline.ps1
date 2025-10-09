


# Function to test if a JSON string is valid
Function Test-JSON() {

    <#
    .SYNOPSIS
    This function is used to test if the JSON passed to a REST Post request is valid
    .DESCRIPTION
    The function tests if the JSON passed to the REST Post is valid
    .EXAMPLE
    Test-JSON -JSON $JSON
    Test if the JSON is valid before calling the Graph REST interface
    .NOTES
    NAME: Test-JSON
    #>

    param (
        $JSON
    )

    try {
        $TestJSON = ConvertFrom-Json $JSON -ErrorAction Stop
        $validJson = $true
    }
    catch {
        $validJson = $false
        $_.Exception
    }

    if (!$validJson) {
        Write-Host "Provided JSON isn't in valid JSON format" -f Red
        break
    }
}


# Function to retrieve device compliance policies from Microsoft Graph API
Function Get-DeviceCompliancePolicy() {

    <#
    .SYNOPSIS
    This function is used to get device compliance policies from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any device compliance policies
    .EXAMPLE
    Get-DeviceCompliancePolicy
    Returns any device compliance policies configured in Intune
    .EXAMPLE
    Get-DeviceCompliancePolicy -Android
    Returns any device compliance policies for Android configured in Intune
    .EXAMPLE
    Get-DeviceCompliancePolicy -iOS
    Returns any device compliance policies for iOS configured in Intune
    .NOTES
    NAME: Get-DeviceCompliancePolicy
    #>

    [cmdletbinding()]
    $graphApiVersion = 'Beta'
    $Resource = 'deviceManagement/deviceCompliancePolicies'

    try {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
        (Invoke-MgGraphRequest -Uri $uri -Method Get).Value
    }
    catch {
        Write-Error $Error[0].ErrorDetails.Message
        break
    }
}


# Function to update a device compliance policy using Microsoft Graph API
Function Update-DeviceCompliancePolicy() {

    <#
    .SYNOPSIS
    This function is used to update device compliance policies from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and updates device compliance policies
    .EXAMPLE
    Update-DeviceCompliancePolicy -id -JSON
    Updates a device compliance policies configured in Intune
    .NOTES
    NAME: Update-DeviceCompliancePolicy
    #>

    
   

    $graphApiVersion = 'Beta'
    $Resource = "deviceManagement/deviceCompliancePolicies/dcf4a2bc-4df7-473e-9c23-acb9e7f8c991"

    try {
        
            Test-Json -Json $JSON
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            Invoke-MgGraphRequest -Uri $uri -Method Patch -Body $JSON -ContentType 'application/json'
        
    }
    catch {
        Write-Error $Error[0].ErrorDetails.Message
        break
    }
}

# Function to get the latest Apple iOS/macOS updates from the Apple Developer RSS feed
Function Get-AppleUpdates() {

    <#
    .SYNOPSIS
    This function is used to get the latest Apple Updates from the Apple Developer RSS Feeds
    .DESCRIPTION
    The function pulls the RSS feed from the Apple Developer RSS Feeds
    .EXAMPLE
    Get-AppleUpdates -OS iOS -Version 15
    #>

    
    try {
        $uri = 'https://developer.apple.com/news/releases/rss/releases.rss'
        [xml]$Updates = (Invoke-WebRequest -Uri $uri -UseBasicParsing -ContentType 'application/xml').Content -replace '[^\x09\x0A\x0D\x20-\xD7FF\xE000-\xFFFD\x10000-x10FFFF]', ''

        $BuildVersion = @()
        foreach ($Update in $Updates.rss.channel.Item) {
            if (($Update.title -like "*iOS*") -and ($Update.title -like "*26*") -and ($Update.title -notlike "*Beta*")) {
                $BuildVersion += $Update.title
            }
        }
        return $BuildVersion[0]
    }
    catch {
        Write-Error $Error[0].ErrorDetails.Message
        break
    }
}






# Get current date and set update description
$Date = Get-Date -Format 'dd-MM-yyyy hh:mm:ss'
$Description = "Updated Operating System Device Compliance Policy on $Date"


# Retrieve the specific device compliance policy by ID
$OSCompliancePolicies = Get-DeviceCompliancePolicy | Where-Object { ($_.id) -eq "dcf4a2bc-4df7-473e-9c23-acb9e7f8c991" }




    # Extract the major version from the current minimum OS version
    $Version = $OSCompliancePolicies.osMinimumVersion.SubString(0, 2)



    # Get the latest Apple iOS update for the detected version
    $AppleUpdate = Get-AppleUpdates -OS iOS -Version $Version
    if ($null -eq $AppleUpdate -or $AppleUpdate -eq "") {
        Write-Host "Apple update result is null or empty for iOS. Skipping policy update." -ForegroundColor Yellow
    } else {
        # Extract the build version number from the update string
        $Build = ($AppleUpdate | Select-String '\b\d+\.\d+\.\d+\b' -AllMatches).Matches.Value
        # Compare current policy version to latest build
        if ($OSCompliancePolicies.osMinimumVersion -ne $Build) {
            # Prepare update object for PATCH request
            $Update = New-Object -TypeName psobject
            $Update | Add-Member -MemberType NoteProperty -Name '@odata.type' -Value $OSCompliancePolicies.'@odata.type'
            $Update | Add-Member -MemberType NoteProperty -Name 'description' -Value $Description
            $Update | Add-Member -MemberType NoteProperty -Name 'osMinimumVersion' -Value $Build

            # Convert update object to JSON and send PATCH request
            $JSON = $Update | ConvertTo-Json -Depth 3
            Update-DeviceCompliancePolicy -Id $OSCompliancePolicies.id -JSON $JSON
            Write-Host "Updated iOS Compliance Policy $($OSCompliancePolicies.displayName) with latest Build: $Build" -ForegroundColor Green
            Write-Host
        } else {
            Write-Host "iOS Compliance Policy $($OSCompliancePolicy.displayName) already on latest Build: $Build" -ForegroundColor Cyan
            Write-Host
        }
    }
