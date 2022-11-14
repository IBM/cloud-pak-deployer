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
                         updateInfraValue, 
                         setWizardError,
                         ocLoginErr
                         }) => {

    //IBM Cloud
    const [loadingIBMRegion, setLoadingIBMRegion] = useState(false)
    const [loadIBMRegionErr, setLoadIBMRegionErr] = useState(false)    
    const [isIBMregionInvalid, setIBMregionInvalid] = useState(false)
    const [isIBMAPIKeyInvalid, setIBMAPIKeyInvalid] = useState(false)
    const [isIBMenvIdInvalid, setIBMenvIdInvalid] = useState(false)

    //AWS   
    const [isAWSAccessKeyIDInvalid, setAWSAccessKeyIDInvalid] = useState(false)
    const [isAWSSecretAccessKeyInvalid, setAWSSecretAccessKeyInvalid] = useState(false)
    const [isAWSregionInvalid, setAWSregionInvalid] = useState(false)   
    
    //Existing OCP
    const [isOcLoginCmdInvalid, setOcLoginCmdInvalid] = useState(false)
    const [isOCPenvIdInvalid, setOCPenvIdInvalid] = useState(false)


    useEffect(() => {
      const getIBMRegion = async() => {
        await axios.get('/api/v1/region/ibm-cloud').then(res =>{          
          setIBMCloudSettings({...IBMCloudSettings, region:res.data.region});        
        }, err => {
          setLoadIBMRegionErr(true)
          console.log(err)
        });
        setLoadingIBMRegion(false)  
      }

      switch (cloudPlatform) {
        case "ibm-cloud":
          if (IBMCloudSettings.region === '') {
            setLoadingIBMRegion(true)
            getIBMRegion()
          }
          if (IBMCloudSettings.IBMAPIKey && IBMCloudSettings.envId && IBMCloudSettings.region ) {
            setWizardError(false)
          }
          break; 
        case "aws":
          if (AWSSettings.accessKeyID && AWSSettings.secretAccessKey && AWSSettings.region ) {
            setWizardError(false)
          }
          break;
        case "existing-ocp":
          if (OCPSettings.ocLoginCmd && OCPSettings.envId) {
            setWizardError(false)
          }
          break;  
        default:

      }   // eslint-disable-next-line
    },[cloudPlatform, IBMCloudSettings, AWSSettings, OCPSettings])

    const setCloudPlatformValue = (value) => {    
      setWizardError(true)
      updateInfraValue({cloudPlatform: value});
    }

    const IBMCloudSettingsOnChange = (e) => {
      switch (e.target.id) {
        case "100":
          setIBMCloudSettings({...IBMCloudSettings, IBMAPIKey:e.target.value});
          if (e.target.value === '') {
            setIBMAPIKeyInvalid(true)
            setWizardError(true)
            return
          }          
          break;
        case "101":
          setIBMCloudSettings({...IBMCloudSettings, envId:e.target.value});
          if (e.target.value === '') {
            setIBMenvIdInvalid(true)
            setWizardError(true)
            return
          }
          break;
        case "102":
          setIBMCloudSettings({...IBMCloudSettings, region:e.target.value});
          if (e.target.value === '') {
            setIBMregionInvalid(true)
            setWizardError(true)
            return
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
          }          
          break;
        case "111":
          setAWSSettings({...AWSSettings, secretAccessKey:e.target.value});
          if (e.target.value === '') {
            setAWSSecretAccessKeyInvalid(true)
            setWizardError(true)
            return
          }
          break;
        case "112":
          setAWSSettings({...AWSSettings, region:e.target.value});
          if (e.target.value === '') {
            setAWSregionInvalid(true)
            setWizardError(true)
            return
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
          }          
          break;
        case "131":
          setOCPSettings({...OCPSettings, envId:e.target.value});
          if (e.target.value === '') {
            setOCPenvIdInvalid(true)
            setWizardError(true)
            return
          }          
          break;
        default:
      }  
    }

    const errorProps = () => ({
      kind: 'error',
      lowContrast: true,
      role: 'error',
      title: 'Unable to get IBM Cloud Region from server.',
      hideCloseButton: false,
    });

    const ocLoginErrorProps = () => ({
      kind: 'error',
      lowContrast: true,
      role: 'error',
      title: 'Get error to login the existing OpenShift platform. ',
      hideCloseButton: false,
    }); 

    return (
      <> 

      { loadIBMRegionErr && <InlineNotification className="cpd-error"
          {...errorProps()}        
            /> } 
      {/* oc login error */}
      {ocLoginErr && <InlineNotification className="cpd-error"
          {...ocLoginErrorProps()}        
           />  }   

      <div className="infra-title">Cloud Platform</div>        

      <RadioButtonGroup orientation="vertical"
         name="radio-button-group"
         defaultSelected={cloudPlatform}     
         onChange={(value)=>{setCloudPlatformValue(value)}
         }
         >
         <RadioButton labelText="Existing OpenShift" value="existing-ocp" id="3" />
         <RadioButton labelText="IBM Cloud" value="ibm-cloud" id="0" />
         <RadioButton labelText="AWS" value="aws" id="1" />
         <RadioButton labelText="vSphere" value="vsphere" id="2" disabled />         
      </RadioButtonGroup>

      {cloudPlatform === 'ibm-cloud' ?  
         <>
          {loadingIBMRegion && <Loading /> }          
          <div className="infra-container">
            <div>
              <div className="infra-items">IBM Cloud API Key</div>
              <PasswordInput onChange={IBMCloudSettingsOnChange} placeholder="IBM Cloud API Key" id="100" labelText="" value={IBMCloudSettings.IBMAPIKey} invalidText="IBM Cloud API Key can not be empty." invalid={isIBMAPIKeyInvalid}/>
            </div>
            <div>
              <div className="infra-items">Enviroment ID</div>
              <TextInput onChange={IBMCloudSettingsOnChange} placeholder="Environment ID" id="101" labelText="" value={IBMCloudSettings.envId} invalidText="Environment ID can not be empty." invalid={isIBMenvIdInvalid}/>
            </div>  
            <div>
              <div className="infra-items">IBM Cloud Region</div>
              <TextInput onChange={IBMCloudSettingsOnChange} placeholder={IBMCloudSettings.region} id="102" labelText="" value={IBMCloudSettings.region} invalidText="IBM Cloud Region can not be empty." invalid={isIBMregionInvalid}/>
            </div> 
          </div>        
         </>  : null } 
      {cloudPlatform === 'aws' ? 
          <>
            <div className="infra-container">
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
                <TextInput onChange={AWSSettingsOnChange} placeholder={AWSSettings.region} id="112" labelText="" value={AWSSettings.region} invalidText="AWS region can not be empty."  invalid={isAWSregionInvalid}/>
              </div> 
            </div>
          </>: null}
      {cloudPlatform === 'existing-ocp' ? 
        <>
          <div className="infra-container">
            <div>
              <div className="infra-items">oc login command</div>
              <TextInput onChange={OCPSettingsOnChange}  placeholder="oc login command" id="130" labelText="" value={OCPSettings.ocLoginCmd} invalidText="oc login command can not be empty."  invalid={isOcLoginCmdInvalid}/>
            </div>
            <div>
              <div className="infra-items">Enviroment ID</div>
              <TextInput onChange={OCPSettingsOnChange} placeholder="Environment ID" id="131" labelText="" value={OCPSettings.envId} invalidText="Environment ID can not be empty." invalid={isOCPenvIdInvalid}/>
            </div>
          </div>
        </> : null}
      </>
    );
  };

export default Infrastructure;