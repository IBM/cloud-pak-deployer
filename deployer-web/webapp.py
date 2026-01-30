<<<<<<< HEAD
from time import sleep
from typing import Any
from flask import Flask, send_from_directory,request,make_response,send_file
import sys, psutil, subprocess, os, getpass
import json,yaml, re
from shutil import copy2 
from pathlib import Path
import glob, zipfile, tarfile
=======
from flask import Flask, send_from_directory,request,make_response,send_file
import sys, psutil, subprocess, os
import json, yaml, re
from shutil import copyfile
from pathlib import Path
import glob, zipfile
>>>>>>> main
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

<<<<<<< HEAD
deployer_dir = Path(os.path.dirname(os.path.realpath(__file__))).parent
app.logger.info('Deployer directory: {}'.format(deployer_dir))
cp_base_config_path = os.path.join(deployer_dir,'sample-configurations/sample-dynamic/config-samples')
ocp_base_config_path = os.path.join(deployer_dir,'sample-configurations/sample-dynamic/config-samples')
running_context=str(os.getenv('CPD_CONTEXT', default='local'))
app.logger.info('Deployer context: {}'.format(running_context))
deployer_project = str(os.getenv('CPD_DEPLOYER_PROJECT', default='cloud-pak-deployer'))
=======
parent = Path(os.path.dirname(os.path.realpath(__file__))).parent
app.logger.info('Parent path of python script: {}'.format(parent))
cp_base_config_path = os.path.join(parent,'sample-configurations/web-ui-base-config/cloud-pak')
ocp_base_config_path = os.path.join(parent,'sample-configurations/web-ui-base-config/ocp')
>>>>>>> main
config_dir=str(os.getenv('CONFIG_DIR'))
status_dir=str(os.getenv('STATUS_DIR'))

Path( status_dir+'/log' ).mkdir( parents=True, exist_ok=True )
Path( config_dir+'/config' ).mkdir( parents=True, exist_ok=True )

<<<<<<< HEAD
#
# Root
#
=======
# Global variable set in /v1/configuration
generated_config_yaml_path = ""
>>>>>>> main

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
<<<<<<< HEAD

#
# Start deployment
#
=======
>>>>>>> main

@app.route('/api/v1/deploy',methods=["POST"])
def deploy():
    body = json.loads(request.get_data())
<<<<<<< HEAD
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
=======
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
>>>>>>> main
    deploy_command+=['-v']
    app.logger.info('deploy command: {}'.format(deploy_command))

    process = subprocess.Popen(deploy_command, 
                    universal_newlines=True,
                    env=deployer_env)

    return 'running'

<<<<<<< HEAD
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
def download_log():
    body = json.loads(request.get_data())
    print(body, file=sys.stderr)

    if 'deployerLog' not in body :
        return make_response('Bad Request', 400)

    deployerLog=body['deployerLog']
    if deployerLog != "deployer-log" and deployerLog != "all-logs":
        return make_response('Bad Request', 400)

    if (running_context == 'local'):
        download_log_local(deployerLog)
    else:
        download_log_openshift(deployerLog)

    if deployerLog == "deployer-log":
        log_path = '/tmp/cloud-pak-deployer.log'
        return send_file(log_path, as_attachment=True)
    else:
        log_zip = '/tmp/cloud-pak-deployer-logs.tar.gz'
        return send_file(log_zip, as_attachment=True)
    

def download_log_local(deployerLog):
    if deployerLog == "deployer-log":
        copy2(status_dir+'/log/cloud-pak-deployer.log', '/tmp/')
    else:
        log_folder_path = status_dir + '/log/'
        with tarfile.open('/tmp/cloud-pak-deployer-logs.tar.gz', 'w:gz') as tar_file:
            for f in os.listdir(log_folder_path):
                tar_file.add(os.path.join(log_folder_path,f))
            tar_file.close()

