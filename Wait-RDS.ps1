Param(
  [parameter(Mandatory=$true)]
  $Identifier
)
Set-DefaultAWSRegion $env:AWSRegion
"wait for instances running..." | Out-Default 
do{
	Sleep 30
}while((Get-RDSDBInstance -DBInstanceIdentifier $Identifier).DBInstanceStatus -ne 'available' )


