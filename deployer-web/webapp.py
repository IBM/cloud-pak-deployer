from flask import Flask, send_from_directory,request
import subprocess

app = Flask(__name__,static_url_path='', static_folder='ww')


@app.route('/',defaults={'path':''})
def index():
    return send_from_directory(app.static_folder,'index.html')


@app.route('/api/v1/deploy',methods=["POST"])
def deploy():
    body = request.json()
    env = body.environment
    process = subprocess.Popen(['../cp-deploy.sh', 'env', 'apply','-e env_id={}'.format(body.envId),'-e ibm_cloud_region={}'.format(body.region)], 
                           stdout=subprocess.PIPE,
                           universal_newlines=True,
                           env={'IBM_CLOUD_API_KEY': env.ibmCloudAPIKey,
                                'CP_ENTITLEMENT_KEY': env.entilementKey,
                                'STATUS_DIR':'/data/status/sample',
                                'CONFIG_DIR':'/data/config/sample'})
    
    return 'runing'

if __name__ == '__main__':
    app.run(host='0.0.0.0', port='32080', debug=False)    