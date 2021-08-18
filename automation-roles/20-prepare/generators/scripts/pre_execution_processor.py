import argparse, json

parser = argparse.ArgumentParser()
parser.add_argument('--attributes', '-a', help="attributes for this generator instance", type= str)
parser.add_argument('--full', '-f', help="merged all_config object containing config for each an every generator instance", type= str)
parser.add_argument('--preprocessor', '-p', help="path to the preprocessor script we want to include", type= str)
args = parser.parse_args()

print(json.dumps({
        'info': args.preprocessor,
    }, indent=4, separators=(',', ': '), sort_keys=True))