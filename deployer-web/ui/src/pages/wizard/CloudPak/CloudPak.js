import { Checkbox,Loading,InlineNotification,PasswordInput,Accordion,AccordionItem,TextInput} from 'carbon-components-react';
import { useState, useEffect } from 'react';
import axios from "axios";
import './CloudPak.scss'

const CloudPak = ({
                  setCloudPlatform, 
                  CPDCartridgesData, 
                  setCPDCartridgesData, 
                  CPICartridgesData, 
                  setCPICartridgesData, 
                  entitlementKey, 
                  setEntitlementKey, 
                  setWizardError,
                  configuration,
                  setConfiguration,
                  locked,
                  setLocked,
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
                  envId,
                  setEnvId,
                }) => {

    
    const [loadingConfiguration, setLoadingConfiguration] = useState(false)
    const [loadConfigurationErr, setLoadConfigurationErr] = useState(false)    
    
    const [loadingCPD, setLoadingCPD] = useState(false)
    const [loadCPDErr, setLoadCPDErr] = useState(false)
    const [loadingCPI, setLoadingCPI] = useState(false)
    const [loadCPIErr, setLoadCPIErr] = useState(false)

    const [isOCPEnvIdInvalid, setOCPEnvIdInvalid] = useState(false)
    const [cp4dVersionInvalid,  setCp4dVersionInvalid] = useState(false)
    const [cp4iVersionInvalid,  setCp4iVersionInvalid] = useState(false)
    const [isEntitlementKeyInvalid, setEntitlementKeyInvalid] = useState(false)

    useEffect(() => {
      const getConfiguration = async () => {
        setLoadingConfiguration(true)
        await axios.get('/api/v1/configuration').then(res => {
          setLoadingConfiguration(false)
          setLoadConfigurationErr(false)
          setConfiguration(res.data)

          console.log('res.data', res.data)

          if (res.data.code === 0) {
            setLocked(true)

            let cloud = res.data.data.global_config.cloud_platform
            setCloudPlatform(cloud)
            setEnvId(res.data.data.global_config.env_id)
            if (res.data.data.cp4d[0]) {
              setCp4dVersion(res.data.data.cp4d[0].cp4d_version)
              setCp4dLicense(res.data.data.cp4d[0].accept_licenses)
              setCPDCartridgesData(res.data.data.cp4d[0].cartridges)
            }
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

      if (loadConfigurationErr) {
        return
      }
      //Load configuration
      if (JSON.stringify(configuration) === "{}") {
        getConfiguration()
      }
    }, [])

    useEffect(() => {
      updateCP4DPlatformCheckBox(CPDCartridgesData)
      updateCP4IPlatformCheckBox(CPICartridgesData)
     
      if ((loadCPDErr === false && loadCPIErr === false) && (cp4dLicense || cp4iLicense) && entitlementKey !== '' ) {
        setWizardError(false)
      }
      else {
        setWizardError(true)
      }
      // eslint-disable-next-line
    }, [configuration, CPDCartridgesData, CPICartridgesData, entitlementKey, loadCPDErr, loadCPIErr, cp4dLicense, cp4iLicense, CP4DPlatformCheckBox, CP4IPlatformCheckBox])

    const errorProps = () => ({
      kind: 'error',
      lowContrast: true,
      role: 'error',
      title: 'Unable to get IBM Cloud Pak Configuration from server.',
      hideCloseButton: false,
    });      
    
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

    const adminPaswordOnChnage = (e) => {
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
            <div>
              <div className="infra-items">Environment ID</div>
              <TextInput onChange={EnvIdOnChange} placeholder="Environment ID" id="131" labelText="" value={envId} invalidText="Environment ID can not be empty." invalid={isOCPEnvIdInvalid} disabled={locked}/>
            </div>

            <div>
              <div className="cloud-pak-items">Entitlement key</div>
              <PasswordInput onChange={entitlementKeyOnChange} placeholder="Entitlement key" id="301" labelText="" value={entitlementKey} invalidText="Entitlement key is required." invalid={isEntitlementKeyInvalid} />
            </div>

            <div>
              <div className="cloud-pak-items">Admin Password</div>
              <PasswordInput onChange={adminPaswordOnChnage} placeholder="Admin Password" id="302" labelText="IBM Cloud Pak Platform will generate a password for admin user if not specified." value={adminPassword} />
            </div> 

            {/* CP4D */}
            <div>
              <div className="cloud-pak-items">IBM Cloud Pak</div>
              {/* CP4D */}
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

                    <Checkbox onClick={()=>(setCP4DPlatformCheckBox((CP4DPlatformCheckBox)=>(!CP4DPlatformCheckBox)))} labelText="IBM Cloud Pak for Data Platform" id="cp4d-platform" key="cp4d-platform" checked={CP4DPlatformCheckBox} />
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

            {/* CP4I */}          
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

                    <Checkbox onClick={()=>(setCP4IPlatformCheckBox((CP4IPlatformCheckBox)=>(!CP4IPlatformCheckBox)))} labelText="IBM Cloud Pak for Integration Platform" id="cp4i-platform" key="cp4i-platform" checked={CP4IPlatformCheckBox} />

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

            </div>
            </div> 
          </div>   
     
        </>
    )
}
export default CloudPak;