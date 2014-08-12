Param(
  [parameter(Mandatory=$true)]
  $ReservedInstancesId,
  [parameter(Mandatory=$true)]
  $engine,
  [parameter(Mandatory=$true)]
  $Identifier,
  [parameter(Mandatory=$true)]
  $database,
  [parameter(Mandatory=$true)]
  [string[]]
  $securityGroups,
  [parameter(Mandatory=$true)]
  $password,
  [parameter(Mandatory=$false)]
  $size = 5
)

$ri = Get-RDSReservedDBInstance $ReservedInstancesId
$type = $ri.DBInstanceClass                      # Instance type from the reservation
$engine = 'postgres'
$multiAZ = $ri.MultiAZ                           # MultiAZ from the reservation
$sgIds = $securityGroups | % { (Get-EC2SecurityGroup -GroupName $_).GroupId }

New-RDSDBInstance -DBName $database -DBInstanceIdentifier $Identifier -AllocatedStorage $size -AutoMinorVersionUpgrade $true -BackupRetentionPeriod 1 -DBInstanceClass $type -VpcSecurityGroupIds $sgIds -Engine $engine -Iops $false -MasterUsername 'administrator' -MasterUserPassword $password -MultiAZ $multiAZ -PubliclyAccessible $true