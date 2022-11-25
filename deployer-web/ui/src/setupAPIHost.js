import axios from "axios";

const setupAPIHost =()=>{
    const API_HOST = process.env.REACT_APP_API_ENTRYPOINT;
    if (API_HOST) {
        axios.defaults.baseURL = API_HOST;        
    } else {
        axios.defaults.baseURL = 'http://localhost:32080';
    }
}

export default setupAPIHost;







