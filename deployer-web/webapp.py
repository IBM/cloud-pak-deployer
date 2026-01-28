from typing import Any
from flask import Flask, send_from_directory,request,make_response,send_file
import sys, psutil, subprocess, os, getpass
import json,yaml, re
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

deployer_dir = Path(os.path.dirname(os.path.realpath(__file__))).parent
app.logger.info('Deployer directory: {}'.format(deployer_dir))
cp_base_config_path = os.path.join(deployer_dir,'sample-configurations/sample-dynamic/config-samples')
ocp_base_config_path = os.path.join(deployer_dir,'sample-configurations/sample-dynamic/config-samples')
running_context=str(os.getenv('CPD_CONTEXT', default='local'))
app.logger.info('Deployer context: {}'.format(running_context))
deployer_project = str(os.getenv('CPD_DEPLOYER_PROJECT', default='cloud-pak-deployer'))
config_dir=str(os.getenv('CONFIG_DIR'))
status_dir=str(os.getenv('STATUS_DIR'))

Path( status_dir+'/log' ).mkdir( parents=True, exist_ok=True )
Path( config_dir+'/config' ).mkdir( parents=True, exist_ok=True )

#
# Root
#

@app.route('/')
def index():
    return send_from_directory(str(app.static_folder),'index.html')

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

#
# Start deployment
#

@app.route('/api/v1/deploy',methods=["POST"])
def deploy():
    body = json.loads(request.get_data())
    deployer_env = os.environ.copy()
    deployer_env['envId'] = body['envId']
    deployer_env['OCP_OC_LOGIN'] = body['oc_login_command']
    deployer_env['CP_ENTITLEMENT_KEY']=body['entitlementKey']
    deployer_env['CONFIG_DIR']=config_dir
    deployer_env['STATUS_DIR']=status_dir
    if 'adminPassword' in body and body['adminPassword']!='':
        deployer_env['adminPassword']=body['adminPassword']

    if (running_context == 'local'):
        result=deploy_local(deployer_env)
    else:
        result=deploy_openshift(deployer_env)

    return result

def deploy_local(deployer_env):
    deploy_command=['cp-deploy.sh','env']
    deploy_command+=['-e=env_id={}'.format(deployer_env['envId'])]
    deploy_command+=['-vs=oc-login={}'.format(deployer_env['OCP_OC_LOGIN'])]
    deploy_command+=['-e=ibm_cp_entitlement_key={}'.format(deployer_env['CP_ENTITLEMENT_KEY'])]
    if 'adminPassword' in deployer_env and deployer_env['adminPassword']!='':
        deploy_command+=['-e=cp4d_admin_password={}'.format(deployer_env['adminPassword'])]
    deploy_command+=['-v']
    app.logger.info('deploy command: {}'.format(deploy_command))

    process = subprocess.Popen(deploy_command, 
                    universal_newlines=True,
                    env=deployer_env)

    return 'running'

def deploy_openshift(deployer_env):

    create_secret_command=['oc','create',f'-n={deployer_project}','secret','generic','cloud-pak-entitlement-key']
    app.logger.info('Create secret command: {}'.format(create_secret_command))

    process = subprocess.Popen(create_secret_command,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    universal_newlines=True)
    
    stdout, stderr = process.communicate()
    
    # Update the config map
    if process.returncode != 0:
        app.logger.info(f"Error creating secret: {stderr}, ignoring")

    update_secret_command=['oc','set','data',f'-n={deployer_project}','secret/cloud-pak-entitlement-key',f'--from-literal=cp-entitlement-key={deployer_env['CP_ENTITLEMENT_KEY']}']
    app.logger.info('Set data for secret command: {}'.format(update_secret_command))

    process = subprocess.Popen(update_secret_command,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    universal_newlines=True)
    
    stdout, stderr = process.communicate()
    
    if process.returncode != 0:
        app.logger.info(f"Error creating secret: {stderr}")        

    deploy_command=['oc','create','-f',f'{deployer_dir}/scripts/deployer/assets/cloud-pak-deployer-start.yaml']
    app.logger.info('deploy command: {}'.format(deploy_command))

    process = subprocess.Popen(deploy_command, 
                    universal_newlines=True,
                    env=deployer_env)

    return 'running'

