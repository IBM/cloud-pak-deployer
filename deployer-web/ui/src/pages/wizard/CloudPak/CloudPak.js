import { Checkbox,Loading,InlineNotification,PasswordInput,Accordion,AccordionItem,TextInput,RadioButton,RadioButtonGroup,CodeSnippet} from 'carbon-components-react';
import { useState, useEffect } from 'react';
import axios from "axios";
import './CloudPak.scss'

const CloudPak = ({
                  setCloudPlatform,
                  selection,
                  CPDCartridgesData, 
                  setCPDCartridgesData, 
                  CPICartridgesData, 
                  setCPICartridgesData, 
                  entitlementKey, 
                  setEntitlementKey, 
                  setWizardError,
                  configuration,
                  setConfiguration,
                  adminPassword,
                  setAdminPassword,
                  envId,
                  setEnvId,
                }) => {

    
    const [selectedCloudPak, setSelectedCloudPak] = useState('software-hub')
    const [existingConfig, setExistingConfig] = useState(false)
    
    const [loadingConfiguration, setLoadingConfiguration] = useState(false)
    const [loadConfigurationErr, setLoadConfigurationErr] = useState(false) 
    
    const [openShiftConnection, setOpenShiftConnection] = useState({})

    const [loadingCPD, setLoadingCPD] = useState(false)
    const [loadCPDErr, setLoadCPDErr] = useState(false)
    const [loadingCPI, setLoadingCPI] = useState(false)
    const [loadCPIErr, setLoadCPIErr] = useState(false)

    const [cp4dLicense, setCp4dLicense] = useState(false)
    const [cp4iLicense, setCp4iLicense] = useState(false)
    const [cp4dVersion, setCp4dVersion] = useState('')
    const [cp4iVersion, setCp4iVersion] = useState('')

    const [isOCPEnvIdInvalid, setOCPEnvIdInvalid] = useState(false)
    const [cp4dVersionInvalid,  setCp4dVersionInvalid] = useState(false)
    const [cp4iVersionInvalid,  setCp4iVersionInvalid] = useState(false)
    const [isEntitlementKeyInvalid, setEntitlementKeyInvalid] = useState(false)

    // Runs only after initial rendering
    useEffect(() => {
      const getConfiguration = async () => {
        setLoadingConfiguration(true)
        await axios.get('/api/v1/configuration').then(res => {
          setLoadingConfiguration(false)
          setLoadConfigurationErr(false)

          setConfiguration(res.data)

          let cloud = res.data.data.global_config.cloud_platform
          setCloudPlatform(cloud)
          setEnvId(res.data.data.global_config.env_id)
          if (res.data.data.global_config.universal_password) {
            setAdminPassword(res.data.data.global_config.universal_password)
          }
          if (res.data.metadata.cp_entitlement_key) {
            setEntitlementKey(res.data.metadata.cp_entitlement_key)
          }
          setExistingConfig(res.data.metadata.existing_config)

          if (res.data.data.cp4d) {
            if (res.data.data.cp4d[0]) {
              setCp4dVersion(res.data.data.cp4d[0].cp4d_version)
              setCp4dLicense(res.data.data.cp4d[0].accept_licenses)
              setCPDCartridgesData(res.data.data.cp4d[0].cartridges)
            }
          }
          if (res.data.data.cp4i) {
            if (res.data.data.cp4i[0]) {
              setCp4iVersion(res.data.data.cp4i[0].cp4i_version)
              setCp4iLicense(res.data.data.cp4i[0].accept_licenses)
              setCPICartridgesData(res.data.data.cp4i[0].instances)
            }
          }

        }, err => {
          setLoadingConfiguration(false)
          setLoadConfigurationErr(true)
          console.log(err)
        });
      }

      const getOpenShiftConnection = async() => {
        await axios.get('/api/v1/oc-check-connection').then(res =>{
          setOpenShiftConnection(res.data)
        }, err => {
          console.log(err)
          setOpenShiftConnection(false)
        });
      }

      if (loadConfigurationErr) {
        return
      }

      // Get OpenShift cluster info
      if (selection==="Configure+Deploy") {
        getOpenShiftConnection()
      }

      //Load configuration
      if (JSON.stringify(configuration) === "{}") {
        getConfiguration()
      }

    }, [])

    // Runs after any of the dependencies change (array of dependencies)
    useEffect(() => {
      
      if (configuration && configuration.metadata) {
        configuration.metadata.entitlementKey = entitlementKey
        setConfiguration(configuration)
      }

      if (configuration && configuration.data && configuration.data.global_config) {
        configuration.data.global_config.universal_password = adminPassword
        setConfiguration(configuration)
      }

      if (configuration && configuration.metadata) {
        configuration.metadata.selectedCloudPak = selectedCloudPak
        setConfiguration(configuration)
      }

      if (configuration && configuration.data && 'cp4d' in configuration.data) {
        configuration.data.cp4d[0].accept_licenses=cp4dLicense
        setConfiguration(configuration)
      }

      if (configuration && configuration.data && 'cp4i' in configuration.data) {
        configuration.data.cp4i[0].accept_licenses=cp4iLicense
        setConfiguration(configuration)
      }
      
      if ((loadCPDErr === false && loadCPIErr === false) && (cp4dLicense || cp4iLicense) && entitlementKey !== '' ) {
        setWizardError(false)
      }
      else {
        setWizardError(true)
      }

      // eslint-disable-next-line
    }, [CPDCartridgesData, CPICartridgesData, entitlementKey, adminPassword, selectedCloudPak, loadCPDErr, loadCPIErr, cp4dLicense, cp4iLicense])

    const errorProps = () => ({
      kind: 'error',
      lowContrast: true,
      role: 'error',
      title: 'Unable to get IBM Cloud Pak Configuration from server.',
      hideCloseButton: false,
    });      
    
    const changeCPDChildCheckBox = (e) => {
      setCPDCartridgesData((data)=>{
        const newCPDCartridgesData = data.map((item)=>{
            if (item.name === e.target.id){
              if (e.target.checked)
                item.state = "installed"
              else
                item.state = "removed"
            } 
            return item             
        })         
        return newCPDCartridgesData
      })          
    }

    const changeCPIChildCheckBox = (e) => {
      setCPICartridgesData((data)=>{
        const newCPICartridgesData = data.map((item)=>{
            if (item.type === e.target.id){
              if (e.target.checked)
                item.state = "installed"
              else
                item.state = "removed"
            } 
            return item             
        })         
        return newCPICartridgesData
      })                
    }

    const EnvIdOnChange = (e) => {
      switch (e.target.id) {
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

    const entitlementKeyOnChange = (e) => {
      setEntitlementKey(e.target.value);
      if (e.target.value === '') {
        setEntitlementKeyInvalid(true)
        setWizardError(true)
        return
      } else {
        setEntitlementKeyInvalid(false)
      }
      setWizardError(false)
    }

    const adminPaswordOnChange = (e) => {
      setAdminPassword(e.target.value)
    }

    const cp4iVersionOnChange = (e) => {
      setCp4iVersion(e.target.value);
      if (e.target.value === '') {
        setCp4iVersionInvalid(true)
        setWizardError(true)
        return
      } else {
        setCp4iVersionInvalid(false)
      }
      setWizardError(false)     
    } 
    
    const cp4dVersionOnChange = (e) => {
      setCp4dVersion(e.target.value);
      if (e.target.value === '') {
        setCp4dVersionInvalid(true)
        setWizardError(true)
        return
      } else {
        setCp4dVersionInvalid(false)
      }
      setWizardError(false)     
    } 

    const errorConfigurationProps = () => ({
      kind: 'error',
      lowContrast: true,
      role: 'error',
      title: 'Unable to get Configuration from server.',
      hideCloseButton: false,
    });    

    const [cp4dExpand, setcp4dExpand] = useState(true)
    const [cp4iExpand, setcp4iExpand] = useState(true)

    useEffect(() => {
      setSelectedCloudPak('software-hub')
      if (configuration && configuration.data) {
        if ('cp4d' in configuration.data) { setSelectedCloudPak('software-hub') }
        else { setSelectedCloudPak('cp4i') }
      }
      // eslint-disable-next-line
    }, [])

    const handleCloudPakSelection = (value) => {
      setSelectedCloudPak(value)
    }

    return (
        <>  
          { loadConfigurationErr && <InlineNotification className="cpd-error"
          {...errorConfigurationProps()}        
            /> } 
          { (loadingConfiguration && !loadConfigurationErr) && <Loading /> }  
          { (loadCPDErr ||loadCPIErr) && <InlineNotification className="cpd-error"
              {...errorProps()}        
            /> 
          }

          <div className="cloud-pak">

            <div className='cpd-container'>

            {openShiftConnection.server &&
              <div>
                <div className="cloud-pak-items">OpenShift server</div>
                <CodeSnippet type="single">{openShiftConnection.server}</CodeSnippet>
              </div>
            }

            <div>
              <div className="cloud-pak-items">Environment ID</div>
              <TextInput onChange={EnvIdOnChange} placeholder="Environment ID" id="131" labelText="" value={envId} invalidText="Environment ID can not be empty." invalid={isOCPEnvIdInvalid} disabled={existingConfig}/>
            </div>

            <div>
              <div className="cloud-pak-items">Entitlement key</div>
              <PasswordInput onChange={entitlementKeyOnChange} placeholder="Entitlement key" id="301" labelText="" value={entitlementKey} invalidText="Entitlement key is required." invalid={isEntitlementKeyInvalid} />
            </div>

            <div>
              <div className="cloud-pak-items">Admin Password</div>
              <PasswordInput onChange={adminPaswordOnChange} placeholder="Admin Password" id="302" labelText="IBM Cloud Pak Platform will generate a password for admin user if not specified." value={adminPassword} />
            </div> 

            {/* CP4D */}
            <div>
              <div className="cloud-pak-items">IBM Cloud Pak</div>
              
              {/* Radio buttons for Cloud Pak selection */}
              <div className="cloud-pak-radio-group">
                <RadioButtonGroup
                  legendText="Select Cloud Pak"
                  name="cloud-pak-selection"
                  valueSelected={selectedCloudPak}
                  onChange={handleCloudPakSelection}
                  disabled={existingConfig}
                >
                  <RadioButton
                    labelText="Software Hub"
                    value="software-hub"
                    id="radio-software-hub"
                  />
                  <RadioButton
                    labelText="Cloud Pak for Integration"
                    value="cp4i"
                    id="radio-cp4i"
                  />
                </RadioButtonGroup>
              </div>

              {/* CP4D */}
              {selectedCloudPak === 'software-hub' && (
              <div>
                
                <Accordion>
                  <AccordionItem title="IBM Software Hub" open={cp4dExpand}>
                    
                    <div className="cpd-version">
                      <div className="item">Version:</div>
                      <TextInput placeholder="version" onChange={cp4dVersionOnChange} id="cp4d-version" labelText="" value={cp4dVersion} invalidText="Version can not be empty." invalid={cp4dVersionInvalid}/>
                    </div>

                    <div className="cpd-license">
                      <div className="item">Licenses:</div>
                      <Checkbox onClick={()=>(setCp4dLicense((cp4dLicense)=>(!cp4dLicense)))} labelText="Accept Licenses" id="cp4d-license" key="cp4d-license" checked={cp4dLicense} />
                    </div>

                    <div className="cpd-cartridges">
                      <div className="item">Cartridges:</div>
                    </div>

                    { CPDCartridgesData.map((item)=>{
                      if (item.state) {
                        return (
                          <Checkbox onClick={changeCPDChildCheckBox} labelText={item.description ||item.name} id={item.name} key={item.name} checked={item.state === "installed"} />                
                        )  
                      }
                      return null        
                    }) } 
                  
                  </AccordionItem>
                </Accordion>
              </div>
              )}

            {/* CP4I */}
            {selectedCloudPak === 'cp4i' && (
            <div>
                <Accordion>                
                  <AccordionItem title="IBM Cloud Pak for Integration" open={cp4iExpand}>
                    <div className="cpd-version">
                      <div className="item">Version:</div>
                      <TextInput placeholder="version" onChange={cp4iVersionOnChange} id="cp4i-version" value={cp4iVersion} labelText="" invalidText="Version can not be empty." invalid={cp4iVersionInvalid} />
                    </div>

                    <div className="cpd-license">
                      <div className="item">Licenses:</div>
                      <Checkbox onClick={()=>(setCp4iLicense((cp4iLicense)=>(!cp4iLicense)))}  labelText="Accept Licenses" id="cp4i-license" key="cp4i-license" checked={cp4iLicense}/>
                    </div>

                    <div className="cpd-cartridges">
                      <div className="item">Cartridges:</div>
                    </div>

                    { CPICartridgesData.map((item)=>{
                      if (item.state) {
                        return (
                          <Checkbox onClick={changeCPIChildCheckBox} labelText={item.description ||item.type} id={item.type} key={item.type} checked={item.state === "installed"} />                
                        )  
                      }
                      return null        
                    }) } 
                    
                  </AccordionItem>
                </Accordion>
              </div>
            )}

            </div>
            </div> 

          </div>   
     
        </>
    )
}
export default CloudPak;