from flask import Flask, send_from_directory
import subprocess

app = Flask(__name__,static_url_path='', static_folder='ww')


@app.route('/',defaults={'path':''})
def index():
    return send_from_directory(app.static_folder,'index.html')


@app.route('v2/api/deploy',methods=["POST"])
def deploy(config):
    env = {}
    process = subprocess.Popen(['cp-deploy.sh', 'env', 'apply','-e env_id=pluto-01','-e ibm_cloud_region=eu-gb'], 
                           stdout=subprocess.PIPE,
                           universal_newlines=True,
                           env={'IBM_CLOUD_API_KEY': '/path/to/directory',
                                'CP_ENTITLEMENT_KEY':'',
                                'STATUS_DIR':'',
                                'CONFIG_DIR':''})
    
    return 'runing'