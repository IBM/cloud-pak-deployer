from flask import Flask, send_from_directory,request,make_response,send_file
import sys, psutil, subprocess, os
import json, yaml, re
from shutil import copyfile
from pathlib import Path
import glob, zipfile
from logging.config import dictConfig

# Configure the logging
dictConfig(
    {
        "version": 1,
        "formatters": {
            "default": {
                "format": "[%(asctime)s] %(levelname)s in %(module)s: %(message)s",
            }
        },
        "handlers": {
            "console": {
                "class": "logging.StreamHandler",
                "stream": "ext://sys.stdout",
                "formatter": "default",
            }
        },
        "root": {"level": "DEBUG", "handlers": ["console"]},
    }
)

app = Flask(__name__,static_url_path='')

parent = Path(os.path.dirname(os.path.realpath(__file__))).parent
app.logger.info('Parent path of python script: {}'.format(parent))
cp_base_config_path = os.path.join(parent,'sample-configurations/sample-dynamic/config-samples')
ocp_base_config_path = os.path.join(parent,'ample-configurations/sample-dynamic/config-samples')
config_dir=str(os.getenv('CONFIG_DIR'))
status_dir=str(os.getenv('STATUS_DIR'))

Path( status_dir+'/log' ).mkdir( parents=True, exist_ok=True )
Path( config_dir+'/config' ).mkdir( parents=True, exist_ok=True )

# Global variable set in /v1/configuration
generated_config_yaml_path = ""

@app.route('/')
def index():
    return send_from_directory(app.static_folder,'index.html')

@app.route('/api/v1/mirror',methods=["POST"])
def mirror():
    body = json.loads(request.get_data())  
    if 'envId' not in body or 'entitlementKey' not in body or 'registry' not in body:
        return make_response('Bad Request', 400)

    print(body['registry']['portable'])
    print(body['registry']['registryHostname'])
    print(body['registry']['registryPort'])
    print(body['registry']['registryNS'])
    print(body['registry']['registryUser'])
    print(body['registry']['registryPassword'])

    deployer_env = os.environ.copy()
    # Assemble the mirror command
    deploy_command=['/cloud-pak-deployer/cp-deploy.sh']
    deploy_command+=['env','download']
    deploy_command+=['-e=env_id={}'.format(body['envId'])]
    deploy_command+=['-e=ibm_cp_entitlement_key={}'.format(body['entitlementKey'])]

    deploy_command+=['-v']
    
    process = subprocess.Popen(deploy_command, 
                    universal_newlines=True,
                    env=deployer_env)

    return 'running'

@app.route('/api/v1/deploy',methods=["POST"])
def deploy():
    body = json.loads(request.get_data())
    with open(generated_config_yaml_path, 'r', encoding='UTF-8') as f:
        content = f.read()
        docs=yaml.load_all(content, Loader=yaml.FullLoader)
        f.close()
        for doc in docs:
            if 'global_config' in doc.keys():
                global_env_id=doc['global_config']['env_id']
            if 'openshift' in doc.keys():
                openshift_name=doc['openshift'][0]['name'].replace('{{ env_id }}',global_env_id)
            if 'cp4d' in doc.keys():
                cp4d_project=doc['cp4d'][0]['project'].replace('{{ env_id }}',global_env_id)
    deployer_env = os.environ.copy()
    if body['cloud']=='ibm-cloud':
      deployer_env['IBM_CLOUD_API_KEY']=body['env']['ibmCloudAPIKey']
    deployer_env['CP_ENTITLEMENT_KEY']=body['entitlementKey']
    deployer_env['CONFIG_DIR']=config_dir
    deployer_env['STATUS_DIR']=status_dir
    cp4d_admin_password=''
    if 'adminPassword' in body and body['adminPassword']!='':
        cp4d_admin_password=body['adminPassword']
    
    app.logger.info('openshift name: {}'.format(openshift_name))
    app.logger.info('oc login command: {}'.format(body['oc_login_command']))

    # Assemble the deploy command
    deploy_command=['/cloud-pak-deployer/cp-deploy.sh']
    deploy_command+=['env','apply']
    deploy_command+=['-e=env_id={}'.format(body['envId'])]
    deploy_command+=['-vs={}-oc-login={}'.format(openshift_name, body['oc_login_command'])]
    if cp4d_admin_password!='':
        deploy_command+=['-vs=cp4d_admin_{}_{}={}'.format(cp4d_project.replace('-','_'), openshift_name.replace('-','_'), cp4d_admin_password)]
    deploy_command+=['-v']
    app.logger.info('deploy command: {}'.format(deploy_command))

    process = subprocess.Popen(deploy_command, 
                    universal_newlines=True,
                    env=deployer_env)

    return 'running'

