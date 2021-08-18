import argparse
#import importlib.util
import base64, json, yaml
import sys

parser = argparse.ArgumentParser()
parser.add_argument('--attributes', '-a', help="attributes for this generator instance", type= str, required=True)
parser.add_argument('--full', '-f', help="merged all_config object containing config for each an every generator instance", type= str, required=True)
parser.add_argument('--generatorpath', '-p', help="absolute path to the generator directory", type= str, required=True)
parser.add_argument('--script', '-s', help="filename of the preprocess-script", type= str, required=True)
args = parser.parse_args()

generatorAttributes = yaml.load(base64.b64decode(args.attributes), Loader=yaml.FullLoader)
generatorFullConfig = yaml.load(base64.b64decode(args.full), Loader=yaml.FullLoader)

# add the generators directory to the path 
# to load definitions from the preprocessor-file
sys.path.append(args.generatorpath)
from preprocessor import preprocessor

# result should contain
# attributes_updated
# validation.infos
# validation.warnings
# validation.errors
result = preprocessor(attributes=generatorAttributes, full_config=generatorFullConfig)



print('--- preprocessor result ---')
print(result)
#spec = importlib.util.spec_from_file_location("preprocessor", args.generatorpath+'/'+args.script)
#preprocessor = importlib.util.module_from_spec(spec)
#spec.loader.exec_module(preprocessor)
#main('test')

print(json.dumps({
        'input': {
            'path_to_preprocessor':args.generatorpath,
            'attributes': generatorAttributes,
            'full_config': generatorFullConfig
        },
        'output': {
            'attributes_updated': result.get('attributes_updated')
        }

    }, indent=4, separators=(',', ': '), sort_keys=True))