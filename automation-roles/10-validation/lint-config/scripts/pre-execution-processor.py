import argparse
import os
import base64, json, yaml
import sys

parser = argparse.ArgumentParser()
parser.add_argument('--key', '-k', help="Generator key inside the config, somehow identical to the generator name")
parser.add_argument('--attributes', '-a', help="attributes for this generator instance", type= str, required=False)
parser.add_argument('--full', '-f', help="merged all_config object containing config for each an every generator instance", type= str, required=False)
parser.add_argument('--generatorpath', '-p', help="absolute path to the generator directory", type= str, required=True)
parser.add_argument('--output', '-o', help="output file", type= str)
parser.add_argument('--script', '-s', help="filename of the preprocess-script", type= str)
parser.add_argument('--index', '-i', help="index of the element inside the generator array", type=int)
parser.add_argument('--vars', '-v', help="module variables", type= str, required=False)
args = parser.parse_args()

# Support both command-line arguments and environment variables to avoid "Argument list too long" errors
attributes_b64 = os.environ.get('GENERATOR_ATTRIBUTES') or args.attributes
full_config_b64 = os.environ.get('GENERATOR_FULL_CONFIG') or args.full
variables_b64 = os.environ.get('GENERATOR_VARIABLES') or args.vars

if not attributes_b64:
    raise ValueError("Generator attributes must be provided via -a argument or GENERATOR_ATTRIBUTES environment variable")
if not full_config_b64:
    raise ValueError("Full configuration must be provided via -f argument or GENERATOR_FULL_CONFIG environment variable")
if not variables_b64:
    raise ValueError("Module variables must be provided via -v argument or GENERATOR_VARIABLES environment variable")

generatorAttributes = yaml.load(base64.b64decode(attributes_b64), Loader=yaml.FullLoader)
generatorFullConfig = yaml.load(base64.b64decode(full_config_b64), Loader=yaml.FullLoader)
generatorVariables = yaml.load(base64.b64decode(variables_b64), Loader=yaml.FullLoader)



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