#
# Download logs
#

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
    
    return make_response('Bad Request', 400)
    
#
# OpenShift login
#

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
        outputlog, errorlog = proc.communicate()   

        if  proc.returncode == 0: 
            result["code"]=proc.returncode
        else:
            errors = str(errorlog,  'utf-8').split("\n")  
            result={"code": proc.returncode,"error": errors[-2]}
            app.logger.info(result)
            app.logger.info(errors)

        return json.dumps(result)
    else:
        return make_response('Bad Request', 400) 

#
# OpenShift connection check
#

@app.route('/api/v1/oc-check-connection',methods=["GET"])
def oc_check_connection():
    result = {
        "connected": False,
        "user": "",
        "server": "",
        "cluster_version": "",
        "kubernetes_version": "",
        "error": ""
    }
    
    app.logger.info("Checking OpenShift connection status")
    
    # Step 1: Check if user is logged in with 'oc whoami'
    try:
        proc = subprocess.Popen(
            'oc whoami',
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            shell=True
        )
        stdout, stderr = proc.communicate()
        
        if proc.returncode == 0:
            result["user"] = str(stdout, 'utf-8').strip()
            app.logger.info(f"Connected as user: {result['user']}")
        else:
            error_msg = str(stderr, 'utf-8').strip()
            result["error"] = "Not logged in to OpenShift cluster"
            app.logger.info(f"Not connected: {error_msg}")
            return json.dumps(result)
            
    except Exception as e:
        result["error"] = f"Error checking connection: {str(e)}"
        app.logger.error(f"Exception during oc whoami: {str(e)}")
        return json.dumps(result)
    
    # Step 2: Get server URL with 'oc whoami --show-server'
    try:
        proc = subprocess.Popen(
            'oc whoami --show-server',
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            shell=True
        )
        stdout, stderr = proc.communicate()
        
        if proc.returncode == 0:
            result["server"] = str(stdout, 'utf-8').strip()
            app.logger.info(f"Server URL: {result['server']}")
        else:
            app.logger.warning("Could not retrieve server URL")
            
    except Exception as e:
        app.logger.error(f"Exception during oc whoami --show-server: {str(e)}")
    
    # Step 3: Get version info with 'oc version -o json'
    try:
        proc = subprocess.Popen(
            'oc version -o json',
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            shell=True
        )
        stdout, stderr = proc.communicate()
        
        if proc.returncode == 0:
            version_data = json.loads(str(stdout, 'utf-8'))
            
            # Extract OpenShift version
            if 'openshiftVersion' in version_data:
                result["cluster_version"] = version_data['openshiftVersion']
            
            # Extract Kubernetes version from server version
            if 'serverVersion' in version_data and 'gitVersion' in version_data['serverVersion']:
                result["kubernetes_version"] = version_data['serverVersion']['gitVersion']
            
            app.logger.info(f"Cluster version: {result['cluster_version']}, Kubernetes version: {result['kubernetes_version']}")
        else:
            app.logger.warning("Could not retrieve version information")
            
    except json.JSONDecodeError as e:
        app.logger.error(f"Error parsing version JSON: {str(e)}")
    except Exception as e:
        app.logger.error(f"Exception during oc version: {str(e)}")
    
    # If we got this far, we're connected
    result["connected"] = True
    app.logger.info("OpenShift connection check completed successfully")
    
    return json.dumps(result)

#
# Deployer status
#

@app.route('/api/v1/deployer-status',methods=["GET"])
def get_deployer_status():
    result = {}

    if (running_context == 'local'):
        result=get_deployer_status_local()
    else:
        result=get_deployer_status_openshift()

    return result

def get_deployer_status_local():
    result = {}
    # Check if the env apply process is active
    result['deployer_active']=False
    for proc in psutil.process_iter():
        if (proc.username() == getpass.getuser()):
            try:
                # app.logger.info(proc.cmdline())
                if 'cp-deploy.sh' in proc.cmdline() and \
                    'env' in proc.cmdline() and ('apply' in proc.cmdline() or 'download' in proc.cmdline()):
                    result['deployer_active']=True
            except:
                pass
    deploy_state_log_path = status_dir + '/state/deployer-state.out'
    get_deployer_status_details(deploy_state_log_path, result)
    return(result)

