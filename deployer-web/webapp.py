from flask import Flask, send_from_directory,request
import sys
import json
import subprocess
import os
import yaml
from shutil import copyfile
from pathlib import Path


app = Flask(__name__,static_url_path='', static_folder='ww')

source = os.getcwd()
#parent = source
parent = os.path.dirname(source)
cp4d_config_path = os.path.join(parent,'sample-configurations/web-ui-base-config/cloud-pak')
ocp_config_path = os.path.join(parent,'sample-configurations/web-ui-base-config/ocp')
inventory_config_path = os.path.join(parent,'sample-configurations/web-ui-base-config/inventory')
config_dir=str(os.getenv('CONFIG_DIR'))
status_dir=str(os.getenv('STATUS_DIR'))
target_config=config_dir+'/config'
target_inventory=config_dir+'/inventory'

Path( status_dir+'/log' ).mkdir( parents=True, exist_ok=True )
Path( target_config ).mkdir( parents=True, exist_ok=True )
Path( target_inventory ).mkdir( parents=True, exist_ok=True )

@app.route('/')
def index():
    return send_from_directory(app.static_folder,'index.html')


@app.route('/api/v1/deploy',methods=["POST"])
def deploy():
    body = json.loads(request.get_data())
    print(body, file=sys.stderr)
    env ={}
    if body['cloud']=='ibm-cloud':
      env = {'IBM_CLOUD_API_KEY': body['env']['ibmCloudAPIKey'],
             'CP_ENTITLEMENT_KEY': body['env']['entilementKey'],
             'CONFIG_DIR':config_dir,
             'STATUS_DIR':status_dir}

      log = open('/tmp/cp-deploy.log', 'a')
      process = subprocess.Popen([parent+'/cp-deploy.sh', 'env', 'apply','-e', 'env_id={}'.
                        format(body['envId']), '-e', 'ibm_cloud_region={}'.format(body['region'])], 
                    stdout=log,
                    stderr=log,
                    universal_newlines=True,
                    env=env)

    #   process = subprocess.Popen([parent+'/cp-deploy.sh', 'env', 'apply','-e', 'env_id={}'.
    #                     format(body['envId']), '-e', 'ibm_cloud_region={}'.format(body['region']), '--check-only'], 
    #                 stdout=subprocess.PIPE,
    #                 universal_newlines=True,
    #                 env=env)

    return 'runing'

@app.route('/api/v1/cartridges/<cloudpak>',methods=["GET"])
def getCartridges(cloudpak):
    cartridges_list=[]
    with open(cp4d_config_path+'/{}.yaml'.format(cloudpak),encoding='UTF-8') as f:
        read_all = f.read()
        docs =yaml.load_all(read_all, Loader=yaml.FullLoader)
        for doc in docs:
            if cloudpak in doc.keys():
               cartridges_list = doc[cloudpak][0]['cartridges']
               break
    return json.dumps(cartridges_list)

@app.route('/api/v1/logs',methods=["GET"])
def getLogs():
    result={}
    result["logs"]='waiting'
    log_path=status_dir+'/log/cloud-pak-deployer.log'
    print(log_path)
    if os.path.exists(log_path):
        result["logs"]=open(log_path,"r").read()
    return json.dumps(result)

@app.route('/api/v1/region/<cloud>',methods=["GET"])
def getRegion(cloud):
   ressult={}
   with open(inventory_config_path+'/{}.inv'.format(cloud),'r') as f:
       lines = f.readlines()
       for line in lines:
         if 'ibm_cloud_region' in line:
             ressult['region'] = line.split('=')[1].replace('\n','')
             break
   return json.dumps(ressult)

def update_region(path, region):
    lines=[]
    with open(path, 'r') as f1:
       lines = f1.readlines()
       for line in lines:
         if 'ibm_cloud_region' in line:
             line = f'ibm_cloud_region={region}'
             break
    with open(path, 'w') as w:
         w.writelines(lines)    

def update_storage(path, storage):
    content = ""
    with open(path, 'r') as f1:
        read_all = f1.read()

        datas = yaml.safe_load_all(read_all)
        for data in datas:
            content=content+"---\n"
            if 'openshift' in data.keys():
                   data['openshift'][0]['openshift_storage']=storage
            content=content+yaml.safe_dump(data)
    with open(path, 'w') as f:
        f.write(content)

@app.route('/api/v1/storages/<cloud>',methods=["GET"])
def getStorages(cloud):
   ocp_config=""
   with open(ocp_config_path+'/{}.yaml'.format(cloud), encoding='UTF-8') as f:
    read_all = f.read()

    datas = yaml.load_all(read_all, Loader=yaml.FullLoader)
    for data in datas:
      if 'openshift' in data.keys():
        ocp_config = data['openshift'][0]['openshift_storage']
        break
   return json.dumps(ocp_config)

def update_cartridges(path,cartridges, storage, cloudpak):
    content=""
    with open(path, 'r') as f1:
        content = f1.read()
        docs=yaml.safe_load_all(content)
        for doc in docs:
            if cloudpak in doc.keys():
                doc[cloudpak][0]['cartridges']=cartridges
                doc[cloudpak][0]['openshift_storage_name']=storage
                content=yaml.safe_dump(doc)
                content = '---\n'+content
                break
    with open(path, 'w') as f1:
        f1.write(content)


@app.route('/api/v1/loadConfig',methods=["POST"])
def loadConfig():
    body = json.loads(request.get_data())
    env_id=body['envId']
    cloud=body['cloud']
    cartridges=body['cartridges']
    storages=body['storages']

    source_cp4d_config_path = cp4d_config_path+'/cp4d.yaml'
    generated_cp4d_yaml_path = target_config+'/{}-cp4d.yaml'.format(env_id)
    copyfile(source_cp4d_config_path,generated_cp4d_yaml_path)
    update_cartridges(generated_cp4d_yaml_path,cartridges,storages[0]['storage_name'],'cp4d')

    source_ocp_config_path = ocp_config_path+'/{}.yaml'.format(cloud)
    generated_ocp_yaml_path = target_config+'/{}-ocp.yaml'.format(env_id)
    copyfile(source_ocp_config_path,generated_ocp_yaml_path)
    update_storage(generated_ocp_yaml_path,storages)
    
    source_inventory_config_path=inventory_config_path+'/{}.inv'.format(cloud)
    generated_inventory_yaml_path = target_inventory+'/{}.inv'.format(env_id)
    copyfile(source_inventory_config_path,generated_inventory_yaml_path)
    update_region(generated_inventory_yaml_path,storages[0]['storage_type'])

    result={}
    result["cp4d"]=open(generated_cp4d_yaml_path,"r").read()
    result["envId"]=open(generated_ocp_yaml_path, "r").read()
    return json.dumps(result)
            
        
    
if __name__ == '__main__':
    app.run(host='0.0.0.0', port='32080', debug=False)    