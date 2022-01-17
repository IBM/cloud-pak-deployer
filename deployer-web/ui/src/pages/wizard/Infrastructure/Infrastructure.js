import { RadioButton, RadioButtonGroup, TextInput } from "carbon-components-react";
import './Infrastructure.scss'

const Infrastructure = ({cloudPlatform, IBMAPIKey, envId,  entilementKey, updateInfraValue}) => {

    const setCloudPlatformValue = (value) => {     
      updateInfraValue({cloudPlatform: value});
    }

    const setIBMAPIKeyValue = (e) => {
      updateInfraValue({IBMAPIKey:e.target.value});         
    }

    const setEnvIDValue = (e) => {
      updateInfraValue({envId:e.target.value});
    }

    const setEntilementKeyValue = (e) => {
      updateInfraValue({entilementKey:e.target.value});
    }

    return (
      <> 
      <div className="infra-title">Cloud Platform</div>  
      <RadioButtonGroup orientation="vertical"
         name="radio-button-group"
         defaultSelected={cloudPlatform}     
         onChange={(value)=>{setCloudPlatformValue(value)}
         }
         >
         <RadioButton labelText="IBM Cloud" value="ibm-cloud" id="0" />
         <RadioButton labelText="AWS" value="aws" id="1" disabled  />
         <RadioButton labelText="vSphere" value="vsphere" id="2" disabled />
         <RadioButton labelText="Openshift" value="openshift" id="3" disabled />
      </RadioButtonGroup>

      {cloudPlatform === 'ibm-cloud' ? 
        <>
          <div className="infra-container">
            <div>
              <div className="infra-items">IBM Cloud API Key</div>
              <TextInput.PasswordInput onChange={setIBMAPIKeyValue} placeholder="IBM Cloud API Key" id="0" labelText="" value={IBMAPIKey} />
            </div>
            <div>
              <div className="infra-items">Entitlement key</div>
              <TextInput.PasswordInput onChange={setEntilementKeyValue} placeholder="Entitlement key" id="1" labelText="" value={entilementKey}/>
            </div>
            <div>
              <div className="infra-items">Enviroment ID</div>
              <TextInput onChange={setEnvIDValue} placeholder="Enviroment ID" id="2" labelText="" value={envId} />
            </div>  
          </div>        
        </> 
          : null}

      {cloudPlatform === 'aws' ?
        <>
          <div className="infra-container">
            <div>
              <div className="infra-items">AWS Access Key</div>
              <TextInput.PasswordInput placeholder="AWS Access Key" id="3" labelText="" />
            </div>
          </div>
        </> : null}    
      </>
    );
  };

export default Infrastructure;