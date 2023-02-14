param name string = 'pid'

// create a pid deployment if there is a specified name
module pidStart './_empty.bicep' = if (name != 'pid'){
  name: name
}

output appgwEnd string = '62974874-11fb-4fb8-b158-1c1423c60a2f'
output appgwStart string = '30186e04-251a-48df-8669-3c9bcd4bbb25'
output dbEnd string = '73af7d0c-6589-580d-99a5-bcd969f42d0b'
output dbStart string = '5edb2db7-51ee-5b9f-8297-f6a0d51fd850'
