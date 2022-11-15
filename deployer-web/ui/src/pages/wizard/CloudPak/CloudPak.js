import { Checkbox, Loading, InlineNotification, PasswordInput ,Accordion,AccordionItem } from 'carbon-components-react';
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
                }) => {
    const [loadingCPD, setLoadingCPD] = useState(false)
    const [loadCPDErr, setLoadCPDErr] = useState(false)
    const [loadingCPI, setLoadingCPI] = useState(false)
    const [loadCPIErr, setLoadCPIErr] = useState(false)

    const [CPDCheckParentCheckBox, setCPDCheckParentCheckBox] = useState(false)
    const [CPDIndeterminateParentCheckBox, setCPDIndeterminateParentCheckBox] = useState(false)
    const [CPICheckParentCheckBox, setCPICheckParentCheckBox] = useState(false)
    const [CPIIndeterminateParentCheckBox, setCPIIndeterminateParentCheckBox] = useState(false)

    const [isEntitlementKeyInvalid, setEntitlementKeyInvalid] = useState(false)



    useEffect(() => {
      const fetchCloudPakData =async () => {        
        await axios.get('/api/v1/cartridges/cp4d').then(res =>{   
            setLoadingCPD(false)         
            setCPDCartridgesData(res.data) 
            updateCPDParentCheckBox(res.data)                        
        }, err => {
            setLoadingCPD(false)
            setLoadCPDErr(true)          
            console.log(err)
        });   
              
      }
      
      const fetchCloudPakIntegration =async () => {        
        await axios.get('/api/v1/cartridges/cp4i').then(res =>{  
            setLoadingCPI(false)          
            setCPICartridgesData(res.data) 
            updateCPIParentCheckBox(res.data)                        
        }, err => {
            setLoadingCPI(false)
            setLoadCPIErr(true)            
            console.log(err)
        });         
      } 
      updateCPDParentCheckBox(CPDCartridgesData)
      updateCPIParentCheckBox(CPICartridgesData)     

      if (locked) {
        setCPDCartridgesData(configuration.data.cp4d[0].cartridges)
        setCPICartridgesData(configuration.data.cp4i[0].instances)
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
      
      if (entitlementKey && (loadCPDErr === false && loadCPIErr === false) ) {
        setWizardError(false)
      }
      else {
        setWizardError(true)
      }
      // eslint-disable-next-line
    }, [CPDCartridgesData, CPICartridgesData])

    const errorProps = () => ({
      kind: 'error',
      lowContrast: true,
      role: 'error',
      title: 'Unable to get IBM Cloud Pak Configuration from server.',
      hideCloseButton: false,
    });     

    const updateCPDParentCheckBox = (data)=> {  
      setCPDCheckParentCheckBox(false)  
      setCPDIndeterminateParentCheckBox(false) 
      let totalItems = data.filter(item => item.description != null )      
      let selectedItem = data.filter(item => item.state === "installed")      
      if (totalItems.length === selectedItem.length) {
        // console.log(totalItems.length )
        // console.log(selectedItem.length)
        setCPDCheckParentCheckBox(true)
      }        
      else {
        if (selectedItem.length > 0) {
          // console.log(selectedItem.length)
          setCPDIndeterminateParentCheckBox(true)
        }
      }       
    }

    const updateCPIParentCheckBox = (data)=> {  
      setCPICheckParentCheckBox(false)  
      setCPIIndeterminateParentCheckBox(false) 
      let totalItems = data.filter(item => item.description != null )      
      let selectedItem = data.filter(item => item.state === "installed")      
      if (totalItems.length === selectedItem.length) {
        // console.log(totalItems.length )
        // console.log(selectedItem.length)
        setCPICheckParentCheckBox(true)
      }        
      else {
        if (selectedItem.length > 0) {
          setCPIIndeterminateParentCheckBox(true)
        }
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
        //updateCPDParentCheckBox(newCPDCartridgesData)        
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
        //updateCPIParentCheckBox(newCPICartridgesData)        
        return newCPICartridgesData
      })                
    }

    const changeCPDParentCheckBox =(e) => {      
      setCPDCartridgesData((CPDCartridgesData)=>{
        const newCPDCartridgesData = CPDCartridgesData.map((item)=>{
            if (item.description){
              if (e.target.checked)
                item.state = "installed"
              else
                item.state = "removed"
            } 
            return item             
        })
        return newCPDCartridgesData
      })
      if (e.target.checked) {
        setCPDIndeterminateParentCheckBox(false)
        setCPDCheckParentCheckBox(true)
      } 
      else {
        setCPDIndeterminateParentCheckBox(false)
        setCPDCheckParentCheckBox(false)
      }      
    }

    const changeCPIParentCheckBox =(e) => {      
      setCPICartridgesData((CPICartridgesData)=>{
        const newCPICartridgesData = CPICartridgesData.map((item)=>{
            if (item.description){
              if (e.target.checked)
                item.state = "installed"
              else
                item.state = "removed"
            } 
            return item             
        })
        return newCPICartridgesData
      })
      if (e.target.checked) {
        setCPIIndeterminateParentCheckBox(false)
        setCPICheckParentCheckBox(true)
      } 
      else {
        setCPIIndeterminateParentCheckBox(false)
        setCPICheckParentCheckBox(false)
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
          <div className='cpd-container'>                 
          {/* Entitlement */}
          <div>
            <div className="cloud-pak-items">Entitlement key</div>
            <PasswordInput onChange={entitlementKeyOnChange} placeholder="Entitlement key" id="301" labelText="" value={entitlementKey} invalidText="Entitlement key can not be empty." invalid={isEntitlementKeyInvalid}/>
          </div> 

          {/* CP4D */}
          <div>
            <div className="cloud-pak-items">Cartridges for IBM Cloud Pak</div>
            {/* CP4D */}
            <div>
              <Accordion>                
                <AccordionItem title="IBM Cloud Pak for Data" open={cp4dExpand}>

                  {CPDCartridgesData.length > 0 &&
                  <Checkbox className='parent' id="cp4d" labelText="IBM Cloud Pak for Data" onClick={changeCPDParentCheckBox} checked={CPDCheckParentCheckBox} indeterminate={CPDIndeterminateParentCheckBox}/>
                  }
                  { CPDCartridgesData.map((item)=>{
                    if (item.description) {
                      return (
                        <Checkbox className='child' onClick={changeCPDChildCheckBox} labelText={item.description} id={item.name} key={item.name} checked={item.state === "installed"} />                
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
                  {CPICartridgesData.length > 0 &&
                  <Checkbox className='parent' id="cp4i" labelText="IBM Cloud Pak for Integration" onClick={changeCPIParentCheckBox} checked={CPICheckParentCheckBox} indeterminate={CPIIndeterminateParentCheckBox}/>
                  }
                  { CPICartridgesData.map((item)=>{
                    if (item.description) {
                      return (
                        <Checkbox className='child' onClick={changeCPIChildCheckBox} labelText={item.description} id={item.type} key={item.type} checked={item.state === "installed"} />                
                      )  
                    }
                    return null        
                  }) } 
                </AccordionItem>
              </Accordion> 
            </div>
          
          </div>
          </div>       
        </>
    )
}
export default CloudPak;