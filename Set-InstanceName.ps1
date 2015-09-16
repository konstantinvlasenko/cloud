Param($InstanceName)

Begin {
  Set-DefaultAWSRegion $env:AWSRegion
}

Process {
  do {
    Sleep 30
    # update spot requests information
    $spot = Get-EC2SpotInstanceRequest $_
    $spot.Status.Message | Out-Default
  } while( $spot.State -eq 'open' )
  "Set Instance Name:$InstanceName" | Out-Default 
  New-EC2Tag -Resource $spot.InstanceId -Tag @{Key='Name'; Value=$InstanceName}
}

End {
  # Executes once after last pipeline object is processed
}