def download_log_openshift(deployerLog):
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

                        if deployerLog == "deployer-log":
                            oc_get_log=['oc','cp',f'-n={deployer_project}',dd['metadata']['name']+':/Data/cpd-status/log/cloud-pak-deployer.log','/tmp/cloud-pak-deployer.log']
                            app.logger.info('Get cloud-pak-deployer log: {}'.format(oc_get_log))

                            try:
                                process = subprocess.Popen(oc_get_log,
                                                stdout=subprocess.PIPE,
                                                stderr=subprocess.PIPE,
                                                universal_newlines=True)
                                
                                stdout, stderr = process.communicate()

                            except Exception as e:
                                app.logger.info('Error while getting /Data/cpd-status/log/cloud-pak-deployer.log from pod {}: {}'.format(dd['metadata']['name'],str(e)))
                        else:
                            oc_rsh_tar=['oc','rsh',f'-n={deployer_project}',dd['metadata']['name'],'tar','cvzf','/tmp/cloud-pak-deployer-logs.tar.gz','-C','/Data/cpd-status/log','.']
                            app.logger.info('tar cloud-pak-deployer logs: {}'.format(oc_rsh_tar))

                            try:
                                process = subprocess.Popen(oc_rsh_tar,
                                                stdout=subprocess.PIPE,
                                                stderr=subprocess.PIPE,
                                                universal_newlines=True)
                                
                                stdout, stderr = process.communicate()
                                app.logger.info(stdout)

                            except Exception as e:
                                app.logger.info('Error while tarring Cloud Pak Deployer logs in pod {}: {}, not getting detailed status'.format(dd['metadata']['name'],str(e)))

                            oc_get_log_tar=['oc','cp',f'-n={deployer_project}',dd['metadata']['name']+':/tmp/cloud-pak-deployer-logs.tar.gz','/tmp/cloud-pak-deployer-logs.tar.gz']
                            app.logger.info('Get cloud-pak-deployer logs: {}'.format(oc_get_log_tar))

                            try:
                                process = subprocess.Popen(oc_get_log_tar,
                                                stdout=subprocess.PIPE,
                                                stderr=subprocess.PIPE,
                                                universal_newlines=True)
                                
                                stdout, stderr = process.communicate()

                            except Exception as e:
                                app.logger.info('Error while getting Cloud Pak Deployer logs from pod {}: {}, not getting detailed status'.format(dd['metadata']['name'],str(e)))

    except Exception as e:
        app.logger.info('Error while getting cloud-pak-deployer-debug pod: {}, not getting getting logs'.format(str(e)))

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

    app.logger.info(f"Deployer status: {result}")

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
        oc_get_deployer=['oc','get',f'-n={deployer_project}','job','cloud-pak-deployer','-o=json']
        app.logger.info('Get cloud-pak-deployer job: {}'.format(oc_get_deployer))

        try:
            process = subprocess.Popen(oc_get_deployer,
                            stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE,
                            universal_newlines=True)
            
            stdout, stderr = process.communicate()
            
            if process.returncode == 0:
                deployer_job=json.loads(stdout)
                if 'status' in deployer_job:
                    if not 'conditions' in deployer_job['status']:
                        result['deployer_active']=True
                    elif deployer_job['status']['conditions'][0]['type'] not in ['Failed', 'Complete']:
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
=======
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
        proc.stdin.close()

        return json.dumps(result)
    else:
        return make_response('Bad Request', 400) 

