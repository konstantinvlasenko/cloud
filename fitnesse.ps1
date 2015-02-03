$config = iex (new-object System.Text.ASCIIEncoding).GetString((Invoke-WebRequest -Uri http://169.254.169.254/latest/user-data -UseBasicParsing).Content)
$DefaultAWSRegion = (ConvertFrom-Json (Invoke-WebRequest -Uri http://169.254.169.254/latest/dynamic/instance-identity/document -UseBasicParsing).Content).region
Set-DefaultAWSRegion $DefaultAWSRegion
[Environment]::SetEnvironmentVariable("AWSRegion", $DefaultAWSRegion, "Machine")
if($config.Bucket -ne $null) {
  [Environment]::SetEnvironmentVariable("Bucket", $config.Bucket, "Machine")
}
if($config.SNS -ne $null) {
  [Environment]::SetEnvironmentVariable("SNS", $config.SNS, "Machine")
}

if($config.ssh -ne $null) {
  # download .ssh folder from AWS S3
  Read-S3Object -BucketName $config.ssh.Bucket -KeyPrefix $config.ssh.KeyPrefix -Folder "$($env:USERPROFILE)\.ssh"
}

if($config.AssumeRoles.R53 -ne $null) {
  [Environment]::SetEnvironmentVariable("AssumeRoleArn",$config.AssumeRoles.R53.ARN, "Machine")
  [Environment]::SetEnvironmentVariable("AssumeRoleSessionName",$config.AssumeRoles.R53.SessionName, "Machine")
}

$cname = (Invoke-WebRequest -Uri http://169.254.169.254/latest/meta-data/public-hostname -UseBasicParsing).Content
$instanceId = (Invoke-WebRequest -Uri http://169.254.169.254/latest/meta-data/instance-id -UseBasicParsing).Content

# set instance name
New-EC2Tag -Resource $instanceId -Tag @{ Key="Name"; Value="ci.$($config.DomainName)" }
.\Register-CNAME.ps1 "ci.$($config.DomainName)" $cname
.\Register-CNAME.ps1 "fitnesse.$($config.DomainName)" $cname

# attach EBS volume with TeamCity data
$volumeId = (Get-EC2Volume -Filters @{ Name="tag:Name"; Values=@("TeamCity") }).VolumeId
Add-EC2Volume $instanceId $volumeId xvdf
do {
  Sleep 5
}while((Test-Path 'd:') -ne $true)

#pull latest configuration
cd d:\config\projects
git pull

# start TeamCity
Restart-Service TCBuildAgent 
Restart-Service TCBuildAgent1 
Restart-Service TCBuildAgent3
Start-Service TeamCity

# search computer by name
Invoke-WmiMethod -path Win32_NetworkAdapterConfiguration -Name SetDNSSuffixSearchOrder -ArgumentList @($config.DomainName)

if($config.fitnesse -ne $null) {
  cd c:\
  # clone PowerSlim
  git clone https://github.com/konstantinvlasenko/PowerSlim.git
  # download Fitnesse
  Invoke-WebRequest 'http://fitnesse.org/fitnesse-standalone.jar?responder=releaseDownload&release=20150114' -OutFile 'c:\PowerSlim\fitnesse-standalone.jar'
  iex $config.fitnesse
  # start Fitnesse 
  cd c:\PowerSlim
  java -jar fitnesse-standalone.jar -d c:\fitnesse -p 8081
}


