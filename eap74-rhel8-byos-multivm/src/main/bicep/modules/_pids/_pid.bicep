param name string = 'pid'

// create a pid deployment if there is a specified name
module pidStart './_empty.bicep' = if (name != 'pid'){
  name: name
}

output appgwEnd string = 'c11e6f5e-2f0f-449d-acde-a26488482dfa'
output appgwStart string = '849dfc91-6601-4cae-aa36-b206eff21eec'
output dbEnd string = '73af7d0c-6589-580d-99a5-bcd969f42d0b'
output dbStart string = '5edb2db7-51ee-5b9f-8297-f6a0d51fd850'
output byosMultivmEnd string = 'e5ec432a-36da-4cf6-994d-34f9581bc32b'
output byosMultivmStart string = '6f94774d-2386-4bbe-967c-b2e09547392b'
