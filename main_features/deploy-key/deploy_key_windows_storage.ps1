<#
.SYNOPSIS
    Prepares owner-restricted Windows directories and validates existing key files.

.DESCRIPTION
    Git Bash's default Windows mounts do not enforce chmod. Create missing
    directories with inheritable ACLs before key generation and reject existing
    paths with untrusted owners, access rules, or reparse points. Existing
    permissions are never rewritten. The Bash caller handles localized errors.
#>

[CmdletBinding(DefaultParameterSetName = 'Directory')]
param(
    [Parameter(Mandatory, ParameterSetName = 'Directory')]
    [string]$SshDirectory,

    [Parameter(Mandatory, ParameterSetName = 'KeyPair')]
    [string]$PrivateKeyPath
)

$ErrorActionPreference = 'Stop'
$userSid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
$trustedSids = @($userSid.Value, 'S-1-5-18', 'S-1-5-32-544')
$childInheritance = [System.Security.AccessControl.InheritanceFlags]'ContainerInherit, ObjectInherit'

<#
.SYNOPSIS
    Returns an existing Windows path, including hidden items, or null if absent.
#>
function Get-DeployKeyStorageItem {
    param([string]$Path)

    try {
        Get-Item -LiteralPath $Path -Force
    }
    catch [System.Management.Automation.ItemNotFoundException] {
        return $null
    }
}

<#
.SYNOPSIS
    Rejects unsafe key paths and verifies that the key directory protects new files.
#>
function Test-DeployKeyStorageItem {
    param(
        [System.IO.FileSystemInfo]$Item,
        [switch]$Directory,
        [switch]$RequireChildAccess
    )

    if ($Item.Attributes.HasFlag([System.IO.FileAttributes]::ReparsePoint) -or
        ($Item -is [System.IO.DirectoryInfo]) -ne $Directory.IsPresent) {
        return $false
    }

    $security = Get-Acl -LiteralPath $Item.FullName
    $descriptor = [System.Security.AccessControl.RawSecurityDescriptor]::new(
        $security.GetSecurityDescriptorBinaryForm(), 0)
    if ($null -eq $descriptor.DiscretionaryAcl -or $descriptor.Owner.Value -notin $trustedSids) {
        return $false
    }

    $inheritsUserAccess = $false
    foreach ($rule in $security.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier])) {
        if ($rule.AccessControlType -ne 'Allow') {
            continue
        }

        $identity = $rule.IdentityReference.Value
        if ($identity -notin $trustedSids) {
            return $false
        }
        if ($identity -eq $userSid.Value -and $rule.InheritanceFlags.HasFlag($childInheritance) -and
            $rule.PropagationFlags -eq 'None' -and $rule.FileSystemRights.HasFlag(
                [System.Security.AccessControl.FileSystemRights]::FullControl)) {
            $inheritsUserAccess = $true
        }
    }

    return (-not $RequireChildAccess -or $inheritsUserAccess)
}

try {
    if ($PSCmdlet.ParameterSetName -eq 'KeyPair') {
        foreach ($path in @($PrivateKeyPath, "$PrivateKeyPath.pub")) {
            $item = Get-DeployKeyStorageItem -Path $path
            if ($item -and -not (Test-DeployKeyStorageItem -Item $item)) {
                exit 1
            }
        }
        exit 0
    }

    $managedDirectory = Join-Path $SshDirectory 'dev-tools'
    $keyDirectory = Join-Path $managedDirectory 'deploy-keys'
    $newDirectorySecurity = [System.Security.AccessControl.DirectorySecurity]::new()
    $newDirectorySecurity.SetOwner($userSid)
    $newDirectorySecurity.SetAccessRuleProtection($true, $false)
    $newDirectorySecurity.AddAccessRule([System.Security.AccessControl.FileSystemAccessRule]::new(
        $userSid, 'FullControl', $childInheritance, 'None', 'Allow'))

    foreach ($path in @($SshDirectory, $managedDirectory, $keyDirectory)) {
        $item = Get-DeployKeyStorageItem -Path $path
        if (-not $item) {
            $item = [System.IO.Directory]::CreateDirectory($path, $newDirectorySecurity)
        }
        if (-not (Test-DeployKeyStorageItem -Item $item -Directory -RequireChildAccess:($path -eq $keyDirectory))) {
            exit 1
        }
    }
}
catch {
    exit 1
}
