'''Custom ansible filters for dicts'''

import copy
class FilterModule(object):

    def filters(self):
        return {
            'drop_keys': self.drop_keys
        }

    def drop_keys(self, dict_to_reduce, list_of_keys):
        '''Deletes items of dict by list of keys provided'''
        dict_to_return = copy.deepcopy(dict_to_reduce)
        for item in list_of_keys:
            if item in dict_to_return:
                del dict_to_return[item]
        return dict_to_return