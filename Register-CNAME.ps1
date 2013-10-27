Param(
  [parameter(Mandatory=$true)]
  [hashtable]
  $config,
  [parameter(Mandatory=$true)]
  [string]
  $name,
  [parameter(Mandatory=$true)]
  [string]
  $cname
)

"[R53]`t[$name] update... " | Out-Default
if($config.AssumeRoles.R53 -ne $null) {
  "[R53]`t[$name] using assume role $($config.AssumeRoles.R53.ARN)" | Out-Default
  $credentials = (Use-STSRole -RoleArn $config.AssumeRoles.R53.ARN -RoleSessionName $config.AssumeRoles.R53.SessionName).Credentials
}
# We will fall-back to the current account if $credential -eq $null
$hostedZones = Get-R53HostedZones -AccessKey $credentials.AccessKeyId -SecretKey $credentials.SecretAccessKey -SessionToken $credentials.SessionToken
$hostedZones | Out-Default
$hostedZoneId = $hostedZones | ? {$_.Name -eq "$($config.DomainName)."} | % {$_.Id.split('/')[-1]}
"[R53]`t[HostedZoneId] $hostedZoneId" | Out-Default
if($config.AssumeRoles.R53 -ne $null) {
  $result = Get-R53ResourceRecordSet -HostedZoneId $hostedZoneId -StartRecordName $name -MaxItems 1 -AccessKey $credentials.Credentials.AccessKeyId -SecretKey $credentials.Credentials.SecretAccessKey -SessionToken $credentials.Credentials.SessionToken
}
else {
  $result = Get-R53ResourceRecordSet -HostedZoneId $hostedZoneId -StartRecordName $name -MaxItems 1
}

$rs = $result.ResourceRecordSets[0]

if($rs.Name -eq "$name.") {
  "[R53]`t[$name] entry found" | Out-Default
  "[R53]`t[$name] delete entry" | Out-Default
  $action = (new-object Amazon.Route53.Model.Change).WithAction('DELETE').WithResourceRecordSet($rs)
  
  Edit-R53ResourceRecordSet -HostedZoneId $hostedZoneId -ChangeBatch_Changes $action -AccessKey $credentials.AccessKeyId -SecretKey $credentials.SecretAccessKey -SessionToken $credentials.SessionToken | Out-Null
} else { "[R53]`t[$name] entry not found (returned entry is for $($rs.Name))" | Out-Default }
"[R53]`t[$name] create entry" | Out-Default
$record = (new-object Amazon.Route53.Model.ResourceRecord).WithValue($cname)
$rs = (new-object Amazon.Route53.Model.ResourceRecordSet).WithName($name).WithType('CNAME').WithTTL('10').WithResourceRecords($record)
$action = (new-object Amazon.Route53.Model.Change).WithAction('CREATE').WithResourceRecordSet($rs)

Edit-R53ResourceRecordSet -HostedZoneId $hostedZoneId -ChangeBatch_Changes $action -AccessKey $credentials.AccessKeyId -SecretKey $credentials.SecretAccessKey -SessionToken $credentials.SessionToken | Out-Null
