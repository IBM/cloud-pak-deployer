<<<<<<< HEAD
import { Checkbox,Loading,InlineNotification,PasswordInput,Accordion,AccordionItem,TextInput,RadioButton,RadioButtonGroup,CodeSnippet} from '@carbon/react';
=======
import { Checkbox,Loading,InlineNotification,PasswordInput,Accordion,AccordionItem,TextInput} from 'carbon-components-react';
>>>>>>> main
import { useState, useEffect } from 'react';
import axios from "axios";
import './CloudPak.scss'

<<<<<<< HEAD
const CloudPak = ({
                  setCloudPlatform,
                  selection,
                  CPDCartridgesData, 
=======
const CloudPak = ({CPDCartridgesData, 
>>>>>>> main
                  setCPDCartridgesData, 
                  CPICartridgesData, 
                  setCPICartridgesData, 
                  entitlementKey, 
                  setEntitlementKey, 
                  setWizardError,
                  configuration,
<<<<<<< HEAD
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

=======
                  locked,
                  cp4dLicense,
                  cp4iLicense,
                  cp4dVersion,
                  cp4iVersion,
                  setCp4dLicense,
                  setCp4iLicense,
                  setCp4dVersion,
                  setCp4iVersion,
                  CP4DPlatformCheckBox,
                  CP4IPlatformCheckBox,
                  setCP4DPlatformCheckBox,
                  setCP4IPlatformCheckBox,
                  adminPassword,
                  setAdminPassword,
                }) => {
>>>>>>> main
    const [loadingCPD, setLoadingCPD] = useState(false)
    const [loadCPDErr, setLoadCPDErr] = useState(false)
    const [loadingCPI, setLoadingCPI] = useState(false)
    const [loadCPIErr, setLoadCPIErr] = useState(false)

<<<<<<< HEAD
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
=======
    const [cp4dVersionInvalid,  setCp4dVersionInvalid] = useState(false)
    const [cp4iVersionInvalid,  setCp4iVersionInvalid] = useState(false)

    useEffect(()=>{
      const fetchCloudPakData =async () => {        
        await axios.get('/api/v1/cartridges/cp4d').then(res =>{   
            setLoadingCPD(false)  
            if (res.data.cp4d[0].cartridges) {
              setCPDCartridgesData(res.data.cp4d[0].cartridges) 
            }             
            if (res.data.cp4d[0].accept_licenses) {
              setCp4dLicense(res.data.cp4d[0].accept_licenses)
            }
            if (res.data.cp4d[0].cp4d_version) {
              setCp4dVersion(res.data.cp4d[0].cp4d_version)
            }                    
        }, err => {
            setLoadingCPD(false)
            setLoadCPDErr(true)          
            console.log(err)
        });                
      }
      
      const fetchCloudPakIntegration =async () => {        
        await axios.get('/api/v1/cartridges/cp4i').then(res =>{  
            setLoadingCPI(false)   
            if (res.data.cp4i[0].instances) {  
              setCPICartridgesData(res.data.cp4i[0].instances) 
            }     
            if (res.data.cp4i[0].accept_licenses) {
              setCp4iLicense(res.data.cp4i[0].accept_licenses)
            }
            if (res.data.cp4i[0].cp4i_version) {
              setCp4iVersion(res.data.cp4i[0].cp4i_version)
            }   
            // updateCPIParentCheckBox(res.data)                        
        }, err => {
            setLoadingCPI(false)
            setLoadCPIErr(true)            
            console.log(err)
        });         
      }  

      if (locked) {  
        if(configuration.data.cp4d[0].cp4d_version) {
          setCp4dVersion(configuration.data.cp4d[0].cp4d_version)
        }
        if(configuration.data.cp4d[0].accept_licenses) {
          setCp4dLicense(configuration.data.cp4d[0].accept_licenses)
        }
        if(configuration.data.cp4d[0].cartridges) {
          setCPDCartridgesData(configuration.data.cp4d[0].cartridges)
        } else {
          setCPDCartridgesData([])
        }

        if(configuration.data.cp4i[0].cp4i_version) {
          setCp4iVersion(configuration.data.cp4i[0].cp4i_version)
        }
        if(configuration.data.cp4i[0].accept_licenses) {
          setCp4iLicense(configuration.data.cp4i[0].accept_licenses)
        }
        if(configuration.data.cp4i[0].instances) {
          setCPICartridgesData(configuration.data.cp4i[0].instances)
        } else {
          setCPICartridgesData([])
        }    
        setWizardError(false)
      } else {
        if (CPDCartridgesData.length === 0) {
            //CP4D 
            setLoadingCPD(true)     
            fetchCloudPakData() 
        }
        if (CPICartridgesData.length === 0) {
            //CP4I
            setLoadingCPI(true)
            fetchCloudPakIntegration() 
        }
      }  
      // eslint-disable-next-line
    },[])

    useEffect(() => {
      updateCP4DPlatformCheckBox(CPDCartridgesData)
      updateCP4IPlatformCheckBox(CPICartridgesData)  
     
      if ((loadCPDErr === false && loadCPIErr === false) && (cp4dLicense || cp4iLicense) ) {
>>>>>>> main
        setWizardError(false)
      }
      else {
        setWizardError(true)
      }
<<<<<<< HEAD

      // eslint-disable-next-line
    }, [CPDCartridgesData, CPICartridgesData, entitlementKey, adminPassword, selectedCloudPak, loadCPDErr, loadCPIErr, cp4dLicense, cp4iLicense])
=======
      // eslint-disable-next-line
    }, [CPDCartridgesData, CPICartridgesData, entitlementKey, loadCPDErr, loadCPIErr, cp4dLicense, cp4iLicense, CP4DPlatformCheckBox, CP4IPlatformCheckBox])
>>>>>>> main

    const errorProps = () => ({
      kind: 'error',
      lowContrast: true,
      role: 'error',
      title: 'Unable to get IBM Cloud Pak Configuration from server.',
      hideCloseButton: false,
    });      
    
<<<<<<< HEAD
=======
    const updateCP4DPlatformCheckBox = (data) => {
      let selectedItem = data.filter(item => item.state === "installed")  
      if (selectedItem.length > 0) {
        setCP4DPlatformCheckBox(true)
      }
    }

    const updateCP4IPlatformCheckBox = (data) => {
      let selectedItem = data.filter(item => item.state === "installed")  
      if (selectedItem.length > 0) {
        setCP4IPlatformCheckBox(true)
      }
    }

>>>>>>> main
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

<<<<<<< HEAD
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
=======
    const entitlementKeyOnChange = (e) => {
      setEntitlementKey(e.target.value);    
    }

    const adminPaswordOnChnage = (e) => {
>>>>>>> main
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
<<<<<<< HEAD
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
=======
    }  

    const [cp4dExpand, setcp4dExpand] = useState(false)
    const [cp4iExpand, setcp4iExpand] = useState(false)

    useEffect(() => {  
      if (locked) {
        let cp4dItem = configuration.data.cp4d[0].cartridges.filter(item => item.state === "installed") 
        setcp4dExpand( cp4dItem.length > 0 )
        let cp4IItem = configuration.data.cp4i[0].instances.filter(item => item.state === "installed") 
        setcp4iExpand( cp4IItem.length > 0 )
      } 
      // eslint-disable-next-line
    }, [])

    return (
        <>  
          { (loadingCPD ||loadingCPI) && <Loading /> }  
>>>>>>> main
          { (loadCPDErr ||loadCPIErr) && <InlineNotification className="cpd-error"
              {...errorProps()}        
            /> 
          }
<<<<<<< HEAD

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
=======
          <div className="cloud-pak">   

            <div className='cpd-container'> 
            {/* Entitlement */}
              <div>
              <div className="cloud-pak-items">Entitlement key</div>
              <PasswordInput onChange={entitlementKeyOnChange} placeholder="Entitlement key" id="301" labelText="" value={entitlementKey} />
            </div> 

            <div>
              <div className="cloud-pak-items">Admin Password</div>
              <PasswordInput onChange={adminPaswordOnChnage} placeholder="Admin Password" id="302" labelText="IBM Cloud Pak Platform will generate a password for admin user if not specified." value={adminPassword} />
>>>>>>> main
            </div> 

            {/* CP4D */}
            <div>
              <div className="cloud-pak-items">IBM Cloud Pak</div>
<<<<<<< HEAD
              
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
=======
              {/* CP4D */}
              <div>
                
                <Accordion>                
                  <AccordionItem title="IBM Cloud Pak for Data" open={cp4dExpand}>                
>>>>>>> main
                    
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

<<<<<<< HEAD
=======
                    <Checkbox onClick={()=>(setCP4DPlatformCheckBox((CP4DPlatformCheckBox)=>(!CP4DPlatformCheckBox)))} labelText="IBM Cloud Pak for Data Platform" id="cp4d-platform" key="cp4d-platform" checked={CP4DPlatformCheckBox} />
>>>>>>> main
                    { CPDCartridgesData.map((item)=>{
                      if (item.state) {
                        return (
                          <Checkbox onClick={changeCPDChildCheckBox} labelText={item.description ||item.name} id={item.name} key={item.name} checked={item.state === "installed"} />                
                        )  
                      }
                      return null        
                    }) } 
                  
                  </AccordionItem>
<<<<<<< HEAD
                </Accordion>
              </div>
              )}

            {/* CP4I */}
            {selectedCloudPak === 'cp4i' && (
=======
                </Accordion> 
              </div>

            {/* CP4I */}          
>>>>>>> main
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

<<<<<<< HEAD
=======
                    <Checkbox onClick={()=>(setCP4IPlatformCheckBox((CP4IPlatformCheckBox)=>(!CP4IPlatformCheckBox)))} labelText="IBM Cloud Pak for Integration Platform" id="cp4i-platform" key="cp4i-platform" checked={CP4IPlatformCheckBox} />

>>>>>>> main
                    { CPICartridgesData.map((item)=>{
                      if (item.state) {
                        return (
                          <Checkbox onClick={changeCPIChildCheckBox} labelText={item.description ||item.type} id={item.type} key={item.type} checked={item.state === "installed"} />                
                        )  
                      }
                      return null        
                    }) } 
                    
                  </AccordionItem>
<<<<<<< HEAD
                </Accordion>
              </div>
            )}

            </div>
            </div> 

=======
                </Accordion> 
              </div>

            </div>
            </div> 
>>>>>>> main
          </div>   
     
        </>
    )
}
export default CloudPak;