def get_deployer_status_openshift():
    result = {}
    # Check if the env apply process is active
    deployer_starting=False
    result['deployer_active']=False

    oc_get_deployer_start=['oc','get',f'-n={deployer_project}','pods','-l=app=cloud-pak-deployer-start','-o=json']
    app.logger.info('Get cloud-pak-deployer-start pods: {}'.format(oc_get_deployer_start))

    try:
        process = subprocess.Popen(oc_get_deployer_start,
                        stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE,
                        universal_newlines=True)
        
        stdout, stderr = process.communicate()
        
        if process.returncode == 0:
            deployer_start_pods=json.loads(stdout)
            for ds in deployer_start_pods['items']:
                if 'status' in ds and 'phase' in ds['status']:
                    if ds['status']['phase'] in ['Pending','Running']:
                        result['deployer_active']=True
                        deployer_starting=True
        
    except Exception as e:
        app.logger.info('Error while getting cloud-pak-deployer-start pods: {}, assuming deployer is not started'.format(str(e)))
        result['deployer_active']=False

    if (not deployer_starting):
        oc_get_deployer=['oc','get',f'-n={deployer_project}','pods','-l=app=cloud-pak-deployer','-o=json']
        app.logger.info('Get cloud-pak-deployer pods: {}'.format(oc_get_deployer))

        try:
            process = subprocess.Popen(oc_get_deployer,
                            stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE,
                            universal_newlines=True)
            
            stdout, stderr = process.communicate()
            
            if process.returncode == 0:
                deployer_pods=json.loads(stdout)
                for dp in deployer_pods['items']:
                    if 'status' in dp and 'phase' in dp['status']:
                        if dp['status']['phase'] in ['Pending','Running']:
                            result['deployer_active']=True
            
        except Exception as e:
            app.logger.info('Error while getting cloud-pak-deployer pods: {}, assuming deployer is not started'.format(str(e)))
            result['deployer_active']=False

        oc_get_debug=['oc','get',f'-n={deployer_project}','pods','-l=app=cloud-pak-deployer-debug','-o=json']
        app.logger.info('Get cloud-pak-deployer debug pods: {}'.format(oc_get_debug))

        try:
            process = subprocess.Popen(oc_get_debug,
                            stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE,
                            universal_newlines=True)
            
            stdout, stderr = process.communicate()
            
            if process.returncode == 0:
                deployer_debug=json.loads(stdout)
                for dd in deployer_debug['items']:
                    if 'status' in dd and 'phase' in dd['status']:
                        if dd['status']['phase'] in ['Running']:

                            oc_get_state=['oc','cp',f'-n={deployer_project}',dd['metadata']['name']+':/Data/cpd-status/state/deployer-state.out','/tmp/deployer-state.out']
                            app.logger.info('Get cloud-pak-deployer state: {}'.format(oc_get_state))

                            try:
                                process = subprocess.Popen(oc_get_state,
                                                stdout=subprocess.PIPE,
                                                stderr=subprocess.PIPE,
                                                universal_newlines=True)
                                
                                stdout, stderr = process.communicate()

                                if process.returncode == 0:
                                    deploy_state_log_path = '/tmp/deployer-state.out'
                                    result=get_deployer_status_details(deploy_state_log_path, result)
                                
                            except Exception as e:
                                app.logger.info('Error while getting deployer state from pod {}: {}, not getting detailed status'.format(dd['metadata']['name'],str(e)))

        except Exception as e:
            app.logger.info('Error while getting cloud-pak-deployer-debug pod: {}, not getting detailed status'.format(str(e)))

    return(result)

