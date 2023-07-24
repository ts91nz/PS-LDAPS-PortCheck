<#
.Synopsis
   Test LDAP functionality and port connectivity. 
.DESCRIPTION
   Get port status for LDAPS on connected DC
.EXAMPLE
   .\LDAPS-Check.ps1 -dir C:\Temp
.OUTPUTS
   File: LDAPS_Status_[Computer_Name].csv
#>

param(
    [string]$dir = 'C:\temp'
)

# Functions
function Test-LDAPPorts {
    [CmdletBinding()]
    param(
        [string] $ServerName,
        [int] $Port
    )
    if ($ServerName -and $Port -ne 0) {
        try {
            $LDAP = "LDAP://" + $ServerName + ':' + $Port
            $Connection = [ADSI]($LDAP)
            $Connection.Close()
            return $true
        } catch {
            if ($_.Exception.ToString() -match "The server is not operational") {
                Write-Warning "Can't open $ServerName`:$Port."
            } elseif ($_.Exception.ToString() -match "The user name or password is incorrect") {
                Write-Warning "Current user ($Env:USERNAME) doesn't seem to have access to to LDAP on port $Server`:$Port"
            } else {
                Write-Warning -Message $_
            }
        }
        return $False
    }
}
Function Test-LDAP {
    [CmdletBinding()]
    param (
        [alias('Server', 'IpAddress')][Parameter(Mandatory = $True)][string[]]$ComputerName,
        [int] $GCPortLDAPSSL = 3269,
        [int] $PortLDAPS = 636
    )
    # Checks for ServerName - Makes sure to convert IPAddress to DNS
    foreach ($Computer in $ComputerName) {
        [Array] $ADServerFQDN = (Resolve-DnsName -Name $Computer -ErrorAction SilentlyContinue)
        if ($ADServerFQDN) {
            if ($ADServerFQDN.NameHost) {
                $ServerName = $ADServerFQDN[0].NameHost
            } else {
                [Array] $ADServerFQDN = (Resolve-DnsName -Name $Computer -ErrorAction SilentlyContinue)
                $FilterName = $ADServerFQDN | Where-Object { $_.QueryType -eq 'A' }
                $ServerName = $FilterName[0].Name
            }
        } else {
            $ServerName = ''
        }
        $GlobalCatalogSSL = Test-LDAPPorts -ServerName $ServerName -Port $GCPortLDAPSSL
        $ConnectionLDAPS = Test-LDAPPorts -ServerName $ServerName -Port $PortLDAPS

        $csvContents = @()
        $row = New-Object System.Object
        $row | Add-Member -MemberType NoteProperty -Name "Server" -Value $ServerName
        $row | Add-Member -MemberType NoteProperty -Name "GlobalCatalogLDAPS" -Value $GlobalCatalogSSL
        $row | Add-Member -MemberType NoteProperty -Name "LDAPS" -Value $ConnectionLDAPS
        $row | Add-Member -MemberType NoteProperty -Name "Port_3269" -Value $GCPortLDAPSSL
        $row | Add-Member -MemberType NoteProperty -Name "Port_636" -Value $PortLDAPS
        $csvContents += $row 
        Write-Output $csvContents | Export-CSV -Path $file -NoTypeInformation
        $csvContents | ft
    }
}

### Main ###
# Remove old log file.
$file = "$dir\LDAPS_Status_$($env:ComputerName).csv"
If(Test-Path $file){
    Remove-Item $file -Force
}
Try{
    #Get domain controller
    $getdomain = [System.Directoryservices.Activedirectory.Domain]::GetCurrentDomain()
    $svr = $getdomain.PdcRoleOwner.Name
} Catch {
    #No domain setup, using WORKGROUP, set localhost. 
    $getdomain = 0
    $svr = $env:ComputerName
}
#Test-LDAP -ComputerName $svr | Out-File $file
Test-LDAP -ComputerName $svr 



