param name string = 'pid'

// create a pid deployment if there is a specified name
module pidStart './_empty.bicep' = if (name != 'pid'){
  name: name
}

output appDeployEnd string = '2246b2ba-b514-417a-9d7b-dd2244511ce6'
output appDeployStart string = 'd4a71c48-a526-4d3f-b114-6a28de03d629'
