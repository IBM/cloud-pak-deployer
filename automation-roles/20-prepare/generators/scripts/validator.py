import sys
import base64, json, yaml
#from schema import  Schema, And, Use, Optional, SchemaError

# convert the input base64-yaml strings
generatorSchema     = yaml.load(base64.b64decode(sys.argv[2]), Loader=yaml.FullLoader)
generatorAttributes = yaml.load(base64.b64decode(sys.argv[3]), Loader=yaml.FullLoader)
generatorFullConfig = yaml.load(base64.b64decode(sys.argv[4]), Loader=yaml.FullLoader)





### utility functions
def devprint(*argv):
    if sys.argv[1]!='ansible':
        print(*argv)



def runCheck(checkDict):
    checkKey, checkParams = checkDict.popitem()

    if("check_"+checkKey in globals() and (isinstance(checkParams, str) or isinstance(checkParams, bool)) ):
        return globals()["check_"+checkKey](checkParams)
    else:
        print("WARNING:",checkKey,"is not a defined test")
        return True

def getPropertValueByKeyList(keyList, queryDictionary):
    devprint("QUERY:",keyList)
    lastValue = queryDictionary
    for i in range(0,len(keyList)):
        devprint(keyList)
        devprint(i)
        devprint('IS :lastValue:',lastValue)
        devprint('SET:lastValue:',lastValue.get( keyList[i] ))
        
        #print('lastValue:',lastValue)
        if(isinstance(lastValue, dict)):
            lastValue = lastValue.get( keyList[i] )
        if(isinstance(lastValue, list)):
            #print('found a list',lastValue)
            #print('|->',pathFragmentsOfSchema)
            # return all properties that match keyList[i]
            # in a list
            emptyList = [] 
            for j in range(0, len(lastValue)):
                devprint("something",lastValue[j])
                devprint("|->",keyList[i])
                # TODO: We suppose the last key is a property of the list item
                # and just query for this key  
                emptyList.append( lastValue[j].get(keyList[i+1]) )
            # in this case we get the 
            return emptyList
        if(lastValue==None):
            devprint("COULDN'T FIND:",keyList,"in",queryDictionary)
            return False
    return lastValue
# the checks:


def check_isRequired(check=True):
    global error_count
    # check if the generatorAttributes-object has this property
    # print(generatorAttributes)
    # print(pathFragmentsOfSchema)
    # Output:
    # {'allow_inbound': ['ssh', 'bogus'], 'name': 'sample'}
    # ['name']
    devprint("CHECK START 'required': check if",pathFragmentsOfSchema,"exists")
    attributeValueFromGenerator = getPropertValueByKeyList(pathFragmentsOfSchema, generatorAttributes)
    
    #print("queryValue:",queryValue)
    if(attributeValueFromGenerator!=None):
        devprint("CHECK SUCCESS: FOUND:",pathFragmentsOfSchema, " does exist and has value:",attributeValueFromGenerator)
        return None
    else:
        devprint("CHECK FAILED: COUDLN'T FIND:",pathFragmentsOfSchema)
        #error_count = error_count+1
        newError = {
            'path': '/'.join(pathFragmentsOfSchema),
            'attributeValue': 'None',
            'message': str(pathFragmentsOfSchema)+" was not defined"
        }
        return newError
    #print('check', queryValue)

def check_ref(key, value, possibleValues):
    return

def check_isDefinedNameOf(checkParameter):
    attributeValueFromGenerator = getPropertValueByKeyList(pathFragmentsOfSchema, generatorAttributes)
    devprint("--- isDefinedNameOf ---",attributeValueFromGenerator)
    if(isinstance(checkParameter, str)):
        #if(checkParameter[:2]=='//'):
            # if the string starts with // we threat it as a reference
            #lookedUpNames = getPropertValueByKeyList( checkParameter[2:].split('/'), generatorFullConfig )
        lookedUpNames = getPropertValueByKeyList([checkParameter, 'name'], generatorFullConfig)
        devprint('|>looking for instances of',checkParameter)
        devprint('\> isDefinedNameOf received:',lookedUpNames)
        if attributeValueFromGenerator in lookedUpNames:
            return None
        else:
            newError = {
                'path': '/'.join(pathFragmentsOfSchema),
                'attributeValue': attributeValueFromGenerator,
                'message': "isDefinedNameOf: failed - "+attributeValueFromGenerator+" is not in "+str(lookedUpNames)
            }
            return newError

### Implementation starts here
devprint('---')
devprint(generatorSchema)
devprint(generatorAttributes)
devprint('---')


## Variables we'll make use of
generatorSchemaSchema = generatorSchema.get('schema')
validator_results = {}
pathFragmentsOfSchema = []
output_errors = []

# move this to the other util-functions
def processSchemaDict(subDict):
    devprint('entering dict',pathFragmentsOfSchema)
    keyCount = len(subDict.keys())
    #print(keyCount)
    for key, value in subDict.items():
        pathFragmentsOfSchema.append(key)
        devprint('- processing -> ',key, ': ', value, ' (', str(type(value)), ')')
        if  ( isinstance(value, str) ):
            # key contains a string, suppose it's the name of a check
            result = runCheck(value)
            pathFragmentsOfSchema.pop(-1)
        elif( isinstance(value, list) ):
            for checkitem in value:
                devprint(checkitem)
                if( isinstance(checkitem, dict) ):
                    result = runCheck(checkitem)
                    if(result!=None):
                        output_errors.append(result)
                #elif( isinstance(value, dict) ):
                    
            pathFragmentsOfSchema.pop(-1)
        elif( isinstance(value, dict) ):
            # process the items
            #print('- going one level deeper')
            processSchemaDict(value)
            # when done with the processing, remove this dicts 
            # path from the end of the pathFragmentsOfSchema-list
            pathFragmentsOfSchema.pop(-1)
#print(generator_schema)

processSchemaDict(generatorSchemaSchema)

if(sys.argv[1]=='ansible'):

    print(json.dumps({
        'errors': output_errors,
    }, indent=4, separators=(',', ': '), sort_keys=True))