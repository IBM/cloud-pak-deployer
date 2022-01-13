from flask import Flask, send_from_directory,request
import json
import subprocess

app = Flask(__name__,static_url_path='', static_folder='ww')


@app.route('/',defaults={'path':''})
def index():
    return send_from_directory(app.static_folder,'index.html')


@app.route('/api/v1/deploy',methods=["POST"])
def deploy():
    body = json.loads(request.get_data())
    env ={}
    if body['cloud']=='IBMCloud':
      env = {'IBM_CLOUD_API_KEY': body['env']['ibmCloudAPIKey'],
                                'CP_ENTITLEMENT_KEY': body['env']['entilementKey']}
    process = subprocess.Popen(['../cp-deploy.sh', 'env', 'webui','-e env_id={}'.format(body['envId']),
                                '-e ibm_cloud_region={}'.format(body['region']), 
                                '--config-dir={}'.format(body['configDir']),'--status-dir={}'.format(body['statusDir']),
                                '--cpd-develop'], 
                           stdout=subprocess.PIPE,
                           universal_newlines=True,
                           env=env)
    
    return 'runing'

if __name__ == '__main__':
    app.run(host='0.0.0.0', port='32080', debug=False)    