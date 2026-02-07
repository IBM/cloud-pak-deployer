import { InlineNotification, RadioButton, RadioButtonGroup, TextInput, PasswordInput,Checkbox  } from "@carbon/react";
import { useEffect, useState, useRef } from "react";
import './Infrastructure.scss'

const Infrastructure = ({cloudPlatform, 
                         OCPSettings,
                         setOCPSettings,
                         setCloudPlatform, 
                         setWizardError,
                         ocLoginErr,
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
            setWizardError(true)
            return
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
      {/* oc login error */}
      {ocLoginErr && <InlineNotification className="cpd-error"
          {...ocLoginErrorProps()}        
           />  }   
      {/* oc login error */}
      {checkDeployerStatusErr && <InlineNotification className="cpd-error"
          {...checkDeployerStatuserrorProps()}        
           />  }  
      
      {cpdWizardMode!=="existing-ocp" && selection!=="Configure+Download" &&
      <>
      <div className="infra-title">OpenShift login</div>      
      <RadioButtonGroup orientation="vertical"
         name="radio-button-group"          
         onChange={(value)=>{setCloudPlatform(value)}}
         defaultSelected={cloudPlatform}  
         valueSelected={cloudPlatform}  
         >
         <RadioButton labelText="Existing OpenShift" value="existing-ocp" id="0" disabled/>
      </RadioButtonGroup></> }
      
        { selection!=="Configure+Download" &&
        <div>
          {cloudPlatform === 'existing-ocp' ? 
            <>
              <div className="infra-container">
                </div>
                <div>
                  <div className="infra-items">oc login command</div>
                  <TextInput ref={ocLoginInputRef} onChange={OCPSettingsOnChange}  placeholder="oc login command" id="130" labelText="" value={OCPSettings.ocLoginCmd} invalidText="Invalid oc login command."  invalid={isOcLoginCmdInvalid}/>
                </div>
            </> : null}
        </div> }

        { selection==="Configure+Download" &&     
          <>
            <div className="infra-container">
                <div>
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