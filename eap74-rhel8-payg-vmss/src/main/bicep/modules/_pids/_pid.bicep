param name string = 'pid'

// create a pid deployment if there is a specified name
module pidStart './_empty.bicep' = if (name != 'pid'){
  name: name
}

output appgwEnd string = 'c1489dfb-5c3e-4c30-8dd1-389fbf160899'
output appgwStart string = '1ed104a9-4c59-493b-90d6-cc76b0014bc8'
output dbEnd string = 'dfe281b6-b9c5-59ea-b1cd-2b6de35b842e'
output dbStart string = '5d244bcd-2277-5f17-a92a-9c06df55a6ac'
output paygVmssEnd string = '309369f2-9983-4701-aa97-5e08daf6a86d'
output paygVmssStart string = '9fb8b19f-1d30-47d7-93f0-97ce3dc18aea'
