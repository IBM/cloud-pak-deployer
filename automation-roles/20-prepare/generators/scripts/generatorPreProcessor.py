from _typeshed import Self
from benedict import benedict

# could be an alternative
# https://github.com/fabiocaccamo/python-benedict

class GeneratorPreProcessor:
    def __init__(self,attributes=None, fullConfig=None) -> None:
        self.d = benedict()
        self.attributes = attributes
        self.attributesDict = benedict(attributes)
        self.fullConfig = fullConfig
        self.fullConfigDict = benedict(fullConfig)
        self.errors = []
    def __call__(self,pathToCheck):
        self.pathToCheck = pathToCheck
        return self
    def __eq__(self,other):
        # in normal conditions 'other' will be True/typeof bool
        if(type(other) is bool):
            return (self.pathToCheck in self.attributesDict)
        if(type(other) is (str or int)):
            return self.attributesDict[self.pathToCheck]
    def mustBeDefined(self):
        if((self.pathToCheck in self.attributesDict)==False):
            self.__appendError("Attribute {path} is not defined".format(path=self.pathToCheck))
        return self
    def mustBeOneOf(self,matchPattern):
        listOfMatches = self.fullConfigDict.match(matchPattern)
        #print(self.attributesDict[ lookupPath ])
        return self
    def __appendError(self, errorToAdd):
        self.errors.append(errorToAdd)
    def getErrors(self):
        return self.errors