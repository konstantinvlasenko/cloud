param($lab)
$config = iex (new-object System.Text.ASCIIEncoding).GetString((Invoke-WebRequest -Uri http://169.254.169.254/latest/user-data -UseBasicParsing).Content)
$DefaultAWSRegion = (ConvertFrom-Json (Invoke-WebRequest -Uri http://169.254.169.254/latest/dynamic/instance-identity/document -UseBasicParsing).Content).region
Set-DefaultAWSRegion $DefaultAWSRegion
"************************************`n*`tDefault AWS Region - $DefaultAWSRegion`n************************************" | Out-Default

$lab | % { $_.name += ".$($config.DomainName)" }
$lab | ? { $_.type -eq $null } | % { $_.type = $env:DefaultInstanceType }
$lab | % { $_ | Out-Default }
# check if the lab already started
$instances = Get-EC2Tag | ? ResourceType -eq Instance | ? Key -eq Name | ? Value -eq $lab[0].name | % ResourceId | % { Get-EC2InstanceStatus $_ } | ? { $_.InstanceState.Code -eq 16}
if($instances -ne $null) {
  "Lab already started. Exiting..." | Out-Default
  exit -1
}

# obtain all Private images
$images = Get-EC2Image | ? Public -eq $false

# S3Reader role
$role = Get-IAMInstanceProfileForRole S3Reader

# create spot requests
$lab | ? { $_.zone -eq $null } | % { $_.request = Request-EC2SpotInstance -SpotPrice $_.maxbid -LaunchSpecification_InstanceType $_.type -LaunchSpecification_ImageId ($images | ? Name -eq $_.amiName).ImageId -LaunchSpecification_SecurityGroup $config.SecurityGroup -IamInstanceProfile_Arn $role.Arn }

$lab | ? { $_.zone -ne $null } | % { $_.request = Request-EC2SpotInstance -SpotPrice $_.maxbid -LaunchSpecification_Placement_AvailabilityZone $_.zone -LaunchSpecification_InstanceType $_.type -LaunchSpecification_ImageId ($images | ? Name -eq $_.amiName).ImageId -LaunchSpecification_SecurityGroup $config.SecurityGroup -IamInstanceProfile_Arn $role.Arn }

"waiting for spot requests fulfilment..." | Out-Default
do {
  Sleep 60
  # update spot requests information
  $lab | % { $_.request = Get-EC2SpotInstanceRequest $_.request.SpotInstanceRequestId }
  $lab | % { "[$($_.name)]`t$($_.request.Status.Message)" | Out-Default }
} while( ($lab | ? { $_.request.State -eq 'open'} ) -ne $null )

# set instances name
$lab | % { New-EC2Tag -Resource $_.request.InstanceId -Tag @{ Key="Name"; Value=$_.name } }

"wait for instances running..." | Out-Default 
do {
  Sleep 30
} while( ($lab | ? { (Get-EC2InstanceStatus $_.request.InstanceId).InstanceState.Name -ne 'running' }) -ne $null )

"wait for reachability test..." | Out-Default
do {
  Sleep 30
} while( ($lab | ? { (Get-EC2InstanceStatus $_.request.InstanceId).Status.Status -ne 'ok' }) -ne $null )

# get instances
$lab | % { $_.instance = (Get-EC2Instance $_.request.InstanceId).RunningInstance }
$lab | % { "[$($_.name)]`t$($_.instance.PublicDnsName)" | Out-Default }

# update R53
$lab | % { .\Register-CNAME.ps1 $_.name $_.instance.PublicDnsName }

"update DNS on clients..." | Out-Default
function Update-DNS($clientIP, $dnsIP) {
  $NICs = Get-WMIObject Win32_NetworkAdapterConfiguration -ComputerName $clientIP | ? IPEnabled -eq 'TRUE'
  foreach($n in $NICs) {$n.SetDNSServerSearchOrder($dnsIP); $n.SetDynamicDNSRegistration('TRUE')}
}
# first computer is DNS
$lab | select -skip 1 | % { Update-DNS $_.instance.PrivateIpAddress $lab[0].instance.PrivateIpAddress | Out-Null }

"Tests whether the WinRM service is running on the clients..." | Out-Default
do {
  Sleep 60
  $lab | ? { $_.WSMan -ne $true } | % { $_.WSMan = (Test-WSMan $_.name) -ne $null }
  $lab | % { "[$($_.name)]`WSMan = $($_.WSMan)" | Out-Default }
  
} while( ($lab | ? { $_.WSMan -ne $true }) -ne $null )

"disable IEESC..." | Out-Default
Invoke-Command -computer $lab.instance.PrivateIpAddress -script {
  '{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}','{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}' | % { Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\$_" -Name 'IsInstalled' -Value 0 }
}

"disable firewall..." | Out-Default
Invoke-Command -computer $lab.instance.PrivateIpAddress -script {
  netsh advfirewall set allprofiles state off
}
