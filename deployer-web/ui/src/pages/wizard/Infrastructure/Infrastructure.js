import { RadioButton, RadioButtonGroup, TextInput } from "carbon-components-react";
import { useEffect } from "react";
import { useState } from "react";
import './Infrastructure.scss'


const Infrastructure = ({changeValue}) => {

    const [cloudPlatform, setCloudPlatform] = useState(0);
    const [IBMAPIKey, setIBMAPIKey] = useState('')
    const [envId, setEnvId] = useState('')  
    const [entilementKey, setEntilementKey] = useState('')  

    //will be used in the future
    const [AWSSecurityKey, setAWSSecurityKey] = useState('')


    const setCloudPlatformValue = (index) => {        
       setCloudPlatform(index);
      //  if (index == 0) {
      //     changeValue({cloudPlatform:'ibm-cloud'});
      //  } 
       switch(index) {
          case 0:
            changeValue({cloudPlatform:'ibm-cloud'});
            break;
          case 1:
            changeValue({cloudPlatform:'aws'});
            break;
          case 2:
              changeValue({cloudPlatform:'vsphere'});
              break;
          default:
            changeValue({cloudPlatform:'ibm-cloud'});
          }         
    }

    const setIBMAPIKeyValue = (e) => {
      setIBMAPIKey(e.target.value);
      changeValue({IBMAPIKey:e.target.value});
    }

    const setEnvIDValue = (e) => {
      setEnvId(e.target.value);
      changeValue({envId:e.target.value});
    }

    const setEntilementKeyValue = (e) => {
      setIBMAPIKey(e.target.value);
      changeValue({entilementKey:e.target.value});
    }

    return (
      <> 
      <div className="infra-title">Cloud Platform</div>  
      <RadioButtonGroup orientation="vertical"
         name="radio-button-group"
         defaultSelected='0'       
         onChange={(index)=>{
           setCloudPlatformValue(index)}
         }
         >
         <RadioButton labelText="IBM Cloud" value="0" id="0" />
         <RadioButton labelText="AWS" value="1" id="1" disabled />
         <RadioButton labelText="vSphere" value="2" id="2" disabled />
         <RadioButton labelText="Openshift" value="3" id="3" disabled />
      </RadioButtonGroup>

      {cloudPlatform == 0 ? 
        <>
          <div>
            <div className="infra-items">IBM Cloud API Key</div>
            <TextInput onChange={setIBMAPIKeyValue} placeholder="IBM Cloud API Key"/>
          </div>
          <div>
            <div className="infra-items">Entilement Key</div>
            <TextInput onChange={setEntilementKeyValue} placeholder="Entilement Key"/>
          </div>
          <div>
            <div className="infra-items">Enviroment ID</div>
            <TextInput onChange={setEnvIDValue} placeholder="Enviroment ID"/>
          </div>          
        </> 
          : null}

      {cloudPlatform == 1 ?
        <>
          <div>
            <div className="infra-items">AWS Access Key</div>
            <TextInput placeholder="AWS Access Key"/></div></> : null}    
        </>
    );
  };

export default Infrastructure;