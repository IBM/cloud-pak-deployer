import argparse
import os
import base64, json, yaml
import sys

parser = argparse.ArgumentParser()
parser.add_argument('--key', '-k', help="Generator key inside the config, somehow identical to the generator name")
parser.add_argument('--attributes', '-a', help="attributes for this generator instance", type= str, required=True)
parser.add_argument('--full', '-f', help="merged all_config object containing config for each an every generator instance", type= str, required=True)
parser.add_argument('--generatorpath', '-p', help="absolute path to the generator directory", type= str, required=True)
parser.add_argument('--output', '-o', help="output file", type= str)
parser.add_argument('--script', '-s', help="filename of the preprocess-script", type= str)
parser.add_argument('--index', '-i', help="index of the element inside the generator array", type=int)
parser.add_argument('--vars', '-v', help="module variables", type= str, required=True)
args = parser.parse_args()

generatorAttributes = yaml.load(base64.b64decode(args.attributes), Loader=yaml.FullLoader)
generatorFullConfig = yaml.load(base64.b64decode(args.full), Loader=yaml.FullLoader)
generatorVariables = yaml.load(base64.b64decode(args.vars), Loader=yaml.FullLoader)



# add the generators directory to the path 
# to load definitions from the preprocessor-file
sys.path.append(os.getcwd())
sys.path.append(args.generatorpath)

from preprocessor import preprocessor

# result should contain
# attributes_updated: <dict>
# errors: []

result = preprocessor(attributes=generatorAttributes, fullConfig=generatorFullConfig, moduleVariables=generatorVariables)


generatorFullConfig[args.key][args.index] = result.get('attributes_updated')

# print('--- preprocessor result ---')
# print(result)

print(json.dumps({
    'attributes_updated': result.get('attributes_updated'),
    'updated_config': generatorFullConfig,
    'errors': result.get('errors')
    }, indent=4, separators=(',', ': '), sort_keys=True))