@app.route('/api/v1/deployer-status',methods=["GET"])
def get_deployer_status():
    result = {}

    # Check if the env apply process is active
    result['deployer_active']=False
    for proc in psutil.process_iter():
        # app.logger.info(proc.cmdline())
        if '/cloud-pak-deployer/cp-deploy.sh' in proc.cmdline() and \
            'env' in proc.cmdline() and ('apply' in proc.cmdline() or 'download' in proc.cmdline()):
            result['deployer_active']=True
    deploy_state_log_path = status_dir + '/state/deployer-state.out'

    # app.logger.info('Retrieving state from {}'.format(deploy_state_log_path))
    try:
        with open(deploy_state_log_path, "r", encoding='UTF-8') as f:
            temp={}
        with open(deploy_state_log_path, "r", encoding='UTF-8') as f:
            temp={}
            content = f.read()
            f.close()
            # app.logger.info(content)
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
    except:
        app.logger.warning('internal server error')
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
            # app.logger.info(content)
            docs=yaml.safe_load_all(content)
            for doc in docs:
                temp={**temp, **doc}

            if 'cp4d' in temp:
                result['data']['cp4d']=temp['cp4d']
                del temp['cp4d']
            else:
                app.logger.info("Loading base cp4d data from {}".format(cp_base_config_path+'/cp4i.yaml'))
                result['data']['cp4d']=loadYamlFile(cp_base_config_path+'/cp4d.yaml')['cp4d']

            if 'cp4i' in temp:
                result['data']['cp4i']=temp['cp4i']
                del temp['cp4i']
            else:
                app.logger.info("Loading base cp4i data from {}".format(cp_base_config_path+'/cp4i.yaml'))
                result['data']['cp4i']=loadYamlFile(cp_base_config_path+'/cp4i.yaml')['cp4i']

            result['data']['ocp']=temp
            if 'env_id' not in result['data']['ocp']['global_config']:
                result['data']['ocp']['global_config']['env_id']='demo'
                app.logger.warning("Added env_id to global_config: {}".format(result['data']['ocp']['global_config']))

            result['code'] = 0
            result['message'] = "Successfully retrieved configuration."
            f.close()
            # app.logger.info('Result of reading file: {}'.format(result))
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

@app.route('/api/v1/cartridges/<cloudpak>',methods=["GET"])
def getCartridges(cloudpak):
    if cloudpak not in ['cp4d', 'cp4i']:
       return make_response('Bad Request', 400)
    return loadYamlFile(cp_base_config_path+'/{}.yaml'.format(cloudpak))
>>>>>>> main

@app.route('/api/v1/logs',methods=["GET"])
def getLogs():
    result={}
    result["logs"]='waiting'
    log_path=status_dir+'/log/cloud-pak-deployer.log'
    print(log_path)
    if os.path.exists(log_path):
        result["logs"]=open(log_path,"r").read()
    return json.dumps(result)

<<<<<<< HEAD
=======
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

>>>>>>> main
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

<<<<<<< HEAD
=======
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

    # Update for region
    if cloud=="ibm-cloud":
        ocp_config['global_config']['ibm_cloud_region']=region
    elif cloud=="aws":
        ocp_config['global_config']['aws_region']=region

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

        if 'cp4d' not in temp:
            temp['cp4d']=loadYamlFile(cp_base_config_path+'/cp4d.yaml')['cp4d']
        if 'cp4i' not in temp:
            temp['cp4i']=loadYamlFile(cp_base_config_path+'/cp4i.yaml')['cp4i']

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

>>>>>>> main
@app.route('/api/v1/environment-variable',methods=["GET"])
def environmentVariable():
    result={}

<<<<<<< HEAD
    running_context=str(os.getenv('CPD_CONTEXT', default='local'))

    result['CPD_WIZARD_PAGE_TITLE']=os.getenv('CPD_WIZARD_PAGE_TITLE', default='Cloud Pak Deployer')
    result['CPD_WIZARD_MODE']=os.getenv('CPD_WIZARD_MODE', default='')
    result['STATUS_DIR']=os.getenv('STATUS_DIR', default='')
    result['CONFIG_DIR']=os.getenv('CONFIG_DIR', default='')
    result['CPD_CONTEXT']=os.getenv('CPD_CONTEXT', default='local')

=======
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
    
>>>>>>> main
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
<<<<<<< HEAD
   http://0.0.0.0:8080  
******************************************************************************
    """)
    app.run(host='0.0.0.0', port=32080, debug=True)    
=======
   https://<host machine>:8080  
******************************************************************************
    """)
    app.run(host='0.0.0.0', port='32080', debug=False)    
>>>>>>> main
