from benedict import benedict

class GeneratorPreProcessor:
    def __init__(self,attributes=None, fullConfig=None) -> None:
        self.d = benedict()
        self.attributes = attributes
        # these are the attributes we'll modify 
        # during preprocessing
        self.attributesDict = benedict(attributes) 
        self.fullConfig = fullConfig
        self.fullConfigDict = benedict(fullConfig)
        self.errors = []
    def __call__(self,pathToCheck):
        self.pathToCheck = pathToCheck
        # check, that it actually exists
        return self
    def __eq__(self,other):
        # in normal conditions 'other' will be True/typeof bool
        # self.pathToCheck = pathToCheck
        if(type(other) is bool):
            return (self.pathToCheck in self.attributesDict)
        if(type(other) is (str or int)):
            return self.attributesDict[self.pathToCheck]
    def mustBeDefined(self):
        if((self.pathToCheck in self.attributesDict)==False):
            self.appendError(msg="Attribute {path} is not defined".format(path=self.pathToCheck))
        return self
    def mustBeOneOf(self,matchPattern):
        listOfMatches = self.fullConfigDict.match(matchPattern)
        #print(self.attributesDict[ lookupPath ])
        return self
    def lookupFromProperty(self, localProperty, generatorName, remotePath, identifierProp='name'):
        localPropertyValue =  self.attributesDict[ localProperty ] # first_zone_prefix
        generatorsListOfEntities = self.fullConfigDict.get(generatorName,[])
        for i in range(len(generatorsListOfEntities)):
            if generatorsListOfEntities[i][identifierProp]==localPropertyValue:
                self.attributesDict[ self.pathToCheck ]=generatorsListOfEntities[i][remotePath]
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
        #     self.attributesDict[self.pathToCheck] = generatorsListOfEntities[0][remotePath]
        #     return self
            
    def expandWith(self, matchPattern):
        #listOfMatches = self.fullConfigDict.match(matchPattern)
        if((self.pathToCheck in self.attributesDict)==False):
            # print("expandWith:",self.pathToCheck, "is missing")
            listOfMatches = self.fullConfigDict.match(matchPattern)
            if(len(listOfMatches)==1):
                self.attributesDict[ self.pathToCheck ]=listOfMatches[0]
            else:
                self.appendError(msg="Can't expand, result of given path not unique, found:" + ','.join(listOfMatches))
        return self
    def do(self):
        return self
    def appendError(self, type='error', path=None, msg=None):
        if(path==None):
            path=self.pathToCheck
        self.errors.append({'type':type, 'path':path, 'message': msg})
    def getExpandedAttributes(self):
        return self.attributesDict
    def getErrors(self):
        return self.errors
    def getErrorsAsString(self):
        
        return self.errors