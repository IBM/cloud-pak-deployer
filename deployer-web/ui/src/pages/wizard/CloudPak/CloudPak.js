import { Checkbox,Loading,InlineNotification,PasswordInput,Accordion,AccordionItem,TextInput} from 'carbon-components-react';
import { useState, useEffect } from 'react';
import axios from "axios";
import './CloudPak.scss'

const CloudPak = ({CPDCartridgesData, 
                  setCPDCartridgesData, 
                  CPICartridgesData, 
                  setCPICartridgesData, 
                  entitlementKey, 
                  setEntitlementKey, 
                  setWizardError,
                  configuration,
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
    const [loadingCPD, setLoadingCPD] = useState(false)
    const [loadCPDErr, setLoadCPDErr] = useState(false)
    const [loadingCPI, setLoadingCPI] = useState(false)
    const [loadCPIErr, setLoadCPIErr] = useState(false)

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
        setWizardError(false)
      }
      else {
        setWizardError(true)
      }
      // eslint-disable-next-line
    }, [CPDCartridgesData, CPICartridgesData, entitlementKey, loadCPDErr, loadCPIErr, cp4dLicense, cp4iLicense, CP4DPlatformCheckBox, CP4IPlatformCheckBox])

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

    const entitlementKeyOnChange = (e) => {
      setEntitlementKey(e.target.value);    
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
          { (loadCPDErr ||loadCPIErr) && <InlineNotification className="cpd-error"
              {...errorProps()}        
            /> 
          }
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
            </div> 

            {/* CP4D */}
            <div>
              <div className="cloud-pak-items">IBM Cloud Pak</div>
              {/* CP4D */}
              <div>
                
                <Accordion>                
                  <AccordionItem title="IBM Cloud Pak for Data" open={cp4dExpand}>                
                    
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