def get_deployer_status_details(deploy_state_log_path, result):
    app.logger.info('Retrieving state from {}'.format(deploy_state_log_path))
    try:
        with open(deploy_state_log_path, "r", encoding='UTF-8') as f:
            temp={}
            content = f.read().replace('\\','')
            f.close()
            docs=yaml.safe_load_all(content)
            for doc in docs:
                temp={**temp, **doc}
            if 'deployer_stage' in temp:
                result['deployer_stage']=temp['deployer_stage']
            if 'last_step' in temp:
                result['last_step']=temp['last_step']
            if 'percentage_completed' in temp:
                result['percentage_completed']=temp['percentage_completed']
            if 'completion_state' in temp:
                result['completion_state']=temp['completion_state']
            if 'mirror_current_image' in temp:
                result['mirror_current_image']=temp['mirror_current_image']
            if 'mirror_number_images' in temp:
                result['mirror_number_images']=temp['mirror_number_images']
            if 'service_state' in temp:
                result['service_state']=temp['service_state']
    except FileNotFoundError:
        app.logger.warning('Error while reading file {}'.format(deploy_state_log_path))
    except PermissionError:
        app.logger.warning('Permission error while reading file {}'.format(deploy_state_log_path))
    except IOError:
        app.logger.warning('IO Error while reading file {}'.format(deploy_state_log_path))
    except Exception as e:
        app.logger.warning('Internal server error: {}'.format(e))

    return result

#
# Deployer configuration
#

@app.route('/api/v1/configuration',methods=["GET"])
def read_configuration():
    config_result: dict[str, Any] = {
        "code":-1,
        "message":"",
        "content":"",
        "data":{},
        "metadata":{},
    }

    app.logger.info(running_context)
    app.logger.info(config_dir)
    read_result={}
    if (running_context == 'local'):
        read_result = read_configuration_from_file()
    else:
        read_result = read_configuration_from_openshift()


    if (read_result['code'] == 0):
        config_result['metadata']=read_result['metadata']
        if (read_result['metadata']['existing_config']):
            app.logger.info(config_result['content'])
            temp=yaml.load(read_result['content'], Loader=yaml.FullLoader)

            if 'global_config' in temp:
                config_result['data']['global_config']=temp['global_config']
            else:
                app.logger.info("Loading base global_config data from {}".format(cp_base_config_path+'/ocp-existing-ocp-auto.yaml'))
                config_result['data']['global_config']=loadYamlFile(cp_base_config_path+'/ocp-existing-ocp-auto.yaml')['global_config']

            if 'openshift' in temp:
                config_result['data']['openshift']=temp['openshift']
            else:
                app.logger.info("Loading base openshift data from {}".format(cp_base_config_path+'/ocp-existing-ocp-auto.yaml'))
                config_result['data']['openshift']=loadYamlFile(cp_base_config_path+'/ocp-existing-ocp-auto.yaml')['openshift']

            if 'cp4d' in temp:
                config_result['data']['cp4d']=temp['cp4d']
                config_result['metadata']['selectedCloudPak'] = 'software-hub'
            elif 'cp4i' in temp:
                config_result['data']['cp4i']=temp['cp4i']
                config_result['metadata']['selectedCloudPak'] = 'cp4i'
            else:
                app.logger.info("Loading base cp4d data from {}".format(cp_base_config_path+'/cp4d-latest.yaml'))
                config_result['data']['cp4d']=loadYamlFile(cp_base_config_path+'/cp4d-latest.yaml')['cp4d']
                app.logger.info("Loading base cp4i data from {}".format(cp_base_config_path+'/cp4i-latest.yaml'))
                config_result['data']['cp4i']=loadYamlFile(cp_base_config_path+'/cp4i-latest.yaml')['cp4i']
                config_result['metadata']['selectedCloudPak'] = 'software-hub'

            if 'env_id' not in config_result['data']['global_config']:
                config_result['data']['global_config']['env_id']='demo'
                app.logger.warning("Added env_id to global_config: {}".format(config_result['data']['global_config']))

            config_result['code'] = 0
            config_result['message'] = "Successfully converted input to configuration."
            app.logger.info('Result of reading configuration: {}'.format(json.dumps(config_result,indent=2)))
        else:
            app.logger.info("Loading base global_config data from {}".format(cp_base_config_path+'/ocp-existing-ocp-auto.yaml'))
            config_result['data']['global_config']=loadYamlFile(cp_base_config_path+'/ocp-existing-ocp-auto.yaml')['global_config']
            app.logger.info("Loading base openshift data from {}".format(cp_base_config_path+'/ocp-existing-ocp-auto.yaml'))
            config_result['data']['openshift']=loadYamlFile(cp_base_config_path+'/ocp-existing-ocp-auto.yaml')['openshift']
            app.logger.info("Loading base cp4d data from {}".format(cp_base_config_path+'/cp4d-latest.yaml'))
            config_result['data']['cp4d']=loadYamlFile(cp_base_config_path+'/cp4d-latest.yaml')['cp4d']
            app.logger.info("Loading base cp4i data from {}".format(cp_base_config_path+'/cp4i-latest.yaml'))
            config_result['data']['cp4i']=loadYamlFile(cp_base_config_path+'/cp4i-latest.yaml')['cp4i']
            config_result['metadata']['selectedCloudPak'] = 'software-hub' 
            config_result['code'] = 0
            config_result['message'] = "Successfully created new configuration."
            app.logger.info('Result of creating configuration: {}'.format(json.dumps(config_result,indent=2)))

    return config_result

