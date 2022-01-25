import { Checkbox, Loading, InlineNotification } from 'carbon-components-react';
import { useState, useEffect } from 'react';
import axios from "axios";
import './CloudPak.scss'

const CloudPak = ({CPDData, setCPDData}) => {
    const [loadingCPD, setLoadingCPD] = useState(false)
    const [loadCPDErr, setLoadCPDErr] = useState(false)

    const [checkParentCheckBox, setCheckParentCheckBox] = useState(false)
    const [indeterminateParentCheckBox, setIndeterminateParentCheckBox] = useState(false)

    useEffect(() => {
      const fetchCloudPakData =async () => {
        setLoadingCPD(true)
        await axios.get('/api/v1/cartridges/cp4d').then(res =>{            
            setCPDData(res.data) 
            updateParentCheckBox(res.data)                        
        }, err => {
            setLoadCPDErr(true)
            console.log(err)
        });        
      }    
      if (CPDData.length === 0) {
         fetchCloudPakData()              
      } 
      else {
        updateParentCheckBox(CPDData) 
      }      
      setLoadingCPD(false)         
    }, [])

    const errorProps = () => ({
      kind: 'error',
      lowContrast: true,
      role: 'error',
      title: 'Unable to get IBM Cloud Pak Configuration from server.',
      hideCloseButton: false,
    });     

    const updateParentCheckBox = (data)=> {  
      setCheckParentCheckBox(false)  
      setIndeterminateParentCheckBox(false) 
      let totalItems = data.filter(item => item.description != null )      
      let selectedItem = data.filter(item => item.state === "installed")      
      if (totalItems.length === selectedItem.length) {
        console.log(totalItems.length )
        console.log(selectedItem.length)
        setCheckParentCheckBox(true)
      }        
      else {
        if (selectedItem.length >= 0) {
          setIndeterminateParentCheckBox(true)
        }
      }       
    }

    const changeChildCheckBox = (e) => {
      setCPDData((data)=>{
        const newCPData = data.map((item)=>{
            if (item.name === e.target.id){
              if (e.target.checked)
                item.state = "installed"
              else
                item.state = "removed"
            } 
            return item             
        })  
        updateParentCheckBox(newCPData)        
        return newCPData
      })          
    }

    const changeParentCheckBox =(e) => {      
      setCPDData((CPDdata)=>{
        const newCPData = CPDdata.map((item)=>{
            if (item.description){
              if (e.target.checked)
                item.state = "installed"
              else
                item.state = "removed"
            } 
            return item             
        })
        return newCPData
      })
      if (e.target.checked) {
        setIndeterminateParentCheckBox(false)
        setCheckParentCheckBox(true)
      } 
      else {
        setIndeterminateParentCheckBox(false)
        setCheckParentCheckBox(false)
      }      
    }

    return (
        <>     
          <div className='cpd-container'>
          </div>  

          { loadingCPD && <Loading /> }  
          { loadCPDErr && <InlineNotification className="cpd-error"
                {...errorProps()}        
            /> }             
            <Checkbox className='parent' id="cp4d" labelText="IBM Cloud Pak for Data" onClick={changeParentCheckBox} checked={checkParentCheckBox} indeterminate={indeterminateParentCheckBox}/>
              { CPDData.map((item)=>{
                if (item.description) {
                  return (
                    <Checkbox className='child' onClick={changeChildCheckBox} labelText={item.description} id={item.name} key={item.name} checked={item.state === "installed"} />                
                  )  
                }
                return null        
              }) }             
        </>
    )
}
export default CloudPak;