param name string = 'pid'

// create a pid deployment if there is a specified name
module pidStart './_empty.bicep' = if (name != 'pid'){
  name: name
}

output dbEnd string = '1e9fe9c5-e8a7-53ba-a776-df67d8682811'
output dbStart string = '0f43c3e1-814d-5079-a35f-123066cfbb30'
