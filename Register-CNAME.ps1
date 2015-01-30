Param(
  [parameter(Mandatory=$true)]
  [string]
  $name,
  [parameter(Mandatory=$true)]
  [string]
  $target,
  [string]
  $targetType = 'CNAME'
)

Set-DefaultAWSRegion $env:AWSRegion
"[R53]`t[$name] update... " | Out-Default
if($env:AssumeRoleArn -ne $null) {
  $credentials = (Use-STSRole -RoleArn $env:AssumeRoleArn -RoleSessionName $env:AssumeRoleSessionName).Credentials
}
# We will fall-back to the current account if $credential -eq $null
$hostedZones = Get-R53HostedZones -AccessKey $credentials.AccessKeyId -SecretKey $credentials.SecretAccessKey -SessionToken $credentials.SessionToken
$hostedZones | Out-Default
$hostedZoneId = $hostedZones | ? {$_.Name -eq "$($name.Split('.')[-2,-1] -join '.')."} | % {$_.Id.split('/')[-1]}
"[R53]`t[HostedZoneId] $hostedZoneId" | Out-Default
if($env:AssumeRoleArn -ne $null) {
  $result = Get-R53ResourceRecordSet -HostedZoneId $hostedZoneId -StartRecordName $name -MaxItems 1 -AccessKey $credentials.AccessKeyId -SecretKey $credentials.SecretAccessKey -SessionToken $credentials.SessionToken
}
else {
  $result = Get-R53ResourceRecordSet -HostedZoneId $hostedZoneId -StartRecordName $name -MaxItems 1
}

$rs = $result.ResourceRecordSets[0]

if($rs.Name -eq "$name.") {
  "[R53]`t[$name] entry found" | Out-Default
  "[R53]`t[$name] delete entry" | Out-Default
  $change = new-object Amazon.Route53.Model.Change
  $change.Action = 'DELETE'
  $change.ResourceRecordSet = $rs
  
  Edit-R53ResourceRecordSet -HostedZoneId $hostedZoneId -ChangeBatch_Changes $change -AccessKey $credentials.AccessKeyId -SecretKey $credentials.SecretAccessKey -SessionToken $credentials.SessionToken | Out-Null
} else { "[R53]`t[$name] entry not found (returned entry is for $($rs.Name))" | Out-Default }
"[R53]`t[$name] create entry" | Out-Default
$record = new-object Amazon.Route53.Model.ResourceRecord
$record.Value = $target
$rs = New-Object Amazon.Route53.Model.ResourceRecordSet
$rs.Name = $name
$rs.Type = $targetType
$rs.TTL = '10'
$rs.ResourceRecords = $record
$change = new-object Amazon.Route53.Model.Change
$change.Action = 'CREATE'
$change.ResourceRecordSet = $rs

Edit-R53ResourceRecordSet -HostedZoneId $hostedZoneId -ChangeBatch_Changes $change -AccessKey $credentials.AccessKeyId -SecretKey $credentials.SecretAccessKey -SessionToken $credentials.SessionToken | Out-Null
