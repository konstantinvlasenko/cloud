$config = iex (new-object System.Text.ASCIIEncoding).GetString((Invoke-WebRequest -Uri http://169.254.169.254/latest/user-data -UseBasicParsing).Content)
Set-DefaultAWSRegion us-east-1
if($config.ssh -ne $null) {
  # download .ssh folder from AWS S3
  Read-S3Object -BucketName $config.ssh.Bucket -KeyPrefix $config.ssh.KeyPrefix -Folder "$($env:USERPROFILE)\.ssh"
}

$r53=[Amazon.AWSClientFactory]::CreateAmazonRoute53Client()
$ec2=[Amazon.AWSClientFactory]::CreateAmazonEC2Client()
function r53-delete-dns($name){
  $req = (new-object Amazon.Route53.Model.ListResourceRecordSetsRequest).WithHostedZoneId($config.HostedZoneId).WithStartRecordName($name)
  $rs = $r53.ListResourceRecordSets($req).ListResourceRecordSetsResult.ResourceRecordSets[0]
  if($rs){
    $action = (new-object Amazon.Route53.Model.Change).WithAction('DELETE').WithResourceRecordSet($rs)
    $changes = (new-object Amazon.Route53.Model.ChangeBatch).WithChanges($action)
    $req = (new-object Amazon.Route53.Model.ChangeResourceRecordSetsRequest).WithChangeBatch($changes).WithHostedZoneId($config.HostedZoneId)
    $r53.ChangeResourceRecordSets($req)
  }
}
function r53-create-dns($name, $cname){
  $record = (new-object Amazon.Route53.Model.ResourceRecord).WithValue($cname)
  $rs = (new-object Amazon.Route53.Model.ResourceRecordSet).WithName($name).WithType('CNAME').WithTTL('10').WithResourceRecords($record)
  $action = (new-object Amazon.Route53.Model.Change).WithAction('CREATE').WithResourceRecordSet($rs)
  $changes = (new-object Amazon.Route53.Model.ChangeBatch).WithChanges($action)
  $req = (new-object Amazon.Route53.Model.ChangeResourceRecordSetsRequest).WithChangeBatch($changes).WithHostedZoneId($config.HostedZoneId)
  $r53.ChangeResourceRecordSets($req)
}
function r53-set-dns($name, $cname){
  r53-delete-dns $name
  r53-create-dns $name $cname
}

function ec2-set-instance-tag($instid, $key, $value){
	$ec2.CreateTags((new-object Amazon.EC2.Model.CreateTagsRequest).WithResourceId($instid).WithTag((new-object Amazon.EC2.Model.Tag).WithKey($key).WithValue($value)))
}
function ec2-set-instance-name($instid, $name){
	ec2-set-instance-tag $instid 'Name' $name
}

$cname = (Invoke-WebRequest -Uri http://169.254.169.254/latest/meta-data/public-hostname -UseBasicParsing).Content
$instanceId = (Invoke-WebRequest -Uri http://169.254.169.254/latest/meta-data/instance-id -UseBasicParsing).Content

# attach EBS volume with TeamCity data
$filter = new-object Amazon.EC2.Model.Filter  
$filter.Name = 'tag:Name'  
$filter.Value = 'TeamCity'  
$volumeId = (Get-EC2Volume -Filter $filter).VolumeId
Add-EC2Volume $volumeId $instanceId xvdf
# start TeamCity
start-service TeamCity

# set instance name
ec2-set-instance-name $instanceId "ci.$($config.DomainName)"
r53-set-dns "ci.$($config.DomainName)" $cname

if($config.fitnesse -ne $null) {
  r53-set-dns "fitnesse.$($config.DomainName)" $cname
  # set instance name
  ec2-set-instance-name $instanceId "fitnesse.$($config.DomainName)"
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


