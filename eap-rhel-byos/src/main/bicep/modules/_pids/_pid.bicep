param name string = 'pid'

// create a pid deployment if there is a specified name
module pidStart './_empty.bicep' = if (name != 'pid'){
  name: name
}

output dbEnd string = '1e9fe9c5-e8a7-53ba-a776-df67d8682811'
output dbStart string = '0f43c3e1-814d-5079-a35f-123066cfbb30'

output byosSingleEnd string = '104b9ff5-85f1-4188-bcd9-905bd8f68dc1'
output byosSingleStart string = '22c886c6-73cf-4f24-b835-f970c524297d'
