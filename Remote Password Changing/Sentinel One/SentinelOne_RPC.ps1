<#
.SYNOPSIS
Changes a user's password in SentinelOne.
Logs the process to a log file.
#>

# --- CONFIGURATION ---
$ApiUrl          = $args[0]    # SentinelOne server URL
$AdminUsername   = $args[1]    # Admin username with permission to change passwords
$AdminPassword   = $args[2]    # Admin password
$UserId          = $args[3]    # ID of the user whose password you want to change
$NewPassword     = $args[4]    # New password to set
$LogDir          = 'C:\Temp\Logs'  # Directory where logs will be stored
$LogFile         = Join-Path $LogDir 'ChangePasswordLog.txt'  # Full path to the log file
$DebugEnabled    = $true       # Set to $false to disable debug logging

# --- PREP WORK ---
# Ensure the log directory exists, create it if it does not
if (!(Test-Path -Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

# --- FUNCTIONS ---
# Logs a debug message with a timestamp if debugging is enabled
function Write-Log {
    param(
        [string]$Message
    )
    if ($DebugEnabled) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Add-Content -Path $LogFile -Value "$timestamp - $Message"
    }
}

# Authenticates to SentinelOne and retrieves an API token
function Get-ApiToken {
    param(
        [string]$ApiUrl,
        [string]$Username,
        [string]$Password
    )

    $uri = "$ApiUrl/web/api/v2.1/login"
    $body = @{ username = $Username; password = $Password }

    try {
        Write-Log "Requesting API token for admin user: $Username"
        $response = Invoke-RestMethod -Method Post -Uri $uri -Body ($body | ConvertTo-Json -Depth 3) -ContentType 'application/json'
        return $response.data.token
    }
    catch {
        Write-Log "ERROR: Failed to obtain API token for user: $Username - $($_.Exception.Message)"
        throw
    }
}

# Sets a user's password in SentinelOne
function Set-UserPassword {
    param(
        [string]$ApiUrl,
        [string]$ApiToken,
        [string]$UserId,
        [string]$NewPassword
    )

    $uri = "$ApiUrl/web/api/v2.1/users/change-password"
    $body = @{ data = @{ id = $UserId; newPassword = $NewPassword; confirmNewPassword = $NewPassword } }
    $headers = @{ Authorization = "ApiToken $ApiToken"; 'Content-Type' = 'application/json' }

    try {
        Write-Log "Attempting to change password for user ID: $UserId"
        $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -Body ($body | ConvertTo-Json -Depth 5) -ErrorAction Stop
        return $response
    }
    catch {
        Write-Log "ERROR: Failed to change password for user ID: $UserId - $($_.Exception.Message)"
        throw
    }
}

# --- MAIN ---
try {
    Write-Log "==== Script started ===="

    # Authenticate and retrieve API token
    $ApiToken = Get-ApiToken -ApiUrl $ApiUrl -Username $AdminUsername -Password $AdminPassword

    # Attempt to change the user's password
    $changeResult = Set-UserPassword -ApiUrl $ApiUrl -ApiToken $ApiToken -UserId $UserId -NewPassword $NewPassword

    # Check if the password change was successful
    if ($changeResult.data.success -eq $true) {
        Write-Log "Password change successful for user ID: $UserId"
    }
    else {
        Write-Log "WARNING: Password change may have failed for user ID: $UserId"
    }

    Write-Log "==== Script completed successfully ===="
}
catch {
    Write-Log "FATAL: Password change script failed - $($_.Exception.Message)"
}
