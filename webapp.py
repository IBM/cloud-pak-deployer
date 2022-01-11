from flask import Flask, send_from_directory

app = Flask(__name__,static_url_path='', static_folder='ww')


@app.route('/',defaults={'path':''})
def index():
    return send_from_directory(app.static_folder,'index.html')


@app.route('v2/api/deploy')
def deploy():
    return