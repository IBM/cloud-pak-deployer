from benedict import benedict

class GeneratorPreProcessor:
    def __init__(self,attributes=None, fullConfig=None) -> None:
        self.d = benedict()
        self.recentCheck = {}
        self.attributes = attributes
        # these are the attributes we'll modify 
        # during preprocessing
        self.attributesDict = benedict(attributes) 
        self.fullConfig = fullConfig
        self.fullConfigDict = benedict(fullConfig)
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
            if (type(matchPattern) is str):
                
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
                            self.appendError(msg="{value} is not one of [{remoteValues}]".format(value=localPropertyValue[i],remoteValues=', '.join(listOfMatches) ))
            if (type(matchPattern) is list):
                checkPassed=False
                localPropertyValue =  self.attributesDict[  self.recentCheck.get('pathToCheck') ]
                for i in range(len(matchPattern)):
                    if(localPropertyValue==matchPattern[i]):
                        checkPassed=True
                if checkPassed==False:
                    self.appendError(msg="{value} is not one of [{listValues}]".format(value=localPropertyValue[i],listValues=', '.join(matchPattern) ))

        #print(listOfMatches)
        #print(self.attributesDict[ lookupPath ])
        return self












    def lookupFromProperty(self, localProperty, generatorName, remotePath, identifierProp='name'):
        if((self.recentCheck.get('pathToCheck') in self.attributesDict)==False):
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
                self.appendError(msg="Can't expand, result of given path ("+ matchPatternCombined +") not unique, found:" + ','.join(listOfMatches))
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