def read_configuration_from_file() -> dict[str, Any]:
    file_result = {
        "code":-1,
        "message":"",
        "content":"",
        "metadata":{},
    }
    """
    Read configuration content from a YAML file.
    """
    existing_config=False
    found_config_files=glob.glob(config_dir+'/config/*.yaml')
    if len(found_config_files) == 0:
        generated_config_yaml_path = config_dir+'/config/cpd-config.yaml'
        existing_config=False
    elif len(found_config_files) > 1:
        errmsg="More than 1 yaml file found in directory {}. Wizard can be used for 0 or 1 config files.".format(config_dir+'/config')
        app.logger.error(errmsg)
        file_result['code'] = 400
        file_result['message'] = errmsg
        return file_result
    else:
        generated_config_yaml_path = found_config_files[0]
        existing_config=True

    app.logger.info(file_result)

    file_result['metadata']['existing_config'] = existing_config 

    app.logger.info('Config file that will be used is {}'.format(generated_config_yaml_path))
    file_result['metadata']['config_file_path'] = generated_config_yaml_path
    if (existing_config):
        try:
            with open(generated_config_yaml_path, "r", encoding='UTF-8') as f:
                content = f.read()
                f.close()
                file_result['content'] = content
            file_result['code'] = 0
            file_result['content'] = content
            file_result['message'] = "Successfully retrieved configuration from file {}".format(generated_config_yaml_path)
            app.logger.info("Successfully retrieved configuration from file {}".format(generated_config_yaml_path))
        except FileNotFoundError:
            file_result['code'] = 404
            file_result['message'] = "Configuration File is not found."
            app.logger.warning('Error while reading file {}'.format(generated_config_yaml_path))
        except PermissionError:
            file_result['code'] = 401
            file_result['message'] = "Permission Error."
        except IOError:
            file_result['code'] = 101
            file_result['message'] = "IO Error."
    else:
        file_result['code'] = 0

    return file_result

