import axios from "axios";
<<<<<<< HEAD
import { InlineNotification, Loading, RadioButton, RadioButtonGroup, TextInput, PasswordInput,Checkbox  } from "@carbon/react";
import { useEffect, useState, useRef } from "react";
import './Infrastructure.scss'

const Infrastructure = ({cloudPlatform, 
=======
import { InlineNotification, Loading, RadioButton, RadioButtonGroup, TextInput, PasswordInput,Checkbox  } from "carbon-components-react";
import { useEffect, useState } from "react";
import './Infrastructure.scss'

const Infrastructure = ({cloudPlatform, 
                         IBMCloudSettings, 
                         setIBMCloudSettings, 
                         AWSSettings, 
                         setAWSSettings,
>>>>>>> main
                         OCPSettings,
                         setOCPSettings,
                         setCloudPlatform, 
                         setWizardError,
                         ocLoginErr,
<<<<<<< HEAD
=======
                         configuration,
                         setConfiguration,
                         locked,
                         setLocked,
>>>>>>> main
                         isOcLoginCmdInvalid,
                         setOcLoginCmdInvalid,
                         envId,
                         setEnvId,
                         checkDeployerStatusErr,
                         cpdWizardMode,
                         selection,
                         registryHostname,
                         setRegistryHostname,
                         registryPort,
                         setRegistryPort,
                         registryNS,
                         setRegistryNS,
                         registryUser,
                         setRegistryUser,
                         registryPassword,
                         setRegistryPassword,
                         portable,
                         setPortable
                         }) => {

<<<<<<< HEAD
    const [loadingConfiguration, setLoadingConfiguration] = useState(false)

    //Existing OCP
    const [isOCPEnvIdInvalid, setOCPEnvIdInvalid] = useState(false)

    const [isRegistryHostnameInvalid, setRegistryHostnameInvalid] = useState(false)
    const [isRegistryNSInvalid, setRegistryNSInvalid] = useState(false)
    const [isRegistryUserInvalid, setRegistryUserInvalid] = useState(false)
    const [isregistryPasswordInvalid, setregistryPasswordInvalid] = useState(false)

    // Ref for oc login command input
    const ocLoginInputRef = useRef(null)

    // Auto-focus the oc login input when component mounts and conditions are met
    useEffect(() => {
      if (selection !== "Configure+Download" && cloudPlatform === 'existing-ocp' && ocLoginInputRef.current) {
        ocLoginInputRef.current.focus()
      }
    }, [selection, cloudPlatform])

    useEffect(() => {
      if (selection!== "Configure+Download") {
        switch (cloudPlatform) {
          case "existing-ocp":
            if (OCPSettings.ocLoginCmd) {
              setWizardError(false)
            }
            break;  
          default:  
        }  
      } else {
        if (portable) {
          if (envId) {
            setWizardError(false)
          }
        } else {
          if (registryHostname && registryHostname && registryUser && registryPassword) {
            setWizardError(false)
          } else {
            setWizardError(true)
          }
        }        
      }
    // eslint-disable-next-line
    },[cloudPlatform, OCPSettings, envId, registryHostname, registryHostname, registryUser, registryPassword, portable])

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

    const RegistryOnChange = (e) => {
      switch (e.target.id) {
        case "190":
          setRegistryHostname(e.target.value)
          if (portable) {
            return
          }
          if (e.target.value === '') {
            setRegistryHostnameInvalid(true)
            setWizardError(true)
            return            
          } else {
            setRegistryHostnameInvalid(false)
          }
          break;
        case "191":
          setRegistryPort(e.target.value)
          break;
        case "192":
          setRegistryNS(e.target.value)
          if (portable) {
            return
          }
          if (e.target.value === '' ) {
            setRegistryNSInvalid(true)
            setWizardError(true)
            return             
          } else {
            setRegistryNSInvalid(false)
          }
          break;
        case "193":
          setRegistryUser(e.target.value)
          if (portable) {
            return
          }
          if(e.target.value==='') {
            setRegistryUserInvalid(true)
            setWizardError(true)
            return  
          } else {
            setRegistryUserInvalid(false)
          }
          break;
        case "194":
          setRegistryPassword(e.target.value)
          if (portable) {
            return
          }
          if (e.target.value==='') {
            setregistryPasswordInvalid(true)
            setWizardError(true)
            return
          } else {
            setregistryPasswordInvalid(false)
          }
          break;
        default:
      }
    } 

    const ocLoginErrorProps = () => ({
      kind: 'error',
      lowContrast: true,
      role: 'error',
      title: 'Error logging into the OpenShift cluster.',
      hideCloseButton: false,
=======
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

    const [isRegistryHostnameInvalid, setRegistryHostnameInvalid] = useState(false)  
    const [isRegistryNSInvalid, setRegistryNSInvalid] = useState(false)
    const [isRegistryUserInvalid, setRegistryUserInvalid] = useState(false)
    const [isregistryPasswordInvalid, setregistryPasswordInvalid] = useState(false)   

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

      if (selection!== "Configure+Download") {
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
        }  
      } else {
        if (portable) {
          if (envId) {
            setWizardError(false)
          }
        } else {
          if (registryHostname && registryHostname && registryUser && registryPassword && envId) {
            setWizardError(false)
          } else {
            setWizardError(true)
          }
        }        
      }
    // eslint-disable-next-line
    },[cloudPlatform, IBMCloudSettings, AWSSettings, OCPSettings, configuration, locked, envId, registryHostname, registryHostname, registryUser, registryPassword, portable])

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

    const RegistryOnChange = (e) => {
      switch (e.target.id) {
        case "190":
          setRegistryHostname(e.target.value)
          if (portable) {
            return
          }
          if (e.target.value === '') {
            setRegistryHostnameInvalid(true)
            setWizardError(true)
            return            
          } else {
            setRegistryHostnameInvalid(false)
          }
          break;
        case "191":
          setRegistryPort(e.target.value)
          break;
        case "192":
          setRegistryNS(e.target.value)
          if (portable) {
            return
          }
          if (e.target.value === '' ) {
            setRegistryNSInvalid(true)
            setWizardError(true)
            return             
          } else {
            setRegistryNSInvalid(false)
          }
          break;
        case "193":
          setRegistryUser(e.target.value)
          if (portable) {
            return
          }
          if(e.target.value==='') {
            setRegistryUserInvalid(true)
            setWizardError(true)
            return  
          } else {
            setRegistryUserInvalid(false)
          }
          break;
        case "194":
          setRegistryPassword(e.target.value)
          if (portable) {
            return
          }
          if (e.target.value==='') {
            setregistryPasswordInvalid(true)
            setWizardError(true)
            return
          } else {
            setregistryPasswordInvalid(false)
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
>>>>>>> main
    }); 

    const checkDeployerStatuserrorProps = () => ({
      kind: 'error',
      lowContrast: true,
      role: 'error',
      title: 'Get error to check Deployer status. ',
      hideCloseButton: false,
    }); 

    return (
      <>
<<<<<<< HEAD
=======
      { loadConfigurationErr && <InlineNotification className="cpd-error"
          {...errorConfigurationProps()}        
            /> } 
>>>>>>> main
      {/* oc login error */}
      {ocLoginErr && <InlineNotification className="cpd-error"
          {...ocLoginErrorProps()}        
           />  }   
      {/* oc login error */}
      {checkDeployerStatusErr && <InlineNotification className="cpd-error"
          {...checkDeployerStatuserrorProps()}        
           />  }  
<<<<<<< HEAD
      
      {cpdWizardMode!=="existing-ocp" && selection!=="Configure+Download" &&
      <>
      <div className="infra-title">OpenShift login</div>      
=======
      {loadingConfiguration && <Loading /> }
      
      {cpdWizardMode!=="existing-ocp" && selection!=="Configure+Download" &&
      <>
      <div className="infra-title">Cloud Platform</div>      
>>>>>>> main
      <RadioButtonGroup orientation="vertical"
         name="radio-button-group"          
         onChange={(value)=>{setCloudPlatform(value)}}
         defaultSelected={cloudPlatform}  
         valueSelected={cloudPlatform}  
         >
<<<<<<< HEAD
         <RadioButton labelText="Existing OpenShift" value="existing-ocp" id="0" disabled/>
=======
         <RadioButton labelText="Existing OpenShift" value="existing-ocp" id="0" disabled={locked}/>
         <RadioButton labelText="IBM Cloud" value="ibm-cloud" id="1" disabled={locked}/>
         <RadioButton labelText="AWS" value="aws" id="2" disabled={locked}/>
         <RadioButton labelText="vSphere" value="vsphere" id="3" disabled />         
>>>>>>> main
      </RadioButtonGroup></> }
      
        { selection!=="Configure+Download" &&
        <div>
<<<<<<< HEAD
          {cloudPlatform === 'existing-ocp' ? 
            <>
              <div className="infra-container">
                </div>
                <div>
                  <div className="infra-items">oc login command</div>
                  <TextInput ref={ocLoginInputRef} onChange={OCPSettingsOnChange}  placeholder="oc login command" id="130" labelText="" value={OCPSettings.ocLoginCmd} invalidText="Invalid oc login command."  invalid={isOcLoginCmdInvalid}/>
=======
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
>>>>>>> main
                </div>
            </> : null}
        </div> }

        { selection==="Configure+Download" &&     
          <>
            <div className="infra-container">
                <div>
<<<<<<< HEAD
=======
                  <div className="infra-items-1">Enviroment ID</div>
                  <TextInput onChange={OCPSettingsOnChange} placeholder="Environment ID" id="131" labelText="" value={envId} invalidText="Environment ID can not be empty." invalid={isOCPEnvIdInvalid} disabled={locked}/>
                </div>

                <div>
>>>>>>> main
                  <div className="infra-items-1">
                    <legend>Registry Option </legend>                    
                    <Checkbox labelText="Portable" onChange={(value)=>{setPortable(value)}} id="portable-registry" key="portable-registry" checked={portable}/> 
                    <div className="infra-items-1-tips">Note: If this checkbox is checked, the private registry host name and the user and password are optional.</div>
                    
                  </div>
                </div>

                <div>
                  <div className="infra-items-1">Registry Host Name</div>
                  <TextInput onChange={RegistryOnChange} placeholder="Registry Host Name" id="190" labelText="" value={registryHostname} invalidText="Registry Host Name can not be empty."  invalid={isRegistryHostnameInvalid} />
                </div>
                <div>
                  <div className="infra-items-1">Registry Port</div>
                  <TextInput onChange={RegistryOnChange} placeholder="Registry Port" id="191" labelText="If not specified, the default port 443 will be used." value={registryPort} />
                </div>
                <div>
                  <div className="infra-items-1">Registry Namespace</div>
                  <TextInput onChange={RegistryOnChange} placeholder="Registry Namespace" id="192" labelText="" value={registryNS} invalidText="Registry Namespace can not be empty." invalid={isRegistryNSInvalid}/>
                </div>
                <div>
                  <div className="infra-items-1">Registry User</div>
                  <TextInput onChange={RegistryOnChange} placeholder="Registry User" id="193" labelText="" value={registryUser} invalidText="Registry User can not be empty." invalid={isRegistryUserInvalid}/>
                </div>
                <div>
                  <div className="infra-items-1">Registry Password</div>
                  <PasswordInput onChange={RegistryOnChange} placeholder="Registry Password" id="194" labelText="" value={registryPassword} invalidText="Registry Password can not be empty." invalid={isregistryPasswordInvalid}/>
                </div>
            </div>            
          </>  }

      </>
    );
  };

export default Infrastructure;