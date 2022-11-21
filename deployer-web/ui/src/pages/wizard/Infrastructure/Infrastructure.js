import axios from "axios";
import { InlineNotification, Loading, RadioButton, RadioButtonGroup, TextInput, PasswordInput  } from "carbon-components-react";
import { useEffect, useState } from "react";
import './Infrastructure.scss'

const Infrastructure = ({cloudPlatform, 
                         IBMCloudSettings, 
                         setIBMCloudSettings, 
                         AWSSettings, 
                         setAWSSettings,
                         OCPSettings,
                         setOCPSettings,
                         setCloudPlatform, 
                         setWizardError,
                         ocLoginErr,
                         configuration,
                         setConfiguration,
                         locked,
                         setLocked,
                         isOcLoginCmdInvalid,
                         setOcLoginCmdInvalid,
                         envId,
                         setEnvId,
                         }) => {

    //IBM Cloud
    const [loadingConfiguration, setLoadingConfiguration] = useState(false)
    const [loadConfigurationErr, setLoadConfigurationErr] = useState(false)    
    const [isIBMregionInvalid, setIBMregionInvalid] = useState(false)
    const [isIBMAPIKeyInvalid, setIBMAPIKeyInvalid] = useState(false)
    const [isIBMEnvIdInvalid, setIBMEnvIdInvalid] = useState(false)

    //AWS   
    const [isAWSAccessKeyIDInvalid, setAWSAccessKeyIDInvalid] = useState(false)
    const [isAWSSecretAccessKeyInvalid, setAWSSecretAccessKeyInvalid] = useState(false)
    const [isAWSregionInvalid, setAWSregionInvalid] = useState(false)   
    const [isAWSEnvIdInvalid, setAWSEnvIdInvalid] = useState(false)
    
    //Existing OCP
    const [isOCPEnvIdInvalid, setOCPEnvIdInvalid] = useState(false)

    useEffect(() => {
      const getConfiguration = async() => {
        setLoadingConfiguration(true)  
        await axios.get('/api/v1/configuration').then(res =>{   
          setLoadingConfiguration(false)   
          setLoadConfigurationErr(false)     
          setConfiguration(res.data)
         
          if (res.data.code === 0) {
            setLocked(true)
            
            let cloud=res.data.data.ocp.global_config.cloud_platform
            setCloudPlatform(cloud)
            setEnvId(res.data.data.ocp.global_config.env_id)
          }
        }, err => {
          setLoadingConfiguration(false) 
          setLoadConfigurationErr(true)
          console.log(err)
        });
         
      }      

      if(loadConfigurationErr) {
        return
      }
      //Load configuration
      if (JSON.stringify(configuration) === "{}") {
        getConfiguration()        
      }

      switch (cloudPlatform) {
        case "ibm-cloud": 
          if (IBMCloudSettings.IBMAPIKey && envId && IBMCloudSettings.region ) {
            setWizardError(false)
          }
          break; 
        case "aws":
          if (AWSSettings.accessKeyID && AWSSettings.secretAccessKey && AWSSettings.region && envId ) {
            setWizardError(false)
          }
          break;
        case "existing-ocp":
          if (OCPSettings.ocLoginCmd && envId) {
            setWizardError(false)
          }
          break;  
        default:

      }   // eslint-disable-next-line
    },[cloudPlatform, IBMCloudSettings, AWSSettings, OCPSettings, configuration, locked])

    const IBMCloudSettingsOnChange = (e) => {
      switch (e.target.id) {
        case "100":
          setIBMCloudSettings({...IBMCloudSettings, IBMAPIKey:e.target.value});
          if (e.target.value === '') {
            setIBMAPIKeyInvalid(true)
            setWizardError(true)
            return
          } else {
            setIBMAPIKeyInvalid(false)
          }     
          break;
        case "101":
          setEnvId(e.target.value);
          if (e.target.value === '') {
            setIBMEnvIdInvalid(true)
            setWizardError(true)
            return
          } else {
            setIBMEnvIdInvalid(false)
          }
          break;
        case "102":
          setIBMCloudSettings({...IBMCloudSettings, region:e.target.value});
          if (e.target.value === '') {
            setIBMregionInvalid(true)
            setWizardError(true)
            return
          } else {
            setIBMregionInvalid(false)
          }
          break;
        default:
      }  
    }

    const AWSSettingsOnChange = (e) => {
      switch (e.target.id) {
        case "110":
          setAWSSettings({...AWSSettings, accessKeyID:e.target.value});
          if (e.target.value === '') {
            setAWSAccessKeyIDInvalid(true)
            setWizardError(true)
            return
          } else {
            setAWSAccessKeyIDInvalid(false)
          }       
          break;
        case "111":
          setAWSSettings({...AWSSettings, secretAccessKey:e.target.value});
          if (e.target.value === '') {
            setAWSSecretAccessKeyInvalid(true)
            setWizardError(true)
            return
          } else {
            setAWSSecretAccessKeyInvalid(false)
          }
          break;
        case "112":
          setAWSSettings({...AWSSettings, region:e.target.value});
          if (e.target.value === '') {
            setAWSregionInvalid(true)
            setWizardError(true)
            return
          } else {
            setAWSregionInvalid(false)
          }
          break;
        case "113":
            setEnvId(e.target.value);
            if (e.target.value === '') {
              setAWSEnvIdInvalid(true)
              setWizardError(true)
              return
            } else {
              setAWSEnvIdInvalid(false)
            }
            break;
        default:
      }  
    }

    const OCPSettingsOnChange = (e) => {
      switch (e.target.id) {
        case "130":
          setOCPSettings({...OCPSettings, ocLoginCmd:e.target.value});
          if (e.target.value === '') {
            setOcLoginCmdInvalid(true)
            setWizardError(true)
            return
          } else {
            setOcLoginCmdInvalid(false)
          }       
          break;
        case "131":
          setEnvId(e.target.value);
          if (e.target.value === '') {
            setOCPEnvIdInvalid(true)
            setWizardError(true)
            return
          } else {
            setOCPEnvIdInvalid(false)
          }     
          break;
        default:
      }  
    }

    const errorConfigurationProps = () => ({
      kind: 'error',
      lowContrast: true,
      role: 'error',
      title: 'Unable to get Configuration from server.',
      hideCloseButton: false,
    });

    const ocLoginErrorProps = () => ({
      kind: 'error',
      lowContrast: true,
      role: 'error',
      title: 'Error logging into the OpenShift cluster.',
      hideCloseButton: false,
    }); 

    return (
      <>
      { loadConfigurationErr && <InlineNotification className="cpd-error"
          {...errorConfigurationProps()}        
            /> } 
      {/* oc login error */}
      {ocLoginErr && <InlineNotification className="cpd-error"
          {...ocLoginErrorProps()}        
           />  }   
      {loadingConfiguration && <Loading /> }
      
      <div className="infra-title">Cloud Platform</div>        

      <RadioButtonGroup orientation="vertical"
         name="radio-button-group"          
         onChange={(value)=>{setCloudPlatform(value)}  
         }
         defaultSelected={cloudPlatform}  
         valueSelected={cloudPlatform}  
         >
         <RadioButton labelText="Existing OpenShift" value="existing-ocp" id="0" disabled={locked}/>
         <RadioButton labelText="IBM Cloud" value="ibm-cloud" id="1" disabled={locked}/>
         <RadioButton labelText="AWS" value="aws" id="2" disabled={locked}/>
         <RadioButton labelText="vSphere" value="vsphere" id="3" disabled />         
      </RadioButtonGroup>

      {cloudPlatform === 'ibm-cloud' ?  
         <>                    
          <div className="infra-container">
            <div>
              <div className="infra-items">Enviroment ID</div>
              <TextInput onChange={IBMCloudSettingsOnChange} placeholder="Environment ID" id="101" labelText="" value={envId} invalidText="Environment ID can not be empty." invalid={isIBMEnvIdInvalid} disabled={locked}/>
            </div>  
            <div>
              <div className="infra-items">IBM Cloud API Key</div>
              <PasswordInput onChange={IBMCloudSettingsOnChange} placeholder="IBM Cloud API Key" id="100" labelText="" value={IBMCloudSettings.IBMAPIKey} invalidText="IBM Cloud API Key can not be empty." invalid={isIBMAPIKeyInvalid}/>
            </div>
            <div>
              <div className="infra-items">IBM Cloud Region</div>
              <TextInput onChange={IBMCloudSettingsOnChange} placeholder="IBM Cloud Region" id="102" labelText="" value={IBMCloudSettings.region} invalidText="IBM Cloud Region can not be empty." invalid={isIBMregionInvalid}/>
            </div> 
          </div>        
         </>  : null } 
      {cloudPlatform === 'aws' ? 
          <>
            <div className="infra-container">
              <div>
                <div className="infra-items">Enviroment ID</div>
                <TextInput onChange={AWSSettingsOnChange} placeholder="Environment ID" id="113" labelText="" value={envId} invalidText="Environment ID can not be empty."  invalid={isAWSEnvIdInvalid}/>
              </div> 
              <div>
                <div className="infra-items">AWS Access Key ID</div>
                <TextInput onChange={AWSSettingsOnChange} placeholder="AWS Access Key" id="110" labelText="" value={AWSSettings.accessKeyID} invalidText="AWS Access Key ID can not be empty."  invalid={isAWSAccessKeyIDInvalid}/>
              </div>
              <div>
                <div className="infra-items">AWS Secret Access Key</div>
                <TextInput.PasswordInput onChange={AWSSettingsOnChange} placeholder="AWS Secret Access Key" id="111" labelText="" value={AWSSettings.secretAccessKey} invalidText="AWS Secret Access Key can not be empty."  invalid={isAWSSecretAccessKeyInvalid}/>
              </div>
              <div>
                <div className="infra-items">AWS Region</div>
                <TextInput onChange={AWSSettingsOnChange} placeholder="AWS Region" id="112" labelText="" value={AWSSettings.region} invalidText="AWS region can not be empty."  invalid={isAWSregionInvalid}/>
              </div> 
            </div>
          </>: null}
      {cloudPlatform === 'existing-ocp' ? 
        <>
          <div className="infra-container">
           <div>
              <div className="infra-items">Enviroment ID</div>
              <TextInput onChange={OCPSettingsOnChange} placeholder="Environment ID" id="131" labelText="" value={envId} invalidText="Environment ID can not be empty." invalid={isOCPEnvIdInvalid} disabled={locked}/>
              </div>
           </div>
            <div>
              <div className="infra-items">oc login command</div>
              <TextInput onChange={OCPSettingsOnChange}  placeholder="oc login command" id="130" labelText="" value={OCPSettings.ocLoginCmd} invalidText="Invalid oc login command."  invalid={isOcLoginCmdInvalid}/>
            </div>
        </> : null}
      </>
    );
  };

export default Infrastructure;