def read_configuration_from_openshift() -> dict[str, Any]:
    config_result = {
        "code":-1,
        "message":"",
        "content":"",
        "metadata":{},
    }
    """
    Read configuration content from an OpenShift ConfigMap
    """
    
    config_result['metadata']['existing_config'] = False
    config_result['metadata']['cp_entitlement_key'] = ""
    
    # Get configuration from the cloud-pak-deployer-config configmap
    cm_command=['oc']
    cm_command += ['extract',f'-n={deployer_project}','configmap/cloud-pak-deployer-config','--keys=cpd-config.yaml','--to=-']
    app.logger.info('Retrieving config map command: {}'.format(cm_command))

    try:
        process = subprocess.Popen(cm_command,
                        stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE,
                        universal_newlines=True)
        
        stdout, stderr = process.communicate()
        
        if process.returncode == 0:
            config_result['metadata']['existing_config'] = True
            config_result['content']=stdout
            config_result['message'] = "Successfully retrieved configuration from config map"
        else:
            config_result['metadata']['existing_config'] = False
            config_result['content']=""
            config_result['message'] = "Config map not retrieved, assuming non-existing config"
        
        app.logger.info(f"Successfully executed oc extract command. Output length: {len(stdout)}")
        
    except subprocess.SubprocessError as e:
        app.logger.info('Subprocess error while retrieving config map: {}, assuming non-existing config'.format(str(e)))
        config_result['message'] = "Config map not retrieved, assuming non-existing config. Error: {}".format(str(e))
        config_result['metadata']['existing_config'] = False
        config_result['content']=""
    except Exception as e:
        app.logger.info('Error while retrieving config map: {}, assuming non-existing config'.format(str(e)))
        config_result['message'] = "Config map not retrieved, assuming non-existing config. Error: {}".format(str(e))
        config_result['metadata']['existing_config'] = False
        config_result['content']=""

    entitlement_command=['oc']
    entitlement_command += ['extract',f'-n={deployer_project}','secret/cloud-pak-entitlement-key','--keys=cp-entitlement-key','--to=-']
    app.logger.info('Retrieving secret command: {}'.format(entitlement_command))

    try:
        process = subprocess.Popen(entitlement_command,
                        stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE,
                        universal_newlines=True)
        
        stdout, stderr = process.communicate()

        if process.returncode == 0:
            existing_config=True
            config_result['metadata']['cp_entitlement_key']=stdout
            config_result['message'] = "Successfully retrieved entitlement key from secret"
        else:
            existing_config=False
            config_result['metadata']['cp_entitlement_key']=""
            config_result['message'] = "Secret not retrieved, assuming entitlement key not set"
        
    except Exception as e:
        app.logger.info('Error while retrieving secret: {}, assuming non-existing entitlement key'.format(str(e)))
        config_result['metadata']['cp_entitlement_key']=""
    
    config_result['code'] = 0

    app.logger.info(config_result)

    return config_result




@app.route('/api/v1/configuration',methods=["PUT"])
def update_configuration():

    body = json.loads(request.get_data())

    full_configuration=body['configuration']
    app.logger.info("Full configuration: {}".format(json.dumps(full_configuration, indent=4)))

    app.logger.info(running_context)
    app.logger.info(config_dir)
    read_result={}
    if (running_context == 'local'):
        result=update_configuration_file(full_configuration)
    else:
        result=update_configuration_openshift(full_configuration)

    return result

def update_configuration_file(full_configuration):

    all_in_one = format_configuration_yaml(full_configuration)
        
    with open(full_configuration['metadata']['config_file_path'], 'w', encoding='UTF-8') as f1:
        f1.write(all_in_one)
        f1.close()

    with open(full_configuration['metadata']['config_file_path'], "r", encoding='UTF-8') as f1:
        result={}
        result["config"]=f1.read()
        f1.close()

    return result

def update_configuration_openshift(full_configuration):

    all_in_one = format_configuration_yaml(full_configuration)

    with open('/tmp/cpd-config.yaml', 'w', encoding='UTF-8') as f1:
        f1.write(all_in_one)
        f1.close()

    with open('/tmp/cpd-config.yaml', "r", encoding='UTF-8') as f1:
        result={}
        result["config"]=f1.read()
        f1.close()

    # First try to create config map, in case it doesn't exist yet
    create_cm_command=['oc','create',f'-n={deployer_project}','configmap','cloud-pak-deployer-config']
    app.logger.info('Create config map command: {}'.format(create_cm_command))

    process = subprocess.Popen(create_cm_command,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    universal_newlines=True)
    
    stdout, stderr = process.communicate()
    
    # Update the config map
    if process.returncode != 0:
        app.logger.info(f"Error creating config map: {stderr}, ignoring")

    update_cm_command=['oc','set','data',f'-n={deployer_project}','configmap/cloud-pak-deployer-config','--from-file=cpd-config.yaml=/tmp/cpd-config.yaml']
    app.logger.info('Set data for config map command: {}'.format(update_cm_command))

    process = subprocess.Popen(update_cm_command,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    universal_newlines=True)
    
    stdout, stderr = process.communicate()
    
    if process.returncode != 0:
        app.logger.info(f"Error creating updating map: {stderr}")        

    return result

#
# Format configuration YAML
#

