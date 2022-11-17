from flask import Flask, send_from_directory,request,make_response
import sys
import json
import subprocess
import os
import yaml
from shutil import copyfile
from pathlib import Path
import re


app = Flask(__name__,static_url_path='', static_folder='ww')

source = os.getcwd()
#parent = source
parent = os.path.dirname(source)
cp4d_config_path = os.path.join(parent,'sample-configurations/web-ui-base-config/cloud-pak')
ocp_config_path = os.path.join(parent,'sample-configurations/web-ui-base-config/ocp')
config_dir=str(os.getenv('CONFIG_DIR'))
status_dir=str(os.getenv('STATUS_DIR'))
target_config=config_dir+'/config'
generated_config_yaml_path = target_config+'/cpd-config.yaml'

Path( status_dir+'/log' ).mkdir( parents=True, exist_ok=True )
Path( target_config ).mkdir( parents=True, exist_ok=True )

@app.route('/')
def index():
    return send_from_directory(app.static_folder,'index.html')

@app.route('/api/v1/deploy',methods=["POST"])
def deploy():
    body = json.loads(request.get_data())
    print(body, file=sys.stderr)
    env ={}
    if body['cloud']=='ibm-cloud':
      env['IBM_CLOUD_API_KEY']=body['env']['ibmCloudAPIKey']
    env['CP_ENTITLEMENT_KEY']=body['entitlementKey']
    env['CONFIG_DIR']=config_dir
    env['STATUS_DIR']=status_dir

    log = open('/tmp/cp-deploy.log', 'a')
    process = subprocess.Popen(['/cloud-pak-deployer/cp-deploy.sh', 'env', 'apply','-e', 'env_id={}'.
                        format(body['envId'])], 
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

@app.route('/api/v1/oc-login',methods=["POST"])
def oc_login():
    body = json.loads(request.get_data())
    print(body, file=sys.stderr)
    env = {}
    oc_login_command=body['oc_login_command']
    oc_login_command = oc_login_command.strip()

    pattern = r'oc(\s+)login(\s)(.*)'    
    isOcLoginCmd = re.match(pattern, oc_login_command)    

    if isOcLoginCmd : 
        result_code=os.system(oc_login_command)
        result={"code": result_code}    
        return json.dumps(result)
    else:
        return make_response('Bad Request', 400)  
    

@app.route('/api/v1/configuration',methods=["GET"])
def check_configuration():
    result = {
        "code":-1,
        "message":"",
        "data":{},
    }
    try:
        with open(target_config+"/cpd-config.yaml", "r", encoding='UTF-8') as f:
            temp={}
            content = f.read()
            docs=yaml.safe_load_all(content)
            for doc in docs:
                temp={**temp, **doc}

            if 'cp4d' in temp:
                result['data']['cp4d']=temp['cp4d']
                del temp['cp4d']
            else:
                result['data']['cp4d']=loadYamlFile(cp4d_config_path+'/cp4d.yaml')['cp4d']

            if 'cp4i' in temp:
                result['data']['cp4i']=temp['cp4i']
                del temp['cp4i']
            else:
                result['data']['cp4i']=loadYamlFile(cp4d_config_path+'/cp4i.yaml')['cp4i']

            result['data']['ocp']=temp

            result['code'] = 0
            result['message'] = "success to get configuration."
            f.close()

    except FileNotFoundError:
        result['code'] = 404
        result['message'] = "Configuration File is not found."
    except PermissionError:
        result['code'] = 401
        result['message'] = "Permission Error."
    except IOError:
        result['code'] = 101
        result['message'] = "IO Error."
    return result

@app.route('/api/v1/cartridges/<cloudpak>',methods=["GET"])
def getCartridges(cloudpak):
    #cp4d
    type_name="cartridges"
    #cp4i
    if cloudpak == "cp4i":
        type_name="instances"    
    cartridges_list=[]
    with open(cp4d_config_path+'/{}.yaml'.format(cloudpak),encoding='UTF-8') as f:
        read_all = f.read()
        docs =yaml.load_all(read_all, Loader=yaml.FullLoader)
        for doc in docs:
            if cloudpak in doc.keys():
               cartridges_list = doc[cloudpak][0][type_name]
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
    newlines=[]
    with open(path, 'r') as f1:
       lines = f1.readlines()
       for line in lines:
          if 'ibm_cloud_region' in line:
            line = f'ibm_cloud_region={region}'
          if 'aws_region' in line:
            line = f'aws_region={region}'
          newlines.append(line)
    with open(path, 'w') as w:
         w.writelines(newlines)    

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

def update_cp4d_cartridges(path, cartridges, storage, cloudpak):
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

def update_cp4i_cartridges(path, cartridges, storage, cloudpak):
    content=""
    with open(path, 'r') as f1:
        content = f1.read()
        docs=yaml.safe_load_all(content)
        for doc in docs:
            if cloudpak in doc.keys():
                doc[cloudpak][0]['instances']=cartridges
                doc[cloudpak][0]['openshift_storage_name']=storage
                content=yaml.safe_dump(doc)
                content = '---\n'+content
                break
    with open(path, 'w') as f1:
        f1.write(content)

def loadYamlFile(path):
    result={}
    content=""
    with open(path, 'r', encoding='UTF-8') as f1:
        content=f1.read()
        docs=yaml.safe_load_all(content)
        for doc in docs:
            result={**result, **doc}
    return result

def mergeSaveConfig(ocp_config, cp4d_config, cp4i_config):
    ocp_yaml=yaml.safe_dump(ocp_config)
    
    all_in_one = '---\n'+ocp_yaml
    if cp4d_config!={}:
        cp4d_yaml=yaml.safe_dump(cp4d_config)
        cp4d_yaml = '\n\n'+cp4d_yaml
        all_in_one = all_in_one + cp4d_yaml
    if cp4i_config!={}:
        cp4i_yaml=yaml.safe_dump(cp4i_config)
        cp4i_yaml = '\n\n'+cp4i_yaml
        all_in_one = all_in_one + cp4i_yaml

    with open(generated_config_yaml_path, 'w', encoding='UTF-8') as f1:
        f1.write(all_in_one)
        f1.close()

    with open(generated_config_yaml_path, "r", encoding='UTF-8') as f1:
        result={}
        result["config"]=f1.read()
        f1.close()
    return json.dumps(result) 

@app.route('/api/v1/createConfig',methods=["POST"])
def createConfig():
    body = json.loads(request.get_data())
    if not body['envId'] or not body['cloud'] or not body['cp4d'] or not body['cp4i'] or not body['storages']:
       return make_response('Bad Request', 400)

    env_id=body['envId']
    cloud=body['cloud']
    region=body['region']
    cp4d=body['cp4d']
    cp4i=body['cp4i']
    storages=body['storages']
    
    #generated_config_yaml_path = target_config+'/cpd-config.yaml'
    # Load the default yaml file
    source_ocp_config_path = ocp_config_path+'/{}.yaml'.format(cloud)
    ocp_config=loadYamlFile(source_ocp_config_path)

    source_cp4d_config_path = cp4d_config_path+'/cp4d.yaml'
    cp4d_config=loadYamlFile(source_cp4d_config_path)

    source_cp4i_config_path = cp4d_config_path+'/cp4i.yaml'
    cp4i_config=loadYamlFile(source_cp4i_config_path)

    # Update for region
    if cloud=="ibm-cloud":
        ocp_config['global_config']['ibm_cloud_region']=region
    elif cloud=="aws":
        ocp_config['global_config']['aws_region']=region

    # Update for EnvId
    ocp_config['global_config']['env_id']=env_id
    # Update for cp4d
    cp4d_selected=False
    for cartridge in cp4d:
        if 'state' in cartridge and cartridge['state']=='installed':
            cp4d_selected=True
    if cp4d_selected:
        cp4d_config['cp4d'][0]['cartridges']=cp4d
    else:
        cp4d_config={}
    # Update for cp4i
    cp4i_selected=False
    for instance in cp4i:
        if 'state' in instance and instance['state']=='installed':
            cp4i_selected=True
    if cp4i_selected:
        cp4i_config['cp4i'][0]['instances']=cp4i
    else:
        cp4i_config={}

    return mergeSaveConfig(ocp_config, cp4d_config, cp4i_config)

@app.route('/api/v1/updateConfig',methods=["PUT"])
def updateConfig():
    body = json.loads(request.get_data())
    if not body['cp4d'] or not body['cp4i']:
       return make_response('Bad Request', 400)

    cp4d=body['cp4d']
    cp4i=body['cp4i']

    #generated_config_yaml_path = target_config+'/cpd-config.yaml'
    with open(generated_config_yaml_path, 'r', encoding='UTF-8') as f1:
        temp={}
        cp4d_config={}
        cp4i_config={}
        ocp_config={}
        content = f1.read()
        docs=yaml.safe_load_all(content)
        for doc in docs:
            temp={**temp, **doc}

        if 'cp4d' in temp:
            cp4d_config['cp4d']=temp['cp4d']
            del temp['cp4d']
        else:
            cp4d_config['cp4d']=loadYamlFile(cp4d_config_path+'/cp4d.yaml')['cp4d']

        if 'cp4i' in temp:
            cp4i_config['cp4i']=temp['cp4i']
            del temp['cp4i']
        else:
            cp4i_config['cp4i']=loadYamlFile(cp4d_config_path+'/cp4i.yaml')['cp4i']
        
        ocp_config=temp
        f1.close()
    
    # Update for cp4d
    cp4d_config['cp4d'][0]['cartridges']=cp4d
    # Update for cp4i
    cp4i_config['cp4i'][0]['instances']=cp4i
    
    return mergeSaveConfig(ocp_config, cp4d_config, cp4i_config)

@app.route('/api/v1/saveConfig',methods=["POST"])
def saveConfig():
    body = json.loads(request.get_data())
    if not body['config']:
       return make_response('Bad Request', 400)

    config_data=body['config']

    cp4d_config={}
    cp4i_config={}
    ocp_config={}
    
    cp4d_config['cp4d']=config_data['cp4d']
    del config_data['cp4d']
    cp4i_config['cp4i']=config_data['cp4i']
    del config_data['cp4i']
    ocp_config=config_data

    return mergeSaveConfig(ocp_config, cp4d_config, cp4i_config)

  
if __name__ == '__main__':
    app.run(host='0.0.0.0', port='32080', debug=False)    