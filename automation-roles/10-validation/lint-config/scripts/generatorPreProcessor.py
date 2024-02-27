from benedict import benedict

class GeneratorPreProcessor:
    def __init__(self,attributes=None, fullConfig=None, moduleVariables=None) -> None:
        self.d = benedict()
        self.recentCheck = {}
        self.attributes = attributes
        # these are the attributes we'll modify 
        # during preprocessing
        self.attributesDict = benedict(attributes) 
        self.fullConfig = fullConfig
        self.fullConfigDict = benedict(fullConfig)
        self.moduleVariables = moduleVariables
        self.errors = []

    def __call__(self,pathToCheck):

        self.recentCheck = {
            'pathToCheck': pathToCheck,
            'resolved': False,
            'canceled': False
        }
        # check, that it actually exists
        return self

    def __eq__(self,other):
        # in normal conditions 'other' will be True/typeof bool
        # self.recentCheck.pathToCheck = pathToCheck
        #print(self.recentCheck.get('pathToCheck'))
        if(type(other) is bool):
            return (self.recentCheck.get('pathToCheck') in self.attributesDict)
        if(type(other) is (str or int)):
            if ( (self.recentCheck.get('pathToCheck') in self.attributesDict)==False):
                return False
            else:
                return self.attributesDict[self.recentCheck.get('pathToCheck')]

    def isRequired(self):
        if((self.recentCheck.get('pathToCheck') in self.attributesDict)==False):
            self.recentCheck['canceled'] = True
            self.appendError(msg="Attribute {path} is not defined".format(path=self.recentCheck.get('pathToCheck')))
        return self

    def isOptional(self):
        if((self.recentCheck.get('pathToCheck') in self.attributesDict)==False):
            self.recentCheck['canceled'] = True
        return self




    # mustBeOneOf(List)
    # sample: .mustBeOneOf(['one','two'])
    # accepts 
    # matchPattern (string): should look like 'address_prefix[*].name'
    # value represented by path is allowed to be a string or a list of strings
    def mustBeOneOf(self,matchPattern, remoteIdentifier='name'):
        if self.recentCheck['canceled']==False:
            # mustBeOneOf is supposed to compare lists against lists
            # if localPropertyValue is not a list we'll convert it to 
            # a list with a single element
            localPropertyValue =  self.attributesDict[  self.recentCheck.get('pathToCheck') ]
            if (type(localPropertyValue) is not list):
                localPropertyList = [ localPropertyValue ]
            else:
                localPropertyList = localPropertyValue

            if (type(matchPattern) is list):
                foundInList=False
                #localPropertyValue =  self.attributesDict[  self.recentCheck.get('pathToCheck') ]
                for local_i in range(len(localPropertyList)):
                    foundInList=False
                    for remote_i in range(len(matchPattern)):
                        #print( str(localPropertyList[local_i]) + " == " + str(matchPattern[remote_i]) +"?")
                        if(localPropertyList[local_i]==matchPattern[remote_i]):
                            #print("True")
                            foundInList=True
                    if foundInList==False:
                        # convert the array members to string before trying to print then
                        remote_entries = [str(remote_entry) for remote_entry in matchPattern]
                        self.appendError(msg="{value} is not one of [{listValues}]".format(value=str(localPropertyList[local_i]),listValues=', '.join(remote_entries) ))
            else:
                # matchPattern is a string that resolves to a list of strings

                matchPatternCombined=matchPattern+'.'+remoteIdentifier
                #print( self.attributesDict[ self.recentCheck.get('pathToCheck') ] )
                #print(self.attributesDict)
                localPropertyValue =  self.attributesDict[  self.recentCheck.get('pathToCheck') ]
                listOfMatches = self.fullConfigDict.match(matchPatternCombined)
                if(type(localPropertyValue) is str):
                    if( (localPropertyValue in listOfMatches)==False):
                        self.appendError(msg="{value} seems not to be in {remoteValues}".format(value=localPropertyValue,remoteValues=matchPatternCombined ))
                if(type(localPropertyValue) is list):
                    for i in range(len(localPropertyValue)):
                        if( (localPropertyValue[i] in listOfMatches)==False):
                            self.appendError(msg="'{value}' is not one of [{remoteValues}]".format(value=localPropertyValue[i],remoteValues=', '.join(listOfMatches) ))


        #print(listOfMatches)
        #print(self.attributesDict[ lookupPath ])
        return self












    def lookupFromProperty(self, localProperty, generatorName, remotePath, identifierProp='name'):
        if((self.recentCheck.get('pathToCheck') in self.attributesDict)==False):
            if(localProperty in self.attributesDict )==False:
                self.appendError(msg="Can't lookup "+self.recentCheck.get('pathToCheck')+" via "+localProperty+" because "+localProperty+" was not set")
                return self
            localPropertyValue =  self.attributesDict[ localProperty ] # first_zone_prefix
            generatorsListOfEntities = self.fullConfigDict.get(generatorName,[])
            for i in range(len(generatorsListOfEntities)):
                if generatorsListOfEntities[i][identifierProp]==localPropertyValue:
                    self.attributesDict[ self.recentCheck.get('pathToCheck') ]=generatorsListOfEntities[i][remotePath]
        else:
            self.recentCheck['resolved'] = True
        return self
        # generatorsListOfEntities = self.fullConfigDict.get(generatorName,[])
        # if len(generatorsListOfEntities)==0:
        #     self.appendError(msg="Can't expand, no instances of " + generatorName + " found.")
        #     return self
        # if len(generatorsListOfEntities)>1:
        #     self.appendError(msg="Can't expand, " + generatorName + " not unique.")
        #     return self
        # if len(generatorsListOfEntities)==1:
        #     print( generatorsListOfEntities[0] )
        #     self.attributesDict[self.recentCheck.pathToCheck] = generatorsListOfEntities[0][remotePath]
        #     return self

    def set(self, newValue):
        self.attributesDict[ self.recentCheck.get('pathToCheck') ] = newValue
        return self
    
    # matchPattern (string): should look like 'vpc[*].name'
    def expandWith(self, matchPattern, remoteIdentifier='name'):
        matchPatternCombined=matchPattern+'.'+remoteIdentifier
        #listOfMatches = self.fullConfigDict.match(matchPattern)
        if((self.recentCheck.get('pathToCheck') in self.attributesDict)==False):
            # print("expandWith:",self.recentCheck.pathToCheck, "is missing")
            listOfMatches = self.fullConfigDict.match(matchPatternCombined)
            if(len(listOfMatches)==1):
                self.attributesDict[ self.recentCheck.get('pathToCheck') ]=listOfMatches[0]
            else:
                #print(listOfMatches)
                self.appendError(msg="Can't expand attribute "+self.recentCheck.get('pathToCheck')+", resource to infer from: " + matchPatternCombined + ") not unique, found: " + ','.join(listOfMatches))
        return self

    # matchPattern (string): should look like 'vpc[*].name'
    def expandWithSub(self, matchObject, remoteIdentifier, remoteValue, listName, listIdentifier):
        if((self.recentCheck.get('pathToCheck') in self.attributesDict)==False):
            itemFound=False
            if matchObject in self.fullConfigDict:
                objectFound=True
                for o in self.fullConfigDict[matchObject]:
                    if remoteIdentifier in o and o[remoteIdentifier]==remoteValue:
                        objectFound=True
                        if listName in o:
                            if len(o[listName]) == 1:
                                if listIdentifier in o[listName][0]:
                                    self.attributesDict[ self.recentCheck.get('pathToCheck') ]=o[listName][0][listIdentifier]
                                else:
                                    self.appendError(msg="Cannot expand, list identifier {}.{}.{} not found. Found: {}".format(matchObject,listName,listIdentifier,o[listName]))
                            else:
                                self.appendError(msg="More than 1 entry found in list {}.{}".format(matchObject,listName))
                        else:
                            self.appendError(msg="No attribute {} found in matching object {}".format(listName,o))
                if not objectFound:
                    self.appendError(msg="No matching item found for object {} with {}={} ".format(matchObject,remoteIdentifier,remoteValue))
            else:
                self.appendError(msg="No object of type {} found".format(matchObject))
        return self

    def do(self):
        return self
    def appendError(self, type='error', path=None, msg=None):
        if(path==None):
            path=self.recentCheck.get('pathToCheck')
        self.errors.append({'type':type, 'path':path, 'message': msg})
    def getFullConfig(self):
        return self.fullConfigDict
    def getExpandedAttributes(self):
        return self.attributesDict
    def getErrors(self):
        return self.errors
    def getErrorsAsString(self):        
        return self.errors
    def getModuleVariables(self):
        return self.moduleVariables