@app.route('/api/v1/format-configuration',methods=["POST"])
def format_configuration():
    formatted_config: dict[str, Any] = {
        "code":-1,
        "message":"",
        "data":{},
    }

    body = json.loads(request.get_data())

    formatted_config['data']=format_configuration_yaml(body)
    formatted_config['code'] = 0

    return formatted_config


def format_configuration_yaml(full_configuration):
    global_config_yaml = yaml.safe_dump({'global_config': full_configuration['data']['global_config']})
    all_in_one = '---\n'+global_config_yaml

    openshift_yaml = yaml.safe_dump({'openshift': full_configuration['data']['openshift']})
    all_in_one = all_in_one + '\n\n' + openshift_yaml

    if 'cp4d' in full_configuration['data'] and full_configuration['metadata']['selectedCloudPak'] == 'software-hub':
        # Sort cp4d dictionary by value type before dumping
        cp4d_data = full_configuration['data']['cp4d']
        if isinstance(cp4d_data, list):
            # If cp4d is a list, sort each dictionary in the list
            sorted_cp4d_data = []
            for item in cp4d_data:
                if isinstance(item, dict):
                    sorted_item = dict(sort_cp4d_dict(item.items()))
                    sorted_cp4d_data.append(sorted_item)
                else:
                    sorted_cp4d_data.append(item)
            cp4d_yaml = yaml.safe_dump({'cp4d': sorted_cp4d_data}, sort_keys=False)
        else:
            # If cp4d is a dict, sort it
            sorted_cp4d = dict(sort_cp4d_dict(cp4d_data.items()))
            cp4d_yaml = yaml.safe_dump({'cp4d': sorted_cp4d}, sort_keys=False)
        all_in_one = all_in_one + '\n\n' + cp4d_yaml
    if 'cp4i' in full_configuration['data'] and full_configuration['metadata']['selectedCloudPak'] == 'cp4i':
        cp4i_yaml=yaml.safe_dump({'cp4i': full_configuration['data']['cp4i']})
        all_in_one = all_in_one + '\n\n' + cp4i_yaml

    return all_in_one

def sort_cp4d_dict(items):
    """
    Sort cp4d dictionary items with specific key ordering:
    1. project (if exists)
    2. operators_project (if exists)
    3. cp4d_version (if exists)
    4. Then by value type:
       - Scalars (str, int, float, bool, None)
       - Lists of scalars
       - Lists of dictionaries
       - Dictionaries
    """
    # Define priority keys and their order
    priority_keys = ['project', 'operators_project', 'cp4d_version']
    
    def get_sort_key(item):
        key, value = item
        
        # Check if key is in priority list
        if key in priority_keys:
            # Return negative priority to ensure these come first
            return (-1000 + priority_keys.index(key), key)
        
        # For non-priority keys, sort by value type
        # Scalars get priority 0
        if isinstance(value, (str, int, float, bool, type(None))):
            return (0, key)
        # Lists get priority 1 or 2 depending on content
        elif isinstance(value, list):
            if len(value) == 0:
                return (1, key)
            # Check if list contains dictionaries
            if any(isinstance(v, dict) for v in value):
                return (2, key)  # List of dicts
            else:
                return (1, key)  # List of scalars
        # Dictionaries get priority 3
        elif isinstance(value, dict):
            return (3, key)
        # Everything else gets priority 4
        else:
            return (4, key)
    
    return sorted(items, key=get_sort_key)


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

@app.route('/api/v1/environment-variable',methods=["GET"])
def environmentVariable():
    result={}

    running_context=str(os.getenv('CPD_CONTEXT', default='local'))

    result['CPD_WIZARD_PAGE_TITLE']=os.getenv('CPD_WIZARD_PAGE_TITLE', default='Cloud Pak Deployer')
    result['CPD_WIZARD_MODE']=os.getenv('CPD_WIZARD_MODE', default='')
    result['STATUS_DIR']=os.getenv('STATUS_DIR', default='')
    result['CONFIG_DIR']=os.getenv('CONFIG_DIR', default='')
    result['CPD_CONTEXT']=os.getenv('CPD_CONTEXT', default='local')

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
   http://0.0.0.0:8080  
******************************************************************************
    """)
    app.run(host='0.0.0.0', port=32080, debug=True)    