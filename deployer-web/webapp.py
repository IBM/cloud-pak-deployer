from flask import Flask, send_from_directory,request
import json
import subprocess
import os
import yaml
from shutil import copyfile

app = Flask(__name__,static_url_path='', static_folder='ww')

source = os.path.dirname(__file__)
parent = os.path.dirname(source)
cp4d_config_path = os.path.join(parent,'sample-configurations/web-ui-base-config')
ocp_config_path = os.path.join(parent,'sample-configurations/web-ui-base-config')
inventory_config_path = os.path.join(parent,'sample-configurations/web-ui-base-config/inventory')
@app.route('/')
def index():
    return send_from_directory(app.static_folder,'index.html')


@app.route('/api/v1/deploy',methods=["POST"])
def deploy():
    body = json.loads(request.get_data())
    env ={}
    if body['cloud']=='ibm-cloud':
      env = {'IBM_CLOUD_API_KEY': body['env']['ibmCloudAPIKey'],
                                'CP_ENTITLEMENT_KEY': body['env']['entilementKey']}
      process = subprocess.Popen(['cp-deploy.sh', 'env', 'apply','-e env_id={}'.
                               format(body['envId']),'-e ibm_cloud_region={}'.format(body['region']), '--check-only'], 
                           stdout=subprocess.PIPE,
                           universal_newlines=True,
                           env=env)
    return 'runing'

@app.route('/api/v1/loadConifg',methods=["POST"])
def loadConfig():
    body = json.loads(request.get_data())
    env_id=body['envId']
    cloud=body['cloud']
    confg_dir=os.getenv('CONFIG_DIR')
    source_cp4d_config_path = cp4d_config_path+'/cloud-pak/cp4d.yaml'
    generated_cp4d_yaml_path = confg_dir+'/config/{}-cp4d.yaml'.format(env_id)
    copyfile(source_cp4d_config_path,generated_cp4d_yaml_path)
    source_ocp_config_path = cp4d_config_path+'/ocp/{}.yaml'.format(cloud)
    generated_ocp_yaml_path = confg_dir+'/config/{}-ocp.yaml'.format(env_id)
    copyfile(source_ocp_config_path,generated_ocp_yaml_path)
    source_inventory_config_path=cp4d_config_path+'/inventory/{}.inv'.format(cloud)
    generated_inventory_yaml_path = confg_dir+'/inventory/{}.inv'.format(env_id)
    copyfile(source_inventory_config_path,generated_inventory_yaml_path)
   
    result={}
    result["cp4d"]=open(generated_cp4d_yaml_path,"r").read()
    result["envId"]=open(generated_ocp_yaml_path, "r").read()
    return json.dumps(result)
            
        
    
if __name__ == '__main__':
    app.run(host='0.0.0.0', port='32080', debug=False)    