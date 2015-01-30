Param(
  [parameter(Mandatory=$true)]
  [string]
  $ami,
  [parameter(Mandatory=$true)]
  [string]
  $type,
  [parameter(Mandatory=$true)]
  [string]
  $name
)

Set-DefaultAWSRegion $env:AWSRegion

if($env:EC2UserData) { $userdata64 = [System.Convert]::ToBase64String( [System.Text.Encoding]::UTF8.GetBytes( $env:EC2UserData ) ) }

$role = Get-IAMInstanceProfileForRole $env:IAMRole

$spot =  Request-EC2SpotInstance -SpotPrice $env:SpotPrice -LaunchSpecification_InstanceType $type -LaunchSpecification_ImageId $ami -LaunchSpecification_SecurityGroups $env:SecurityGroup -LaunchSpecification_IamInstanceProfile_Arn $role.Arn -LaunchSpecification_UserData $userdata64

"waiting for spot request fulfilment..." | Out-Default
do {
  Sleep 30
  # update spot requests information
  $spot = Get-EC2SpotInstanceRequest $spot.SpotInstanceRequestId
  $spot.Status.Message | Out-Default
} while( $spot.State -eq 'open' )

# set instance name
$tag = new-object Amazon.EC2.Model.Tag
$tag.Key = "Name"
$tag.Value = $name
New-EC2Tag -ResourceId $spot.InstanceId -Tag $tag

"wait for instances running..." | Out-Default 
do {
  Sleep 30
} while( (Get-EC2InstanceStatus $spot.InstanceId).InstanceState.Name -ne 'running' )

"wait for reachability test..." | Out-Default
do {
  Sleep 30
} while( (Get-EC2InstanceStatus $spot.InstanceId).Status.Status.Value -ne 'ok' )

$spot.InstanceId