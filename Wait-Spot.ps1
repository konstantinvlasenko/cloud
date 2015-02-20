Begin {
  # Executes once before first item in pipeline is processed
}

Process {
  "waiting for spot request fulfilment..." | Out-Default
  do {
    Sleep 30
    # update spot requests information
    $spot = Get-EC2SpotInstanceRequest $_
    $spot.Status.Message | Out-Default
  } while( $spot.State -eq 'open' )

  "wait for instances running..." | Out-Default 
  do {
    Sleep 30
  } while( (Get-EC2InstanceStatus $spot.InstanceId).InstanceState.Name -ne 'running' )

  "wait for reachability test..." | Out-Default
  do {
    Sleep 30
  } while( (Get-EC2InstanceStatus $spot.InstanceId).Status.Status.Value -ne 'ok' )

  $spot.InstanceId
}

End {
  # Executes once after last pipeline object is processed
}






Param(
  [parameter(Mandatory=$true)]
  [string]
  $name
)

Set-DefaultAWSRegion $env:AWSRegion

if($env:EC2UserData) { $userdata64 = [System.Convert]::ToBase64String( [System.Text.Encoding]::UTF8.GetBytes( $env:EC2UserData ) ) }

$role = Get-IAMInstanceProfileForRole $env:IAMRole

if($env:SubnetId)
{
  $sg = new-object Amazon.EC2.Model.GroupIdentifier
  $sg.GroupId = $env:SecurityGroup
  $spot =  Request-EC2SpotInstance -SpotPrice $env:SpotPrice -LaunchSpecification_InstanceType $type -LaunchSpecification_ImageId $ami -LaunchSpecification_AllSecurityGroup $sg -IamInstanceProfile_Arn $role.Arn -LaunchSpecification_UserData $userdata64 -LaunchSpecification_SubnetId $env:SubnetId
}
else
{
  $spot =  Request-EC2SpotInstance -SpotPrice $env:SpotPrice -LaunchSpecification_InstanceType $type -LaunchSpecification_ImageId $ami -LaunchSpecification_SecurityGroup $env:SecurityGroup -IamInstanceProfile_Arn $role.Arn -LaunchSpecification_UserData $userdata64
}

"waiting for spot request fulfilment..." | Out-Default
do {
  Sleep 30
  # update spot requests information
  $spot = Get-EC2SpotInstanceRequest $spot.SpotInstanceRequestId
  $spot.Status.Message | Out-Default
} while( $spot.State -eq 'open' )

# set instance name
New-EC2Tag -Resource $spot.InstanceId -Tag @{ Key="Name"; Value=$name }

"wait for instances running..." | Out-Default 
do {
  Sleep 30
} while( (Get-EC2InstanceStatus $spot.InstanceId).InstanceState.Name -ne 'running' )

"wait for reachability test..." | Out-Default
do {
  Sleep 30
} while( (Get-EC2InstanceStatus $spot.InstanceId).Status.Status.Value -ne 'ok' )

$spot.InstanceId