@app.route('/api/v1/download-log',methods=["POST"])
def downloadLog ():
    body = json.loads(request.get_data())
    print(body, file=sys.stderr)

    if 'deployerLog' not in body :
       return make_response('Bad Request', 400)

    deployerLog=body['deployerLog']

    if deployerLog != "deployer-log" and deployerLog != "all-logs":
       return make_response('Bad Request', 400)   

    if deployerLog == "deployer-log":
        log_path = status_dir + '/log/cloud-pak-deployer.log'
        return send_file(log_path, as_attachment=True)
    
    if deployerLog == "all-logs":
        log_zip = '/tmp/logs.zip'

        log_folder_path = status_dir + '/log/'
        log_zip_file=zipfile.ZipFile(log_zip, 'w')
        for f in os.listdir(log_folder_path):
            log_zip_file.write(os.path.join(log_folder_path, f), f, zipfile.ZIP_DEFLATED)
        log_zip_file.close()

        return send_file(log_zip, as_attachment=True)


@app.route('/api/v1/oc-login',methods=["POST"])
def oc_login():
    result = {
        "code":-1,
        "error":"",
    }
    body = json.loads(request.get_data())
    #print(body, file=sys.stderr)
    env = {}
    oc_login_command=body['oc_login_command']
    oc_login_command = oc_login_command.strip()

    app.logger.info(body)

    pattern = r'oc(\s+)login(\s)(.*)'    
    isOcLoginCmd = re.match(pattern, oc_login_command)    

    if isOcLoginCmd:
        proc = subprocess.Popen(oc_login_command, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
        proc.stdin.write(b"n\n")
        outputlog, errorlog = proc.communicate()   

        if  proc.returncode == 0: 
            result["code"]=proc.returncode
        else:
            errors = str(errorlog,  'utf-8').split("\n")  
            result={"code": proc.returncode,"error": errors[-2]}
            app.logger.info(result)
            app.logger.info(errors)
        proc.stdin.close()

        return json.dumps(result)
    else:
        return make_response('Bad Request', 400) 

@app.route('/api/v1/deployer-status',methods=["GET"])
def get_deployer_status():
    result = {}

    # Check if the env apply process is active
    result['deployer_active']=False
    # for proc in psutil.process_iter():
    #     # app.logger.info(proc.cmdline())
    #     if '/cloud-pak-deployer/cp-deploy.sh' in proc.cmdline() and \
    #         'env' in proc.cmdline() and ('apply' in proc.cmdline() or 'download' in proc.cmdline()):
    #         result['deployer_active']=True
    # deploy_state_log_path = status_dir + '/state/deployer-state.out'

    # # app.logger.info('Retrieving state from {}'.format(deploy_state_log_path))
    # try:
    #     with open(deploy_state_log_path, "r", encoding='UTF-8') as f:
    #         temp={}
    #     with open(deploy_state_log_path, "r", encoding='UTF-8') as f:
    #         temp={}
    #         content = f.read()
    #         f.close()
    #         # app.logger.info(content)
    #         docs=yaml.safe_load_all(content)
    #         for doc in docs:
    #             temp={**temp, **doc}
    #         if 'deployer_stage' in temp:
    #             result['deployer_stage']=temp['deployer_stage']
    #         if 'last_step' in temp:
    #             result['last_step']=temp['last_step']
    #         if 'percentage_completed' in temp:
    #             result['percentage_completed']=temp['percentage_completed']
    #         if 'completion_state' in temp:
    #             result['completion_state']=temp['completion_state']
    #         if 'mirror_current_image' in temp:
    #             result['mirror_current_image']=temp['mirror_current_image']
    #         if 'mirror_number_images' in temp:
    #             result['mirror_number_images']=temp['mirror_number_images']
    #         if 'service_state' in temp:
    #             result['service_state']=temp['service_state']
    # except FileNotFoundError:
    #     app.logger.warning('Error while reading file {}'.format(deploy_state_log_path))
    # except PermissionError:
    #     app.logger.warning('Permission error while reading file {}'.format(deploy_state_log_path))
    # except IOError:
    #     app.logger.warning('IO Error while reading file {}'.format(deploy_state_log_path))
    # except:
    #     app.logger.warning('internal server error')
    return result

@app.route('/api/v1/configuration',methods=["GET"])
def check_configuration():
    result = {
        "code":-1,
        "message":"",
        "data":{},
    }

    global generated_config_yaml_path

    found_config_files=glob.glob(config_dir+'/config/*.yaml')
    if len(found_config_files) == 0:
        generated_config_yaml_path = config_dir+'/config/cpd-config.yaml'
    elif len(found_config_files) > 1:
        errmsg="More than 1 yaml file found in directory {}. Wizard can be used for 0 or 1 config files.".format(config_dir+'/config')
        app.logger.error(errmsg)
        result['code'] = 400
        result['message'] = errmsg
        return result
    else:
        generated_config_yaml_path = found_config_files[0]

    app.logger.info('Config file that will be updated is {}'.format(generated_config_yaml_path))
    try:
        with open(generated_config_yaml_path, "r", encoding='UTF-8') as f:
            temp={}
            content = f.read()
            docs=yaml.safe_load_all(content)
            for doc in docs:
                temp={**temp, **doc}

            if 'openshift' in temp:
                result['data']['openshift']=temp['openshift']
                del temp['openshift']
            else:
                app.logger.info("Loading base openshift data from {}".format(cp_base_config_path+'/ocp-existing-ocp-auto.yaml'))
                result['data']['openshift']=loadYamlFile(cp_base_config_path+'/ocp-existing-ocp-auto.yaml')['openshift']

            if 'global_config' in temp:
                result['data']['global_config']=temp['global_config']
                del temp['global_config']
            else:
                app.logger.info("Loading base global_config data from {}".format(cp_base_config_path+'/ocp-existing-ocp-auto.yaml'))
                result['data']['global_config']=loadYamlFile(cp_base_config_path+'/ocp-existing-ocp-auto.yaml')['global_config']

            if 'cp4d' in temp:
                result['data']['cp4d']=temp['cp4d']
                del temp['cp4d']
            else:
                app.logger.info("Loading base cp4d data from {}".format(cp_base_config_path+'/cp4d-latest.yaml'))
                result['data']['cp4d']=loadYamlFile(cp_base_config_path+'/cp4d-latest.yaml')['cp4d']

            if 'cp4i' in temp:
                result['data']['cp4i']=temp['cp4i']
                del temp['cp4i']
            else:
                app.logger.info("Loading base cp4i data from {}".format(cp_base_config_path+'/cp4i-latest.yaml'))
                result['data']['cp4i']=loadYamlFile(cp_base_config_path+'/cp4i-latest.yaml')['cp4i']

            if 'env_id' not in result['data']['global_config']:
                result['data']['global_config']['env_id']='demo'
                app.logger.warning("Added env_id to global_config: {}".format(result['data']['global_config']))

            result['code'] = 0
            result['message'] = "Successfully retrieved configuration."
            f.close()
            app.logger.info('Result of reading file: {}'.format(result))
    except FileNotFoundError:
        result['code'] = 404
        result['message'] = "Configuration File is not found."
        app.logger.warning('Error while reading file {}'.format(generated_config_yaml_path))
    except PermissionError:
        result['code'] = 401
        result['message'] = "Permission Error."
    except IOError:
        result['code'] = 101
        result['message'] = "IO Error."
    return result

# @app.route('/api/v1/cartridges/<cloudpak>',methods=["GET"])
# def getCartridges(cloudpak):
#     if cloudpak not in ['cp4d', 'cp4i']:
#        return make_response('Bad Request', 400)
#     return loadYamlFile(cp_base_config_path+'/{}.yaml'.format(cloudpak))

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

@app.route('/api/v1/storages/<cloud>',methods=["GET"])
def getStorages(cloud):
    ocp_config=""
    with open(ocp_base_config_path+'/{}.yaml'.format(cloud), encoding='UTF-8') as f:
        read_all = f.read()

    datas = yaml.load_all(read_all, Loader=yaml.FullLoader)
    for data in datas:
        if 'openshift' in data.keys():
            ocp_config = data['openshift'][0]['openshift_storage']
            break
    return json.dumps(ocp_config)

def loadYamlFile(path):
    result={}
    content=""
    try:
        with open(path, 'r', encoding='UTF-8') as f1:
            content=f1.read()
            docs=yaml.safe_load_all(content)
            for doc in docs:
                result={**result, **doc}
    except:
        app.logger.error('Error while reading file {}'.format(path))
        raise Exception('Error while reading file {}'.format(path))
    return result

def mergeSaveConfig(ocp_config, cp4d_config, cp4i_config):
    global generated_config_yaml_path

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
    if 'envId' not in body or 'cloud' not in body or 'cp4d' not in body or 'cp4i' not in body or 'storages' not in body or 'cp4dVersion' not in body or 'cp4iVersion' not in body or 'cp4dLicense' not in body or 'cp4iLicense' not in body or 'CP4DPlatform' not in body or 'CP4IPlatform' not in body:
       return make_response('Bad Request', 400)

    env_id=body['envId']
    cloud=body['cloud']
    region=body['region']
    cp4d=body['cp4d']
    cp4i=body['cp4i']
    storages=body['storages']
    cp4dLicense=body['cp4dLicense']
    cp4iLicense=body['cp4iLicense']
    cp4dVersion=body['cp4dVersion']
    cp4iVersion=body['cp4iVersion']
    CP4DPlatform=body['CP4DPlatform']
    CP4IPlatform=body['CP4IPlatform']
    
    # Load the base yaml files
    ocp_config=loadYamlFile(ocp_base_config_path+'/{}.yaml'.format(cloud))
    cp4d_config=loadYamlFile(cp_base_config_path+'/cp4d.yaml')
    cp4i_config=loadYamlFile(cp_base_config_path+'/cp4i.yaml')

    # Update for EnvId
    ocp_config['global_config']['env_id']=env_id

    # Update for cp4d
    cp4d_selected=CP4DPlatform
    if cp4d_selected:
        cp4d_config['cp4d'][0]['cartridges']=cp4d
        cp4d_config['cp4d'][0]['accept_licenses']=cp4dLicense
        cp4d_config['cp4d'][0]['cp4d_version']=cp4dVersion
    else:
        cp4d_config={}
    # Update for cp4i
    cp4i_selected=CP4IPlatform
    if cp4i_selected:
        cp4i_config['cp4i'][0]['instances']=cp4i
        cp4i_config['cp4i'][0]['accept_licenses']=cp4iLicense
        cp4i_config['cp4i'][0]['cp4i_version']=cp4iVersion
    else:
        cp4i_config={}

    return mergeSaveConfig(ocp_config, cp4d_config, cp4i_config)

@app.route('/api/v1/updateConfig',methods=["PUT"])
def updateConfig():
    global generated_config_yaml_path

    body = json.loads(request.get_data())
    if 'cp4d' not in body or 'cp4i' not in body or 'cp4dVersion' not in body or 'cp4iVersion' not in body or 'cp4dLicense' not in body or 'cp4iLicense' not in body or 'CP4DPlatform' not in body or 'CP4IPlatform' not in body:
       return make_response('Bad Request', 400)

    app.logger.info("Configuration received by updateConfig {}".format(body))

    cp4d_cartridges=body['cp4d']
    cp4i_instances=body['cp4i']
    cp4dLicense=body['cp4dLicense']
    cp4iLicense=body['cp4iLicense']
    cp4dVersion=body['cp4dVersion']
    cp4iVersion=body['cp4iVersion']
    CP4DPlatform=body['CP4DPlatform']
    CP4IPlatform=body['CP4IPlatform']

    with open(generated_config_yaml_path, 'r', encoding='UTF-8') as f1:
        temp={}
        cp4d_config={}
        cp4i_config={}
        ocp_config={}
        content = f1.read()
        f1.close()
        docs=yaml.safe_load_all(content)
        for doc in docs:
            temp={**temp, **doc}

        # app.logger.info("temp: {}".format(temp))
        cp4d_selected=CP4DPlatform
        if cp4d_selected:
            cp4d_config['cp4d']=temp['cp4d']
            cp4d_config['cp4d'][0]['cartridges']=cp4d_cartridges
            cp4d_config['cp4d'][0]['accept_licenses']=cp4dLicense
            cp4d_config['cp4d'][0]['cp4d_version']=cp4dVersion
        del temp['cp4d']

        cp4i_selected=CP4IPlatform
        if cp4i_selected:
            cp4i_config['cp4i']=temp['cp4i']
            cp4i_config['cp4i'][0]['instances']=cp4i_instances
            cp4i_config['cp4i'][0]['accept_licenses']=cp4iLicense
            cp4i_config['cp4i'][0]['cp4i_version']=cp4iVersion
        del temp['cp4i']
        
        ocp_config=temp
        if 'env_id' not in ocp_config['global_config']:
            ocp_config['global_config']['env_id']='demo'
        
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
    
    if 'cp4d' in config_data:
        cp4d_config['cp4d']=config_data['cp4d']
        del config_data['cp4d']
    if 'cp4i' in config_data:
        cp4i_config['cp4i']=config_data['cp4i']
        del config_data['cp4i']
    ocp_config=config_data

    return mergeSaveConfig(ocp_config, cp4d_config, cp4i_config)

@app.route('/api/v1/environment-variable',methods=["GET"])
def environmentVariable():
    result={}

    if 'CPD_WIZARD_PAGE_TITLE' in os.environ:
      result['CPD_WIZARD_PAGE_TITLE']=os.environ['CPD_WIZARD_PAGE_TITLE']
    else:
      result['CPD_WIZARD_PAGE_TITLE']="Cloud Pak Deployer"

    if 'CPD_WIZARD_MODE' in os.environ:
      result['CPD_WIZARD_MODE']=os.environ['CPD_WIZARD_MODE']
    else:
      result['CPD_WIZARD_MODE']=""

    if 'STATUS_DIR' in os.environ:
      result['STATUS_DIR']=os.environ['STATUS_DIR']
    else:
      result['STATUS_DIR']=""

    if 'CONFIG_DIR' in os.environ:
      result['CONFIG_DIR']=os.environ['CONFIG_DIR']
    else:
      result['CONFIG_DIR']=""
    
    return result

import logging
log = logging.getLogger('werkzeug')
log.setLevel(logging.ERROR)

if __name__ == '__main__':
    print("""
IBM Cloud Pak Deployer Wizard is started.
Please access the below URL for the web console:
******************************************************************************
Summary
 * Web console HTTPS URL:
   https://<host machine>:8080  
******************************************************************************
    """)
    app.run(host='0.0.0.0', port='32080', debug=True)    