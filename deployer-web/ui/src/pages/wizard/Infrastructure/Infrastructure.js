import axios from "axios";
import { InlineNotification, Loading, RadioButton, RadioButtonGroup, TextInput } from "carbon-components-react";
import { useEffect, useState } from "react";
import './Infrastructure.scss'

const Infrastructure = ({cloudPlatform, IBMCloudSettings, updateInfraValue, updateWizardError, setIBMCloudSettings, AWSSettings, setAWSSettings}) => {

    //IBM Cloud
    const [loadingIBMRegion, setLoadingIBMRegion] = useState(false)
    const [loadIBMRegionErr, setLoadIBMRegionErr] = useState(false)
    const [IBMRegion, setIBMRegion] = useState(IBMCloudSettings.region)
    const [isIBMregionInValid, setIBMregionInValid] = useState(false)

    //AWS
    const [AWSAccessKeyID, setAWSAccessKeyID] = useState(AWSSettings.accessKeyID)
    const [AWSSecretAccessKey, setAWSSecretAccessKey] = useState(AWSSettings.secretAccessKey)
    const [AWSRegion, setAWSRegion] = useState(AWSSettings.region)    
    const [isAWSregionInValid, setAWSregionInValid] = useState(false)      

    useEffect(() => {
      const getIBMRegion = async() => {
        await axios.get('/api/v1/region/ibm-cloud').then(res =>{ 
          setIBMRegion(res.data.region) 
          updateInfraValue({region:res.data.region});          
        }, err => {
          setLoadIBMRegionErr(true)
          console.log(err)
        });
        setLoadingIBMRegion(false)  
      }
      
      if (cloudPlatform === 'ibm-cloud') {           
        if (IBMRegion === '') {
          setLoadingIBMRegion(true)
          getIBMRegion()
        }
      }      
    }, [cloudPlatform])

    const setCloudPlatformValue = (value) => {    
      updateInfraValue({cloudPlatform: value});
    }

    const setIBMAPIKeyValue = (e) => {
      //updateInfraValue({IBMAPIKey:e.target.value});     
      setIBMCloudSettings({...IBMCloudSettings, IBMAPIKey:e.target.value})    
    }

    const setEnvIDValue = (e) => {
      //updateInfraValue({envId:e.target.value});
      setIBMCloudSettings({...IBMCloudSettings, envId:e.target.value})
    }

    const setEntilementKeyValue = (e) => {
      //updateInfraValue({entilementKey:e.target.value});
      setIBMCloudSettings({...IBMCloudSettings, entilementKey:e.target.value})
    }

    const setIBMCloudRegion =(e)=>{
      setIBMRegion(e.target.value)
      if (e.target.value === '') {
        setIBMregionInValid(true)        
        updateWizardError(true)
        return
      }
      updateWizardError(false)
      setIBMregionInValid(false)      
      //updateInfraValue({region:e.target.value});    
      setIBMCloudSettings({...IBMCloudSettings, region:e.target.value})  
    }

    const errorProps = () => ({
      kind: 'error',
      lowContrast: true,
      role: 'error',
      title: 'Unable to get IBM Cloud Region from server.',
      hideCloseButton: false,
    });  

    // 0 - IBMCloudPlatform
    const IBMCloudPlatform = () => {
      return (        
        <>
          {loadingIBMRegion && <Loading /> }          
          <div className="infra-container">
            <div>
              <div className="infra-items">IBM Cloud API Key</div>
              <TextInput.PasswordInput onChange={setIBMAPIKeyValue} placeholder="IBM Cloud API Key" id="0" labelText="" value={IBMCloudSettings.IBMAPIKey} />
            </div>
            {/* <div>
              <div className="infra-items">Entitlement key</div>
              <TextInput.PasswordInput onChange={setEntilementKeyValue} placeholder="Entitlement key" id="1" labelText="" value={IBMCloudSettings.entilementKey}/>
            </div> */}
            <div>
              <div className="infra-items">Enviroment ID</div>
              <TextInput onChange={setEnvIDValue} placeholder="Enviroment ID" id="2" labelText="" value={IBMCloudSettings.envId} />
            </div>  
            <div>
              <div className="infra-items">IBM Cloud Region</div>
              <TextInput onChange={setIBMCloudRegion} placeholder={IBMRegion} id="3" labelText="" value={IBMRegion} invalidText="IBM Cloud Region can not be empty."  invalid={isIBMregionInValid}/>
            </div> 
          </div>        
        </> 
      );
    }

    // 1 - AWSPlatform
    const AWSPlatform = () => {
      return (
        <>
          <div className="infra-container">
            <div>
              <div className="infra-items">AWS Access Key ID</div>
              <TextInput placeholder="AWS Access Key" id="10" labelText="" value={AWSSettings.AWSAccessKeyID} />
            </div>
            <div>
              <div className="infra-items">AWS Secret Access Key</div>
              <TextInput.PasswordInput placeholder="AWS Secret Access Key" id="11" labelText="" value={AWSSettings.AWSSecretAccessKey}/>
            </div>
            <div>
              <div className="infra-items">AWS Region</div>
              <TextInput onChange={setIBMCloudRegion} placeholder={AWSRegion} id="12" labelText="" value={AWSRegion} invalidText="AWS region."  invalid={isAWSregionInValid}/>
            </div> 
          </div>
        </>
      )
    }

    // 3 - ExistingOpenShiftPlatform
    const ExistingOpenShiftPlatform = () => {
      return (
        <>
          <div className="infra-container">
            <div>
              <div className="infra-items">oc login command</div>
              <TextInput placeholder="oc login command" id="30" labelText="" />
            </div>
          </div>
        </>
      )
    }    

    return (
      <> 
      <div className="infra-title">Cloud Platform</div>  
      { loadIBMRegionErr && <InlineNotification className="cpd-error"
                {...errorProps()}        
            /> } 
      <RadioButtonGroup orientation="vertical"
         name="radio-button-group"
         defaultSelected={cloudPlatform}     
         onChange={(value)=>{setCloudPlatformValue(value)}
         }
         >
         <RadioButton labelText="IBM Cloud" value="ibm-cloud" id="0" />
         <RadioButton labelText="AWS" value="aws" id="1" />
         <RadioButton labelText="vSphere" value="vsphere" id="2" disabled />
         <RadioButton labelText="Existing OpenShift" value="existing-ocp" id="3" />
      </RadioButtonGroup>

      {cloudPlatform === 'ibm-cloud' ?  <IBMCloudPlatform /> : null } 
      {cloudPlatform === 'aws' ? <AWSPlatform />: null}
      {cloudPlatform === 'existing-ocp' ? <ExistingOpenShiftPlatform/> : null}

      </>
    );
  };

export default Infrastructure;