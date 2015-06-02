Param(
  [parameter(Mandatory=$true)]
  $Identifier,
  [parameter(Mandatory=$true)]
  $snapshot,
  [parameter(Mandatory=$true)]
  [string]
  $subnetGroupName,
  [parameter(Mandatory=$true)]
  [string]
  $type
)

Set-DefaultAWSRegion $env:AWSRegion

Restore-RDSDBInstanceFromDBSnapshot -DBInstanceIdentifier $Identifier -DBSnapshotIdentifier $snapshot -DBInstanceClass $type -DBSubnetGroupName $subnetGroupName
"wait for instances running..." | Out-Default 
do{
	Sleep 30
}while((Get-RDSDBInstance -DBInstanceIdentifier $Identifier).DBInstanceStatus -ne 'available' )


 