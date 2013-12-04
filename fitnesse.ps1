$config = iex (new-object System.Text.ASCIIEncoding).GetString((Invoke-WebRequest -Uri http://169.254.169.254/latest/user-data -UseBasicParsing).Content)
Set-DefaultAWSRegion us-east-1
if($config.SNS -ne $null) {
  [Environment]::SetEnvironmentVariable("SNS", $config.SNS, "Machine")
}

if($config.ssh -ne $null) {
  # download .ssh folder from AWS S3
  Read-S3Object -BucketName $config.ssh.Bucket -KeyPrefix $config.ssh.KeyPrefix -Folder "$($env:USERPROFILE)\.ssh"
}

$cname = (Invoke-WebRequest -Uri http://169.254.169.254/latest/meta-data/public-hostname -UseBasicParsing).Content
$instanceId = (Invoke-WebRequest -Uri http://169.254.169.254/latest/meta-data/instance-id -UseBasicParsing).Content

# set instance name
New-EC2Tag -ResourceId $instanceId -Tag (new-object Amazon.EC2.Model.Tag).WithKey('Name').WithValue("ci.$($config.DomainName)")
.\Register-CNAME.ps1 $config "ci.$($config.DomainName)" $cname
.\Register-CNAME.ps1 $config "fitnesse.$($config.DomainName)" $cname

# attach EBS volume with TeamCity data
$filter = new-object Amazon.EC2.Model.Filter  
$filter.Name = 'tag:Name'  
$filter.Value = 'TeamCity'  
$volumeId = (Get-EC2Volume -Filter $filter).VolumeId
Add-EC2Volume $volumeId $instanceId xvdf
do {
  Sleep 5
}while((Test-Path 'd:') -ne $true)

#pull latest configuration
cd d:\config\projects
git pull

# start TeamCity
Restart-Service TCBuildAgent 
Restart-Service TCBuildAgent1 
Start-Service TeamCity

# search computer by name
Invoke-WmiMethod -path Win32_NetworkAdapterConfiguration -Name SetDNSSuffixSearchOrder -ArgumentList @($config.DomainName)

if($config.fitnesse -ne $null) {
  cd c:\
  # clone PowerSlim
  git clone https://github.com/konstantinvlasenko/PowerSlim.git
  # download Fitnesse
  (new-object System.Net.WebClient).DownloadFile('http://fitnesse.org/fitnesse-standalone.jar?responder=releaseDownload&release=20130530', 'c:\PowerSlim\fitnesse-standalone.jar')
  iex $config.fitnesse
  # start Fitnesse 
  cd c:\PowerSlim
  java -jar fitnesse-standalone.jar -d c:\fitnesse -p 8081
}


