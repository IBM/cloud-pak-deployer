from flask import Flask, send_from_directory

app = Flask(__name__,static_url_path='', static_folder='ww')

@app.route('/')
def index():
    return send_from_directory(app.static_folder,'index.html')

if __name__ == '__main__':
    app.run(host='0.0.0.0', port='8080', debug=False)    